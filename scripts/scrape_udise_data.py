#!/usr/bin/env python3
"""
UDISE+ Data Scraper
Fetches comprehensive school data from UDISE+ API for South Indian states.
Stores data in schools_udise_data table with automatic retry and state-wise logging.
"""

import os
import sys
import json
import time
import requests
import psycopg2
from psycopg2.extras import Json
from dotenv import load_dotenv
from datetime import datetime
import random
import logging
from pathlib import Path

# Load environment variables
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))

DB_URL = os.getenv("DATABASE_URL")
CURRENT_YEAR_ID = 11  # 2024-25

# State priority order
STATE_PRIORITY = ["KARNATAKA", "GOA", "KERALA", "TELANGANA", "TAMIL NADU", "ANDHRA PRADESH"]

# UDISE API endpoints
UDISE_BASE = "https://kys.udiseplus.gov.in/webapp/api"
ENDPOINTS = {
    "by_year": f"{UDISE_BASE}/school/by-year",
    "report_card": f"{UDISE_BASE}/school/report-card",
    "facility": f"{UDISE_BASE}/school/facility",
    "profile": f"{UDISE_BASE}/school/profile",
    "social_1": f"{UDISE_BASE}/getSocialData",  # Caste
    "social_2": f"{UDISE_BASE}/getSocialData",  # Religion, BPL, CWSN
    "social_3": f"{UDISE_BASE}/getSocialData",  # Mainstreamed
    "social_4": f"{UDISE_BASE}/getSocialData",  # EWS
    "social_5": f"{UDISE_BASE}/getSocialData",  # RTE
}

# Create logs directory
LOGS_DIR = Path(BASE_DIR) / "logs" / "udise_scraper"
LOGS_DIR.mkdir(parents=True, exist_ok=True)

# Checkpoint file for resuming
CHECKPOINT_FILE = LOGS_DIR / "checkpoint.json"


def setup_logging(state_name):
    """Setup state-specific logging."""
    log_file = LOGS_DIR / f"udise_scrape_{state_name.lower().replace(' ', '_')}.log"
    
    logger = logging.getLogger(f"udise_scraper_{state_name}")
    logger.setLevel(logging.INFO)
    
    # Clear existing handlers
    logger.handlers = []
    
    # File handler
    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.INFO)
    
    # Console handler
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    
    # Formatter
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    
    logger.addHandler(fh)
    logger.addHandler(ch)
    
    return logger


def fetch_udise_data(udise_code, school_id, year_id=CURRENT_YEAR_ID, retry=0, logger=None):
    """
    Fetch data from all 9 UDISE endpoints for a school.
    Returns dict with all API responses and extracted summary fields.
    """
    if retry >= 3:
        return None, f"Max retries exceeded for {udise_code}"
    
    try:
        data = {
            "udise_code": udise_code,
            "school_id": school_id,
            "year_id": year_id,
            "scrape_status": "success",
            "retry_count": retry,
            "error_message": None
        }
        
        # Fetch all endpoints
        try:
            # 1. By Year
            resp = requests.get(ENDPOINTS["by_year"], params={"schoolId": school_id, "action": 2}, timeout=10)
            data["basic_info"] = resp.json() if resp.status_code == 200 else None
            
            # 2. Report Card
            resp = requests.get(ENDPOINTS["report_card"], params={"schoolId": school_id, "yearId": year_id}, timeout=10)
            data["report_card"] = resp.json() if resp.status_code == 200 else None
            
            # 3. Facility
            resp = requests.get(ENDPOINTS["facility"], params={"schoolId": school_id, "yearId": year_id}, timeout=10)
            data["facility_data"] = resp.json() if resp.status_code == 200 else None
            
            # 4. Profile
            resp = requests.get(ENDPOINTS["profile"], params={"schoolId": school_id, "yearId": year_id}, timeout=10)
            data["profile_data"] = resp.json() if resp.status_code == 200 else None
            
            # 5-9. Social Data (flags 1-5)
            for flag in range(1, 6):
                key = f"enrollment_{'social' if flag == 1 else 'religion' if flag == 2 else 'mainstreamed' if flag == 3 else 'ews' if flag == 4 else 'rte'}"
                resp = requests.get(ENDPOINTS[f"social_{flag}"], params={"schoolId": school_id, "yearId": year_id, "flag": flag}, timeout=10)
                data[key] = resp.json() if resp.status_code == 200 else None
            
            # Extract summary fields
            if data["report_card"] and "data" in data["report_card"]:
                rc = data["report_card"]["data"]
                data["total_students"] = rc.get("rowBoyTotal", 0) + rc.get("rowGirlTotal", 0) if "rowBoyTotal" in rc else None
                data["total_boys"] = rc.get("totMale")
                data["total_girls"] = rc.get("totFemale")
                data["total_teachers"] = rc.get("totalTeacher")
            
            if data["facility_data"] and "data" in data["facility_data"]:
                fd = data["facility_data"]["data"]
                data["has_internet"] = fd.get("internetYn") == 1
                data["has_library"] = fd.get("libraryYn") == 1
                data["has_playground"] = fd.get("playgroundYn") == 1
                data["has_electricity"] = fd.get("electricityYn") == 1
            
            return data, None
            
        except requests.Timeout:
            if logger:
                logger.warning(f"Timeout for {udise_code}, retry {retry + 1}/3")
            time.sleep(2 ** retry)  # Exponential backoff
            return fetch_udise_data(udise_code, school_id, year_id, retry + 1, logger)
            
        except requests.RequestException as e:
            if logger:
                logger.warning(f"Request error for {udise_code}: {e}, retry {retry + 1}/3")
            time.sleep(2 ** retry)
            return fetch_udise_data(udise_code, school_id, year_id, retry + 1, logger)
            
    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        if logger:
            logger.error(f"Failed to fetch {udise_code}: {error_msg}")
        return None, error_msg


