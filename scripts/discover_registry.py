#!/usr/bin/env python3
import os
import json
import time
import requests
import psycopg2
import logging
from datetime import datetime
from dotenv import load_dotenv

# Path Configuration
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))
DB_URL = os.getenv("DATABASE_URL")

# API Configuration
UDISE_BASE = "https://kys.udiseplus.gov.in/webapp/api"
DISTRICTS_API = f"{UDISE_BASE}/districts"
BLOCKS_API = f"{UDISE_BASE}/blocks"
CLUSTERS_API = f"{UDISE_BASE}/clusters"
REGIONAL_URL = f"{UDISE_BASE}/search-school/by-region"

STATES = {
    "KARNATAKA": 129,
    "GOA": 130,
    "KERALA": 132,
    "ANDHRA PRADESH": 128,
    "TAMIL NADU": 133,
    "TELANGANA": 136
}

# Logger Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(BASE_DIR, "logs", "discovery_scan.log")),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("Discovery")

def get_db_connection():
    return psycopg2.connect(DB_URL)

def unmask_code(masked_code, block_cd):
    """Unmasks UDISE code using block code + suffix logic."""
    if not masked_code or not block_cd: return None
    if "*" not in str(masked_code): return str(masked_code)
    suffix = str(masked_code)[-5:] # Always the last 5 digits
    return f"{block_cd}{suffix}"

def fetch_json(url, params=None, retries=3):
    """Robust JSON fetcher with retries."""
    for i in range(retries):
        try:
            resp = requests.get(url, params=params, timeout=15)
            if resp.status_code == 200:
                return resp.json().get("data")
            logger.warning(f"  ! API Error {resp.status_code} at {url} (Retry {i+1})")
        except Exception as e:
            logger.warning(f"  ! Request failed: {e} (Retry {i+1})")
        time.sleep(1)
    return None

def upsert_school(conn, s, d, b, c):
    """Inserts or updates school record in the flattened schema."""
    cursor = conn.cursor()
    
    # 1. Unmask UDISE
    raw_code = s.get("udiseschCode")
    block_cd = s.get("blockCd")
    udise_code = unmask_code(raw_code, block_cd)
    
    if not udise_code:
        return
        
    # 2. Determine initial status
    school_status = s.get("schoolStatus", 0)
    status_name = s.get("schoolStatusName", "Unknown")
    scrape_status = 'pending' if school_status == 0 else 'closed_registry'
    
    try:
        cursor.execute("""
            INSERT INTO schools_udise_data (
                school_id, year_id, udise_code, school_name, school_status, status_name, last_modified,
                state_id, state_cd, state_name,
                district_id, district_cd, district_name,
                block_id, block_cd, block_name,
                cluster_id, cluster_cd, cluster_name,
                village_id, vill_ward_cd, village_name,
                pincode, address, email,
                lgd_state_id, lgd_district_id, lgd_block_id, lgd_village_id, lgd_vill_name,
                lgd_panchayat_id, lgd_vill_panchayat_name,
                sch_loc_rural_urban, sch_loc_desc,
                sch_category_id, sch_cat_desc,
                sch_type, sch_type_desc,
                sch_mgmt_id, sch_mgmt_desc,
                sch_mgmt_parent_id, sch_mgmt_desc_st,
                sch_broad_mgmt_id, class_frm, class_to,
                is_operational_2018_to_19, is_operational_2019_to_20, is_operational_2020_to_21, is_operational_2021_to_22, is_operational_2022_to_23,
                scrape_status
            ) VALUES (
                %s, 12, %s, %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s,
                %s, %s,
                %s, %s,
                %s, %s,
                %s, %s,
                %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s
            )
            ON CONFLICT (school_id, year_id) DO UPDATE SET
                udise_code = EXCLUDED.udise_code,
                school_name = EXCLUDED.school_name,
                school_status = EXCLUDED.school_status,
                status_name = EXCLUDED.status_name,
                last_modified = EXCLUDED.last_modified,
                is_operational_2018_to_19 = EXCLUDED.is_operational_2018_to_19,
                is_operational_2019_to_20 = EXCLUDED.is_operational_2019_to_20,
                is_operational_2020_to_21 = EXCLUDED.is_operational_2020_to_21,
                is_operational_2021_to_22 = EXCLUDED.is_operational_2021_to_22,
                is_operational_2022_to_23 = EXCLUDED.is_operational_2022_to_23,
                scrape_status = CASE 
                    WHEN schools_udise_data.scrape_status = 'success' THEN 'success' 
                    ELSE EXCLUDED.scrape_status 
                END;
        """, (
            s.get("schoolId"), udise_code, s.get("schoolName"), school_status, status_name, s.get("lastmodifiedTime"),
            s.get("stateId"), s.get("stateCd"), s.get("stateName"),
            s.get("districtId"), s.get("districtCd"), s.get("districtName"),
            s.get("blockId"), s.get("blockCd"), b['blockName'],  # Use blockName from hierarchy loop
            s.get("clusterId"), s.get("clusterCd"), c['clusterName'], # Use clusterName from hierarchy loop
            s.get("villageId"), s.get("villWardCd"), s.get("villageName"),
            s.get("pincode"), s.get("address"), s.get("email"),
            s.get("lgdStateId"), s.get("lgdDistrictCd"), s.get("lgdBlockId"), s.get("lgdvillageId"), s.get("lgdvillName"),
            s.get("lgdpanchayatId"), s.get("lgdvillpanchayatName"),
            s.get("schLocRuralUrban"), s.get("schLocDesc"),
            s.get("schCategoryId"), s.get("schCatDesc"),
            s.get("schType"), s.get("schTypeDesc"),
            s.get("schMgmtId"), s.get("schMgmtDesc"),
            s.get("schmgmtParentId"), s.get("schMgmtDescSt"),
            s.get("schBroadMgmtId"), s.get("classFrm"), s.get("classTo"),
            s.get("isOperational2018To19"), s.get("isOperational2019To20"), s.get("isOperational2020To21"), s.get("isOperational2021To22"), s.get("isOperational2022To23"),
            scrape_status
        ))
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(f"  ! SQL Error for {udise_code}: {e}")
    finally:
        cursor.close()

