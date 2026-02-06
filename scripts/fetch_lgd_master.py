import os
import requests
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv
import time
from datetime import datetime

# Load environment variables relative to script
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))

API_KEY = os.getenv("DATA_GOV_IN_API_KEY")
RESOURCE_ID = "f17a1608-5f10-4610-bb50-a63c80d83974"
BASE_URL = "https://api.data.gov.in/resource/f17a1608-5f10-4610-bb50-a63c80d83974"
DB_URL = os.getenv("DATABASE_URL")

if not API_KEY:
    print("Error: DATA_GOV_IN_API_KEY not found in .env")
    exit(1)

def run_sync_cycle():
    """Returns True if sync is complete, False if it should restart."""
    conn = psycopg2.connect(DB_URL)
    cursor = conn.cursor()
    
    # Get starting offset
    job_name = "lgd_master"
    try:
        # Try finding persisted offset first
        cursor.execute("SELECT last_offset FROM sync_status WHERE job_name = %s", (job_name,))
        row = cursor.fetchone()
        
        if row:
            start_offset = row[0]
            print(f"Found persisted offset: {start_offset}")
        else:
            # Fallback to COUNT(*)
            cursor.execute("SELECT COUNT(*) FROM lgd_master")
            count = cursor.fetchone()[0]
            start_offset = (count // 1000) * 1000
            print(f"No persisted offset. Fallback to DB count: {count} -> {start_offset}")
            
        offset = start_offset
    except Exception as e:
        print(f"Error checking offset: {e}. Starting from 0.")
        offset = 0
        conn.rollback()

    limit = 1000
    total_records = start_offset
    
    print(f"[{datetime.now()}] Resuming LGD Master sync from offset: {offset}")
    
    try:
        while True:
            params = {
                "api-key": API_KEY,
                "format": "json",
                "offset": offset,
                "limit": limit
            }
            
            response = None
            max_retries = 3
            for attempt in range(max_retries):
                try:
                    response = requests.get(BASE_URL, params=params, timeout=30)
                    if response.status_code == 200:
                        break
                    print(f"Attempt {attempt+1}/{max_retries} failed: Status {response.status_code}. Waiting...")
                    time.sleep(2 * (attempt + 1))
                except requests.RequestException as e:
                    print(f"Attempt {attempt+1}/{max_retries} Exception: {e}")
                    time.sleep(2 * (attempt + 1))
            
            if not response or response.status_code != 200:
                print(f"Failed to fetch data after retries. Last status: {response.status_code if response else 'None'}")
                return False # Signal restart needed
                
            data = response.json()
            records = data.get("records", [])
            
            if not records:
                # Double check total validity? 
                # Ideally check 'total' in response but data.gov.in 'total' field is sometimes static.
                # If records is empty, we are likely done.
                print("No more records found in API response.")
                return True # Signal complete
                
            # Prepare batch insert
            insert_query = """
                INSERT INTO lgd_master (
                    village_code, village_name, 
                    subdistrict_code, subdistrict_name, 
                    district_code, district_name, 
                    state_code, state_name, 
                    pincode
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (village_code) DO UPDATE SET
                    village_name = EXCLUDED.village_name,
                    subdistrict_name = EXCLUDED.subdistrict_name,
                    district_name = EXCLUDED.district_name,
                    state_name = EXCLUDED.state_name,
                    pincode = EXCLUDED.pincode,
                    last_updated = CURRENT_TIMESTAMP;
            """
            
            values = []
            for r in records:
                values.append((
                    r.get("villageCode"),
                    r.get("villageNameEnglish"),
                    r.get("subdistrictCode"),
                    r.get("subdistrictNameEnglish"),
                    r.get("districtCode"),
                    r.get("districtNameEnglish"),
                    r.get("stateCode"),
                    r.get("stateNameEnglish"),
                    str(r.get("pincode")) if r.get("pincode") else None
                ))
            
            execute_batch(cursor, insert_query, values)
            
            # Update Offset
            count = len(records)
            offset += count
            total_records += count
            
            # Persist Progress
            cursor.execute("""
                INSERT INTO sync_status (job_name, last_offset, last_updated)
                VALUES (%s, %s, CURRENT_TIMESTAMP)
                ON CONFLICT (job_name) DO UPDATE SET
                    last_offset = EXCLUDED.last_offset,
                    last_updated = CURRENT_TIMESTAMP;
            """, (job_name, offset))
            
            conn.commit()
            
            print(f"Inserted {count} records. Current Offset: {offset}")
            
            if count < limit:
                print("Reached end of data stream (count < limit).")
                return True
                
            time.sleep(0.5) # Rate limiting
            
    except Exception as e:
        print(f"Critical Error in Sync Cycle: {e}")
        conn.rollback()
        return False # Signal restart needed
    finally:
        cursor.close()
        conn.close()

def main_loop():
    restart_delay = 300 # 5 minutes
    
    while True:
        try:
            is_complete = run_sync_cycle()
            if is_complete:
                print("Sync Completed Successfully. Exiting.")
                break
            else:
                print(f"Sync interrupted or failed. Restarting in {restart_delay} seconds...")
                time.sleep(restart_delay)
        except KeyboardInterrupt:
            print("Sync manually stopped.")
            break
        except Exception as e:
            print(f"Unexpected Loop Error: {e}")
            time.sleep(restart_delay)

if __name__ == "__main__":
    main_loop()