def save_to_db(conn, data):
    """Save UDISE data to database."""
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO schools_udise_data (
                udise_code, school_id, year_id,
                last_scraped_at, scrape_status, retry_count, error_message,
                basic_info, report_card, facility_data, profile_data,
                enrollment_social, enrollment_religion, enrollment_mainstreamed, enrollment_ews, enrollment_rte,
                total_students, total_boys, total_girls, total_teachers,
                has_internet, has_library, has_playground, has_electricity
            ) VALUES (
                %s, %s, %s, CURRENT_TIMESTAMP, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (udise_code, year_id) DO UPDATE SET
                last_scraped_at = CURRENT_TIMESTAMP,
                scrape_status = EXCLUDED.scrape_status,
                retry_count = EXCLUDED.retry_count,
                error_message = EXCLUDED.error_message,
                basic_info = EXCLUDED.basic_info,
                report_card = EXCLUDED.report_card,
                facility_data = EXCLUDED.facility_data,
                profile_data = EXCLUDED.profile_data,
                enrollment_social = EXCLUDED.enrollment_social,
                enrollment_religion = EXCLUDED.enrollment_religion,
                enrollment_mainstreamed = EXCLUDED.enrollment_mainstreamed,
                enrollment_ews = EXCLUDED.enrollment_ews,
                enrollment_rte = EXCLUDED.enrollment_rte,
                total_students = EXCLUDED.total_students,
                total_boys = EXCLUDED.total_boys,
                total_girls = EXCLUDED.total_girls,
                total_teachers = EXCLUDED.total_teachers,
                has_internet = EXCLUDED.has_internet,
                has_library = EXCLUDED.has_library,
                has_playground = EXCLUDED.has_playground,
                has_electricity = EXCLUDED.has_electricity;
        """, (
            data["udise_code"], data["school_id"], data["year_id"],
            data["scrape_status"], data["retry_count"], data["error_message"],
            Json(data.get("basic_info")), Json(data.get("report_card")), 
            Json(data.get("facility_data")), Json(data.get("profile_data")),
            Json(data.get("enrollment_social")), Json(data.get("enrollment_religion")),
            Json(data.get("enrollment_mainstreamed")), Json(data.get("enrollment_ews")), 
            Json(data.get("enrollment_rte")),
            data.get("total_students"), data.get("total_boys"), data.get("total_girls"), data.get("total_teachers"),
            data.get("has_internet"), data.get("has_library"), data.get("has_playground"), data.get("has_electricity")
        ))
        
        conn.commit()
        return True
        
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()


def get_school_id_from_search_api(udise_code, logger=None):
    """Get UDISE API school_id from search API."""
    try:
        url = f"{UDISE_BASE}/search-schools"
        params = {
            "searchType": 3,  # Search by UDISE code
            "searchParam": udise_code
        }
        
        resp = requests.get(url, params=params, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            if data.get("status") and data.get("data", {}).get("content"):
                schools = data["data"]["content"]
                if schools and len(schools) > 0:
                    return schools[0].get("schoolId")
        
        if logger:
            logger.warning(f"Could not find school_id for {udise_code} from search API")
        return None
        
    except Exception as e:
        if logger:
            logger.error(f"Error fetching school_id for {udise_code}: {e}")
        return None


def get_schools_to_scrape(conn, state_name):
    """Get list of schools in a state that need scraping."""
    cursor = conn.cursor()
    
    # Use JOIN to get schools through normalized schema
    cursor.execute("""
        SELECT DISTINCT s.udise_code
        FROM schools s
        LEFT JOIN clusters c ON s.cluster_id = c.id
        LEFT JOIN blocks b ON c.block_id = b.id
        LEFT JOIN districts d ON b.district_id = d.id
        LEFT JOIN states st ON d.state_id = st.id
        LEFT JOIN schools_udise_data u ON s.udise_code = u.udise_code AND u.year_id = %s
        WHERE st.name ILIKE %s
        AND u.id IS NULL
        ORDER BY s.udise_code;
    """, (CURRENT_YEAR_ID, f"%{state_name}%"))
    
    schools = cursor.fetchall()
    cursor.close()
    
    # Return just udise_codes, we'll fetch school_id from search API
    return [row[0] for row in schools]


def save_checkpoint(state_name, udise_code):
    """Save progress checkpoint."""
    checkpoint = {
        "state": state_name,
        "last_udise_code": udise_code,
        "timestamp": datetime.now().isoformat()
    }
    
    with open(CHECKPOINT_FILE, 'w') as f:
        json.dump(checkpoint, f)


def load_checkpoint():
    """Load progress checkpoint."""
    if CHECKPOINT_FILE.exists():
        with open(CHECKPOINT_FILE, 'r') as f:
            return json.load(f)
    return None


def scrape_state(state_name, test_mode=False, limit=None):
    """Scrape all schools in a state."""
    logger = setup_logging(state_name)
    logger.info(f"Starting UDISE scrape for {state_name}")
    
    conn = psycopg2.connect(DB_URL)
    
    try:
        schools = get_schools_to_scrape(conn, state_name)
        
        if limit:
            schools = schools[:limit]
        
        total = len(schools)
        logger.info(f"Found {total} schools to scrape in {state_name}")
        
        success_count = 0
        failed_count = 0
        
        for idx, udise_code in enumerate(schools, 1):
            logger.info(f"[{idx}/{total}] Processing {udise_code}")
            
            # First, get school_id from search API
            school_id = get_school_id_from_search_api(udise_code, logger)
            
            if not school_id:
                logger.error(f"✗ Could not get school_id for {udise_code}, skipping")
                failed_count += 1
                continue
            
            # Fetch data
            data, error = fetch_udise_data(udise_code, school_id, logger=logger)
            
            if data:
                # Save to DB
                try:
                    save_to_db(conn, data)
                    success_count += 1
                    logger.info(f"✓ Successfully scraped {udise_code}")
                except Exception as e:
                    failed_count += 1
                    logger.error(f"✗ Failed to save {udise_code}: {e}")
            else:
                # Save failure record
                failed_data = {
                    "udise_code": udise_code,
                    "school_id": school_id,
                    "year_id": CURRENT_YEAR_ID,
                    "scrape_status": "failed",
                    "retry_count": 3,
                    "error_message": error
                }
                try:
                    save_to_db(conn, failed_data)
                except:
                    pass
                failed_count += 1
                logger.error(f"✗ Failed to fetch {udise_code}: {error}")
            
            # Save checkpoint
            save_checkpoint(state_name, udise_code)
            
            # Random delay to avoid throttling (2-5 seconds)
            if not test_mode and idx < total:
                delay = random.uniform(2, 5)
                time.sleep(delay)
        
        logger.info(f"Completed {state_name}: {success_count} success, {failed_count} failed")
        
    except KeyboardInterrupt:
        logger.info("Scraping interrupted by user. Progress saved.")
        sys.exit(0)
        
    except Exception as e:
        logger.error(f"Critical error in {state_name}: {e}")
        raise
        
    finally:
        conn.close()


def main():
    """Main scraper loop."""
    import argparse
    
    parser = argparse.ArgumentParser(description="UDISE+ Data Scraper")
    parser.add_argument("--test-mode", action="store_true", help="Test mode with faster delays")
    parser.add_argument("--limit", type=int, help="Limit number of schools per state")
    parser.add_argument("--state", type=str, help="Scrape only specific state")
    
    args = parser.parse_args()
    
    states_to_scrape = [args.state.upper()] if args.state else STATE_PRIORITY
    
    print(f"UDISE+ Data Scraper")
    print(f"States to process: {', '.join(states_to_scrape)}")
    print(f"Logs directory: {LOGS_DIR}")
    print(f"Test mode: {args.test_mode}")
    print(f"Limit: {args.limit if args.limit else 'No limit'}")
    print()
    
    for state in states_to_scrape:
        try:
            scrape_state(state, test_mode=args.test_mode, limit=args.limit)
        except Exception as e:
            print(f"Failed to process {state}: {e}")
            # Continue to next state
            continue
    
    print("All states processed!")


if __name__ == "__main__":
    main()
