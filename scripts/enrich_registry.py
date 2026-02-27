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

# Path Configuration
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))
DB_URL = os.getenv("DATABASE_URL")
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
    return psycopg2.connect(DB_URL)

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

def fetch_9_blobs(school_id, udise_code, year_id):
    """Parallel fragment fetch with Year 11 fallback and manifest tracking."""
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    })

    # Load existing manifest
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT enrichment_manifest FROM schools_udise_data WHERE school_id = %s AND year_id = %s", (school_id, year_id))
    row = cursor.fetchone()
    manifest = row[0] if row and row[0] else {}
    cursor.close()
    conn.close()

    endpoints_to_fetch = [
        ("basic_info", ENDPOINTS["by_year"], {"schoolId": school_id, "action": 2}),
        ("report_card", ENDPOINTS["report_card"], {"schoolId": school_id, "yearId": year_id}),
        ("facility_data", ENDPOINTS["facility"], {"schoolId": school_id, "yearId": year_id}),
        ("profile_data", ENDPOINTS["profile"], {"schoolId": school_id, "yearId": year_id}),
        ("social_1", ENDPOINTS["social_1"], {"schoolId": school_id, "yearId": year_id, "flag": 1}),
        ("social_2", ENDPOINTS["social_2"], {"schoolId": school_id, "yearId": year_id, "flag": 2}),
        ("social_3", ENDPOINTS["social_3"], {"schoolId": school_id, "yearId": year_id, "flag": 3}),
        ("social_4", ENDPOINTS["social_4"], {"schoolId": school_id, "yearId": year_id, "flag": 4}),
        ("social_5", ENDPOINTS["social_5"], {"schoolId": school_id, "yearId": year_id, "flag": 5}),
    ]

    def try_fetch(url, current_params):
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

    def fetch_single_fragment(key, url, params):
        if manifest.get(key) == 200:
            return key, 200, None

        # Attempt Target Year (Y12)
        code, data = try_fetch(url, params)
        
        # Fallback to Y11 if missing
        if code != 200 and "yearId" in params and params["yearId"] == CURRENT_YEAR_ID:
            fb_params = params.copy()
            fb_params["yearId"] = FALLBACK_YEAR_ID
            code, data = try_fetch(url, fb_params)

        return key, code, data

    with ThreadPoolExecutor(max_workers=9) as executor:
        futures = [executor.submit(fetch_single_fragment, k, u, p) for k, u, p in endpoints_to_fetch]
        for f in as_completed(futures):
            key, code, data = f.result()
            manifest[key] = code
            if code == 200 and data:
                save_intermediate_blob(school_id, year_id, key, data, manifest)
            else:
                save_manifest_only(school_id, year_id, manifest)
    return manifest

def save_manifest_only(school_id, year_id, manifest):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE schools_udise_data SET enrichment_manifest = %s WHERE school_id = %s AND year_id = %s", (json.dumps(manifest), school_id, year_id))
        conn.commit()
    finally:
        cursor.close() ; conn.close()

def save_intermediate_blob(school_id, year_id, key, blob, manifest):
    column_map = {
        "basic_info": "basic_info", "report_card": "report_card", "facility_data": "facility_data", "profile_data": "profile_data",
        "social_1": "enrollment_social", "social_2": "enrollment_religion", "social_3": "enrollment_mainstreamed", "social_4": "enrollment_ews", "social_5": "enrollment_rte"
    }
    col = column_map.get(key)
    if not col: return
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"UPDATE schools_udise_data SET {col} = %s, enrichment_manifest = %s, last_modified = CURRENT_TIMESTAMP WHERE school_id = %s AND year_id = %s", (json.dumps(blob), json.dumps(manifest), school_id, year_id))
        conn.commit()
    finally:
        cursor.close() ; conn.close()

