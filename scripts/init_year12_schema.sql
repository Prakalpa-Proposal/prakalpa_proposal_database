-- 1. Backup legacy Year 11 data (rename current table)
ALTER TABLE IF EXISTS schools_udise_data RENAME TO schools_udise_data_v1_bak;

-- 2. Create the fresh Year 12 table with flattened schema
CREATE TABLE schools_udise_data (
    -- Identity
    school_id INTEGER NOT NULL,
    year_id INTEGER NOT NULL DEFAULT 12,
    udise_code VARCHAR(11) NOT NULL,
    school_name VARCHAR,
    school_status INTEGER,
    status_name VARCHAR,
    last_modified TIMESTAMP,
    
    -- Geographic & LGD Hierarchy
    state_id INTEGER,
    state_cd VARCHAR,
    state_name VARCHAR,
    district_id INTEGER,
    district_cd VARCHAR,
    district_name VARCHAR,
    block_id INTEGER,
    block_cd VARCHAR,
    block_name VARCHAR,
    cluster_id INTEGER,
    cluster_cd VARCHAR,
    cluster_name VARCHAR,
    village_id INTEGER,
    vill_ward_cd VARCHAR,
    village_name VARCHAR,
    pincode INTEGER,
    address TEXT,
    email VARCHAR,
    
    -- LGD Codes
    lgd_state_id INTEGER,
    lgd_district_id INTEGER,
    lgd_block_id INTEGER,
    lgd_village_id VARCHAR,
    lgd_vill_name VARCHAR,
    lgd_panchayat_id VARCHAR,
    lgd_vill_panchayat_name VARCHAR,
    
    -- Urban/Rural Metadata
    sch_loc_rural_urban INTEGER,
    sch_loc_desc VARCHAR,
    
    -- Categories & Management
    sch_category_id INTEGER,
    sch_cat_desc VARCHAR,
    sch_type INTEGER,
    sch_type_desc VARCHAR,
    sch_mgmt_id INTEGER,
    sch_mgmt_desc VARCHAR,
    sch_mgmt_parent_id INTEGER,
    sch_mgmt_desc_st VARCHAR,
    sch_broad_mgmt_id INTEGER,
    class_frm INTEGER,
    class_to INTEGER,
    
    -- Operational History
    is_operational_2018_to_19 INTEGER,
    is_operational_2019_to_20 INTEGER,
    is_operational_2020_to_21 INTEGER,
    is_operational_2021_to_22 INTEGER,
    is_operational_2022_to_23 INTEGER,
    
    -- Summary Analytics (Aggregated from Pass 2)
    total_students INTEGER,
    total_boys INTEGER,
    total_girls INTEGER,
    total_teachers INTEGER,
    has_internet BOOLEAN,
    has_library BOOLEAN,
    has_playground BOOLEAN,
    has_electricity BOOLEAN,
    
    -- Scraper Metadata
    scrape_status VARCHAR DEFAULT 'pending',
    error_message TEXT,
    last_scraped_at TIMESTAMP DEFAULT NOW(),
    
    -- Deep-Scrape Blobs (JSONB)
    basic_info JSONB,
    report_card JSONB,
    facility_data JSONB,
    profile_data JSONB,
    enrollment_social JSONB,
    enrollment_religion JSONB,
    enrollment_mainstreamed JSONB,
    enrollment_ews JSONB,
    enrollment_rte JSONB,

    -- Constraints
    PRIMARY KEY (school_id, year_id)
);

-- 3. Create Performance Indexes
CREATE INDEX idx_udise_code ON schools_udise_data (udise_code);
CREATE INDEX idx_lgd_village_id ON schools_udise_data (lgd_village_id);
CREATE INDEX idx_pincode ON schools_udise_data (pincode);
CREATE INDEX idx_cluster_id ON schools_udise_data (cluster_id);
CREATE INDEX idx_scrape_status ON schools_udise_data (scrape_status);
