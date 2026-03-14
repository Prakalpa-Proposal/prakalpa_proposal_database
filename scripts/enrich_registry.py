#!/usr/bin/env python3
import os
import json
import time
import requests
import psycopg2
import logging
import random
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from dotenv import load_dotenv
from psycopg2 import pool

# Path Configuration
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))
DB_URL = os.getenv("DATABASE_URL")
DB_POOL = pool.SimpleConnectionPool(1, 20, DB_URL)
CURRENT_YEAR_ID = 12
FALLBACK_YEAR_ID = 11

# API Endpoints
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

# Logger Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(BASE_DIR, "logs", "enrichment_scan.log")),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("Enrichment")

def get_db_connection():
    return DB_POOL.getconn()

def put_db_connection(conn):
    DB_POOL.putconn(conn)

def get_json(resp, url):
    """Refined JSON loader. strictly requires status: true."""
    if resp.status_code == 503:
        logger.warning(f"  ! 503 Service Unavailable at {url}. Emergency Pause (60s)...")
        time.sleep(60)
        return 'RETRY'
        
    if resp.status_code != 200: 
        return None
    try:
        js = resp.json()
        if js.get("status") is True:
            return js
        return None
    except:
        return None

def fetch_9_blobs(school_id, udise_code):
    """
    Discovery-Driven Fetch:
    1. Calls 'by_year' first to find the Effective Year for this school.
    2. Fetches all other 8 fragments for that specific Year.
    """
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    })

    def try_fetch_internal(url, current_params):
        for attempt in range(2):
            try:
                resp = session.get(url, params=current_params, timeout=15)
                res = get_json(resp, url)
                if res == 'RETRY': return 503, None
                if res: return 200, res
            except:
                pass
            time.sleep(1)
        return 404, None

    # STEP 1: Discovery & Smart Fallback (Sequential Lock-in)
    # -------------------------------------------------------------------------
    code, res = try_fetch_internal(ENDPOINTS["by_year"], {"schoolId": school_id, "action": 2})
    
    if code == 200 and res:
        effective_year = res.get("data", {}).get("yearId", CURRENT_YEAR_ID)
    else:
        # Smart Fallback: Verify Year 11 via a single probe
        logger.info(f"  ? Discovery Failed for {udise_code}. Probing Year 11 Fallback...")
        code, probe = try_fetch_internal(ENDPOINTS["report_card"], {"schoolId": school_id, "yearId": FALLBACK_YEAR_ID})
        if code == 200:
            effective_year = FALLBACK_YEAR_ID
            logger.info(f"  ✓ Fallback Success: Using Year {FALLBACK_YEAR_ID} for {udise_code}")
        else:
            logger.warning(f"  ! MISSING_ON_SERVER: {udise_code} has no data sessions.")
            return CURRENT_YEAR_ID, {"basic_info": 404, "is_missing_on_server": True}

    logger.info(f"  > Target Effective Year for {udise_code}: {effective_year}")
    
    # LOCK-IN: Stamp metadata early to ensure row integrity
    conn = get_db_connection() ; cursor = conn.cursor()
    try:
        cursor.execute("UPDATE schools_udise_data SET effective_year = %s WHERE school_id = %s", (effective_year, school_id))
        conn.commit()
    finally:
        cursor.close() ; put_db_connection(conn)

    # Initialize manifest and save primary blob
    manifest = {"basic_info": 200}
    # If discovery succeeded, res is basic_info. If fallback, res might be None but probe is report_card.
    # To maintain consistency, we should try to get basic_info for the effective_year if we don't have it.
    if effective_year != CURRENT_YEAR_ID or not res:
         code, res = try_fetch_internal(ENDPOINTS["by_year"], {"schoolId": school_id, "action": 2}) # Refresh for year if needed (though by_year is year-less)
         # Actually basic_info in manifest usually maps to by_year result.
    
    save_intermediate_blob(school_id, "basic_info", res if res else {}, manifest)

    # STEP 2: Fragment Extraction (Parallel)
    # -------------------------------------------------------------------------
    endpoints_to_fetch = [
        ("report_card", ENDPOINTS["report_card"], {"schoolId": school_id, "yearId": effective_year}),
        ("facility_data", ENDPOINTS["facility"], {"schoolId": school_id, "yearId": effective_year}),
        ("profile_data", ENDPOINTS["profile"], {"schoolId": school_id, "yearId": effective_year}),
        ("social_1", ENDPOINTS["social_1"], {"schoolId": school_id, "yearId": effective_year, "flag": 1}),
        ("social_2", ENDPOINTS["social_2"], {"schoolId": school_id, "yearId": effective_year, "flag": 2}),
        ("social_3", ENDPOINTS["social_3"], {"schoolId": school_id, "yearId": effective_year, "flag": 3}),
        ("social_4", ENDPOINTS["social_4"], {"schoolId": school_id, "yearId": effective_year, "flag": 4}),
        ("social_5", ENDPOINTS["social_5"], {"schoolId": school_id, "yearId": effective_year, "flag": 5}),
    ]

    def fetch_single_fragment(key, url, params):
        # Micro-jitter to stagger requests
        time.sleep(random.uniform(0.1, 0.5))
        code, data = try_fetch_internal(url, params)
        return key, code, data

    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(fetch_single_fragment, k, u, p) for k, u, p in endpoints_to_fetch]
        for f in as_completed(futures):
            key, code, data = f.result()
            manifest[key] = code
            if code == 200 and data:
                save_intermediate_blob(school_id, key, data, manifest)
            else:
                save_manifest_only(school_id, manifest)

    return effective_year, manifest

