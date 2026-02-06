import os
import sys
import argparse
import zipfile
import pandas as pd
import psycopg2
from dotenv import load_dotenv

# Setup paths relative to script location
BASE_DIR = os.path.join(os.path.dirname(__file__), '..')
env_path = os.path.join(BASE_DIR, '.env')
load_dotenv(env_path)

DB_URL = os.getenv("DATABASE_URL")

def get_db_connection():
    if not DB_URL:
        print("Error: DATABASE_URL not found in .env")
        sys.exit(1)
    return psycopg2.connect(DB_URL)

def ingest_district_demographics(file_path):
    print(f"Starting ingestion of District Demographics (NDAP 9307) from: {file_path}")
    
    # Check if file is a zip or csv
    if file_path.endswith('.zip'):
        with zipfile.ZipFile(file_path, 'r') as z:
            # Find the source data file
            target_file = None
            for name in z.namelist():
                if '9307_source_data.csv' in name:
                    target_file = name
                    break
            
            if not target_file:
                print("Error: 9307_source_data.csv not found in zip!")
                return

            print(f"Reading {target_file} from zip...")
            with z.open(target_file) as f:
                df = pd.read_csv(f)
    else:
        print(f"Reading CSV file: {file_path}")
        df = pd.read_csv(file_path)
            
    print(f"Loaded {len(df)} rows. Transforming...")
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    inserted = 0
    
    for _, row in df.iterrows():
        # Extract fields
        state = row.get('srcStateName')
        district = row.get('srcDistrictName')
        year = row.get('srcYear')
        
        # Parse populations (handle NaNs/empty strings)
        def clean_int(val):
            try:
                return int(float(val)) if pd.notnull(val) else 0
            except:
                return 0
                
        sc_pop = clean_int(row.get('Number of SC population'))
        st_pop = clean_int(row.get('Number of ST population'))
        gen_pop = clean_int(row.get('Number of general population'))
        
        # Total logic: sum specific columns
        calc_total = sc_pop + st_pop + gen_pop
        
        try:
            query = """
                INSERT INTO district_demographics 
                (state_name, district_name, year_code, total_population, sc_population, st_population, general_population, source_file)
                VALUES (%s, %s, %s, %s, %s, %s, %s, 'NDAP_9307_source_data.csv')
                ON CONFLICT (state_name, district_name, year_code) 
                DO UPDATE SET
                    total_population = EXCLUDED.total_population,
                    sc_population = EXCLUDED.sc_population,
                    st_population = EXCLUDED.st_population,
                    general_population = EXCLUDED.general_population,
                    created_at = NOW();
            """
            cur.execute(query, (state, district, year, calc_total, sc_pop, st_pop, gen_pop))
            inserted += 1
            
        except Exception as e:
            print(f"Error inserting {state}-{district}: {e}")
            conn.rollback()
            continue

    conn.commit()
    cur.close()
    conn.close()
    print(f"Ingestion Complete. Processed {inserted} rows.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Ingest NDAP 9307 District Demographics')
    parser.add_argument('--file', required=True, help='Path to the 9307_all_files.zip or 9307_source_data.csv')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.file):
        print(f"Error: File not found: {args.file}")
        sys.exit(1)
        
    ingest_district_demographics(args.file)