def extract_summary(data):
    summary = {
        "total_students": None, "total_boys": None, "total_girls": None, "total_teachers": None,
        "has_internet": False, "has_library": False, "has_playground": False, "has_electricity": False,
        "lgd_urban_body_id": None, "lgd_urban_body_name": None, "lgd_ward_id": None, "lgd_ward_name": None
    }
    if data.get("report_card") and "data" in data["report_card"]:
        rc = data["report_card"]["data"]
        boys = rc.get("rowBoyTotal") or rc.get("totMale") or 0
        girls = rc.get("rowGirlTotal") or rc.get("totFemale") or 0
        total = rc.get("rowTotal") or (boys + girls)
        summary.update({"total_students": total, "total_boys": boys, "total_girls": girls, "total_teachers": rc.get("totalTeacher")})
    if data.get("facility_data") and "data" in data["facility_data"]:
        fd = data["facility_data"]["data"]
        summary.update({"has_internet": fd.get("internetYn") == 1, "has_library": fd.get("libraryYn") == 1, "has_playground": fd.get("playgroundYn") == 1, "has_electricity": fd.get("electricityYn") == 1})
    if data.get("profile_data") and "data" in data["profile_data"]:
        pd = data["profile_data"]["data"]
        summary.update({"lgd_urban_body_id": pd.get("lgdurbanlocalbodyId"), "lgd_urban_body_name": pd.get("lgdurbanlocalbodyName"), "lgd_ward_id": pd.get("lgdwardId"), "lgd_ward_name": pd.get("lgdwardName")})
    return summary

def process_school(school_id, udise_code):
    manifest = fetch_9_blobs(school_id, udise_code, CURRENT_YEAR_ID)
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT report_card, facility_data, profile_data FROM schools_udise_data WHERE school_id = %s AND year_id = %s", (school_id, CURRENT_YEAR_ID))
    row = cursor.fetchone()
    cursor.close() ; conn.close()
    if row:
        summary = extract_summary({"report_card": row[0], "facility_data": row[1], "profile_data": row[2]})
        conn = get_db_connection() ; cursor = conn.cursor()
        try:
            cursor.execute("""
                UPDATE schools_udise_data SET
                    total_students = %s, total_boys = %s, total_girls = %s, total_teachers = %s,
                    has_internet = %s, has_library = %s, has_playground = %s, has_electricity = %s,
                    lgd_urban_local_body_id = %s, lgd_urban_local_body_name = %s, lgd_ward_id = %s, lgd_ward_name = %s,
                    scrape_status = CASE WHEN %s = 200 AND %s = 200 THEN 'success' ELSE 'partial' END,
                    last_scraped_at = CURRENT_TIMESTAMP
                WHERE school_id = %s AND year_id = %s
            """, (
                summary["total_students"], summary["total_boys"], summary["total_girls"], summary["total_teachers"],
                summary["has_internet"], summary["has_library"], summary["has_playground"], summary["has_electricity"],
                summary["lgd_urban_body_id"], summary["lgd_urban_body_name"], summary["lgd_ward_id"], summary["lgd_ward_name"],
                manifest.get("profile_data"), manifest.get("report_card"), school_id, CURRENT_YEAR_ID
            ))
            conn.commit()
        finally:
            cursor.close() ; conn.close()
    return 'done'

def mine_state(state_name, limit=None):
    logger.info(f"--- STARTING MISSION: {state_name} ---")
    conn = get_db_connection() ; cursor = conn.cursor()
    query = "SELECT school_id, udise_code FROM schools_udise_data WHERE state_name = %s AND (scrape_status = 'pending' OR scrape_status = 'partial') ORDER BY scrape_status DESC, udise_code ASC"
    if limit: query += f" LIMIT {limit}"
    cursor.execute(query, (state_name,))
    schools = cursor.fetchall()
    cursor.close() ; conn.close()
    total = len(schools)
    for i, s in enumerate(schools, 1):
        try:
            process_school(s[0], s[1])
            if i % 10 == 0: logger.info(f"  [{state_name}] Progress: {i}/{total}")
            time.sleep(random.uniform(1.0, 4.0))
        except Exception as e:
            logger.error(f"  ! Fatal {s[1]}: {e}\n{traceback.format_exc()}")
            time.sleep(10)
    logger.info(f"--- COMPLETED: {state_name} ---")

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--limit", type=int, default=None)
    args = p.parse_args()
    mine_state(args.state, args.limit)