def save_manifest_only(school_id, manifest):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Year-Agnostic update: Primary identity is school_id
        cursor.execute("UPDATE schools_udise_data SET enrichment_manifest = %s WHERE school_id = %s", (json.dumps(manifest), school_id))
        conn.commit()
    finally:
        cursor.close() ; put_db_connection(conn)

def save_intermediate_blob(school_id, key, blob, manifest):
    column_map = {
        "basic_info": "basic_info", "report_card": "report_card", "facility_data": "facility_data", "profile_data": "profile_data",
        "social_1": "enrollment_social", "social_2": "enrollment_religion", "social_3": "enrollment_mainstreamed", "social_4": "enrollment_ews", "social_5": "enrollment_rte"
    }
    col = column_map.get(key)
    if not col: return
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"UPDATE schools_udise_data SET {col} = %s, enrichment_manifest = %s, last_modified = CURRENT_TIMESTAMP WHERE school_id = %s", (json.dumps(blob), json.dumps(manifest), school_id))
        conn.commit()
    finally:
        cursor.close() ; put_db_connection(conn)

def extract_summary(data):
    """
    Revised Strict Extractor: Decouples Student and Teacher domains.
    - Students: Sourced from 'enrollment_social' (The Master Registry).
    - Teachers: Sourced from 'report_card' (The Staff Registry).
    - N/A Signal: -1 used to differentiate missing data from zero counts.
    """
    summary = {
        "total_students": -1, "total_boys": -1, "total_girls": -1, "total_teachers": -1,
        "has_internet": False, "has_library": False, "has_playground": False, "has_electricity": False,
        "lgd_urban_body_id": None, "lgd_urban_body_name": None, "lgd_ward_id": None, "lgd_ward_name": None
    }
    
    # 1. Student Domain (from enrollment_social)
    if data.get("enrollment_social") and "data" in data["enrollment_social"]:
        social = data["enrollment_social"]["data"].get("schEnrollmentYearDataTotal", {})
        b = social.get("rowBoyTotal") if social.get("rowBoyTotal") is not None else -1
        g = social.get("rowGirlTotal") if social.get("rowGirlTotal") is not None else -1
        t = social.get("rowTotal") if social.get("rowTotal") is not None else -1
        
        # If total is missing but gendered components exist, sum them
        if t == -1 and (b != -1 or g != -1):
            t = (max(0, b) + max(0, g))
            
        summary.update({"total_students": t, "total_boys": b, "total_girls": g})

    # 2. Teacher Domain (from report_card)
    if data.get("report_card") and "data" in data["report_card"]:
        rc = data["report_card"]["data"]
        mt = rc.get("totMale") if rc.get("totMale") is not None else -1
        ft = rc.get("totFemale") if rc.get("totFemale") is not None else -1
        tt = rc.get("totalTeacher") if rc.get("totalTeacher") is not None else \
             (max(0, mt) + max(0, ft) if (mt != -1 or ft != -1) else -1)
             
        summary.update({"total_teachers": tt})

    # 3. Infrastructure (from facility_data)
    if data.get("facility_data") and "data" in data["facility_data"]:
        fd = data["facility_data"]["data"]
        summary.update({
            "has_internet": fd.get("internetYn") == 1, 
            "has_library": fd.get("libraryYn") == 1, 
            "has_playground": fd.get("playgroundYn") == 1, 
            "has_electricity": fd.get("electricityYn") == 1
        })
        
    # 4. Urban LGD (from profile_data)
    if data.get("profile_data") and "data" in data["profile_data"]:
        pd = data["profile_data"]["data"]
        summary.update({
            "lgd_urban_body_id": pd.get("lgdurbanlocalbodyId"), 
            "lgd_urban_body_name": pd.get("lgdurbanlocalbodyName"), 
            "lgd_ward_id": pd.get("lgdwardId"), 
            "lgd_ward_name": pd.get("lgdwardName")
        })
    return summary