def scan_state(state_name):
    state_id = STATES.get(state_name.upper())
    if not state_id:
        logger.error(f"Invalid state: {state_name}")
        return

    logger.info(f"--- BEGINNING DISCOVERY SCAN: {state_name} ---")
    conn = get_db_connection()
    
    # 1. Get Districts
    districts = fetch_json(DISTRICTS_API, {"stateId": state_id, "yearId": 0})
    if not districts: return

    for d in districts:
        d_id = d['districtId']
        logger.info(f"District: {d['districtName']} (ID: {d_id})")
        
        # 2. Get Blocks
        blocks = fetch_json(BLOCKS_API, {"districtId": d_id, "yearId": 0})
        if not blocks: continue
        
        for b in blocks:
            b_id = b['blockId']
            logger.info(f"  Block: {b['blockName']} (ID: {b_id})")
            
            # 3. Get Clusters
            clusters = fetch_json(CLUSTERS_API, {"blockId": b_id, "yearId": 0})
            if not clusters: continue
            
            for c in clusters:
                c_id = c['clusterId']
                # logger.info(f"    Cluster: {c['clusterName']} (ID: {c_id})")
                
                # 4. Get Schools by Region
                params = {
                    "stateId": state_id, "districtId": d_id, "blockId": b_id, "clusterId": c_id,
                    "villageId": "", "categoryId": "", "managementId": ""
                }
                data = fetch_json(REGIONAL_URL, params)
                schools = data.get("content", []) if data else []
                
                if schools:
                    logger.info(f"      ✓ Cluster {c['clusterName']}: Found {len(schools)} schools")
                    for s in schools:
                        upsert_school(conn, s, d, b, c)
                
                time.sleep(0.05) # Polite delay
    
    conn.close()
    logger.info(f"--- COMPLETED DISCOVERY SCAN: {state_name} ---")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True)
    args = parser.parse_args()
    
    scan_state(args.state)