def process_school(school_id, udise_code):
    effective_year, manifest = fetch_9_blobs(school_id, udise_code)
    
    # Check for terminal "Missing on Server" state
    if manifest.get("is_missing_on_server"):
        conn = get_db_connection() ; cursor = conn.cursor()
        try:
            cursor.execute("UPDATE schools_udise_data SET scrape_status = 'missing_on_server', last_scraped_at = CURRENT_TIMESTAMP WHERE school_id = %s", (school_id,))
            conn.commit()
        finally:
            cursor.close() ; put_db_connection(conn)
        return 'missing'

    conn = get_db_connection()
    cursor = conn.cursor()
    # Query by school_id only (found row)
    cursor.execute("SELECT report_card, facility_data, profile_data, enrollment_social FROM schools_udise_data WHERE school_id = %s", (school_id,))
    row = cursor.fetchone()
    cursor.close() ; put_db_connection(conn)
    
    if row:
        summary = extract_summary({
            "report_card": row[0], 
            "facility_data": row[1], 
            "profile_data": row[2],
            "enrollment_social": row[3]
        })
        conn = get_db_connection() ; cursor = conn.cursor()
        try:
            cursor.execute("""
                UPDATE schools_udise_data SET
                    year_id = %s,
                    total_students = %s, total_boys = %s, total_girls = %s, total_teachers = %s,
                    has_internet = %s, has_library = %s, has_playground = %s, has_electricity = %s,
                    lgd_urban_local_body_id = %s, lgd_urban_local_body_name = %s, lgd_ward_id = %s, lgd_ward_name = %s,
                    scrape_status = CASE WHEN %s = 200 AND %s = 200 THEN 'success' ELSE 'partial' END,
                    last_scraped_at = CURRENT_TIMESTAMP
                WHERE school_id = %s
            """, (
                effective_year,
                summary["total_students"], summary["total_boys"], summary["total_girls"], summary["total_teachers"],
                summary["has_internet"], summary["has_library"], summary["has_playground"], summary["has_electricity"],
                summary["lgd_urban_body_id"], summary["lgd_urban_body_name"], summary["lgd_ward_id"], summary["lgd_ward_name"],
                manifest.get("profile_data"), manifest.get("report_card"), school_id
            ))
            conn.commit()
        finally:
            cursor.close() ; put_db_connection(conn)
    return 'done'

def mine_state(state_name, mode='normal', limit=None):
    logger.info(f"--- STARTING MISSION: {state_name} (Mode: {mode}) ---")
    conn = get_db_connection() ; cursor = conn.cursor()
    
    if mode == 'recovery':
        # Broad Recovery Query: Target all non-closed schools where recovery hasn't run yet
        query = "SELECT school_id, udise_code FROM schools_udise_data WHERE state_name = %s AND scrape_status IN ('pending', 'partial', 'success') AND effective_year IS NULL ORDER BY scrape_status ASC, udise_code ASC"
    else:
        query = "SELECT school_id, udise_code FROM schools_udise_data WHERE state_name = %s AND (scrape_status = 'pending' OR scrape_status = 'partial') ORDER BY scrape_status DESC, udise_code ASC"
    
    if limit: query += f" LIMIT {limit}"
    cursor.execute(query, (state_name,))
    schools = cursor.fetchall()
    cursor.close() ; put_db_connection(conn)
    total = len(schools)
    for i, s in enumerate(schools, 1):
        try:
            process_school(s[0], s[1])
            if i % 10 == 0: logger.info(f"  [{state_name}] Progress: {i}/{total}")
            time.sleep(random.uniform(1.0, 3.0)) # Optimized Speed (saves ~34h)
        except Exception as e:
            logger.error(f"  ! Fatal {s[1]}: {e}\n{traceback.format_exc()}")
            time.sleep(10)
    logger.info(f"--- COMPLETED: {state_name} ---")

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--state", default=None)
    p.add_argument("--limit", type=int, default=None)
    p.add_argument("--udise", default=None)
    p.add_argument("--mode", default="normal", choices=["normal", "recovery"])
    args = p.parse_args()
    
    if args.udise:
        conn = get_db_connection() ; cursor = conn.cursor()
        cursor.execute("SELECT school_id FROM schools_udise_data WHERE udise_code = %s", (args.udise,))
        row = cursor.fetchone()
        cursor.close() ; put_db_connection(conn)
        if row:
            logger.info(f"Targeted Scan for UDISE {args.udise} (ID: {row[0]})")
            process_school(row[0], args.udise)
        else:
            logger.error(f"UDISE {args.udise} not found in DB.")
    elif args.state:
        mine_state(args.state, args.mode, args.limit)
    else:
        logger.error("Usage: --state [NAME] or --udise [CODE]")
