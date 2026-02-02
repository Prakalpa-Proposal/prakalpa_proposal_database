-- Hierarchy Tables

CREATE TABLE IF NOT EXISTS states (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    url_slug VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS districts (
    id SERIAL PRIMARY KEY,
    state_id INTEGER REFERENCES states(id),
    name VARCHAR(255) NOT NULL,
    url_slug VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(state_id, url_slug)
);

CREATE TABLE IF NOT EXISTS blocks (
    id SERIAL PRIMARY KEY,
    district_id INTEGER REFERENCES districts(id),
    name VARCHAR(255) NOT NULL,
    url_slug VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(district_id, url_slug)
);

CREATE TABLE IF NOT EXISTS clusters (
    id SERIAL PRIMARY KEY,
    block_id INTEGER REFERENCES blocks(id),
    name VARCHAR(255) NOT NULL,
    url_slug VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(block_id, url_slug)
);

-- Main School Data Table

CREATE TABLE IF NOT EXISTS schools (
    id SERIAL PRIMARY KEY,
    udise_code VARCHAR(50) NOT NULL UNIQUE, -- Critical for deduplication
    name VARCHAR(255) NOT NULL,
    cluster_id INTEGER REFERENCES clusters(id),
    
    category VARCHAR(100),       -- e.g. "Primary only (1-5)"
    management VARCHAR(100),     -- e.g. "Department of Education"
    medium_of_instruction VARCHAR(100), -- e.g. "Kannada"
    
    address TEXT,
    pincode VARCHAR(20),
    
    -- Review Ratings from source
    rating VARCHAR(50), 
    
    -- Flexible Infrastructure Data (e.g. Classrooms: 1, Computers: 2)
    infrastructure JSONB DEFAULT '{}'::jsonb,
    
    url_slug VARCHAR(255),
    active BOOLEAN DEFAULT TRUE,
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for frequent queries
CREATE INDEX idx_schools_cluster ON schools(cluster_id);
CREATE INDEX idx_schools_udise ON schools(udise_code);
CREATE INDEX idx_districts_state ON districts(state_id);

-- Create Villages Table (Master List)
CREATE TABLE IF NOT EXISTS villages (
    id SERIAL PRIMARY KEY,
    lgd_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    district_name VARCHAR(255),
    state_name VARCHAR(255),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_villages_lgd_code ON villages(lgd_code);

-- Create Village Demographics Table (JJM Data)
CREATE TABLE IF NOT EXISTS village_demographics (
    id SERIAL PRIMARY KEY,
    village_id INTEGER REFERENCES villages(id),
    lgd_code VARCHAR(20) NOT NULL,
    total_population INTEGER,
    households INTEGER,
    sc_population INTEGER,
    st_population INTEGER,
    general_population INTEGER,
    source VARCHAR(50) DEFAULT 'JJM_LIVE_SCRAPER',
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'SUCCESS'
);

CREATE INDEX IF NOT EXISTS idx_village_demographics_lgd_code ON village_demographics(lgd_code);

-- Migration: Add User Login and Organization Management Tables
-- Date: 2026-02-01

-- 1. Organizations Table
CREATE TABLE IF NOT EXISTS organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(500) NOT NULL,
    url VARCHAR(500),
    email VARCHAR(150),
    phone VARCHAR(20) NOT NULL,
    poc_name VARCHAR(100) NOT NULL,
    address VARCHAR(500),
    state VARCHAR(100),
    district VARCHAR(100),
    city VARCHAR(100),
    pincode VARCHAR(20),
    domain JSONB, -- Storing domain as JSONB for flexibility
    active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_organizations_name ON organizations(name);

-- 2. Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    userid VARCHAR(20) NOT NULL,
    password VARCHAR(255) NOT NULL, -- Hashed password
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    org_id INTEGER REFERENCES organizations(id),
    active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_users_userid ON users(userid);
CREATE INDEX IF NOT EXISTS idx_users_org_id ON users(org_id);

-- 3. Default Organization Entry
INSERT INTO organizations (
    id, name, url, email, phone, poc_name, address, 
    state, district, city, pincode, domain, active, created_by
) VALUES (
    1, 
    'Prakalpa Soujanya Foundation', 
    'https://www.prakalpasooujanya.g', 
    'contact@prakalpasoujanya.org', 
    '+91 9845024536', 
    'Vijay Paul', 
    'Indiranagar', 
    'Karnataka', 
    'Bangalore Urban', 
    'Bangalore', 
    '560038', 
    '"Social Sector Project Management"', -- JSONB string
    TRUE,
    'SYSTEM'
) ON CONFLICT (id) DO NOTHING;

-- 4. Default Admin User Entry
-- Password: admin123 (hashed with bcrypt)
INSERT INTO users (
    id, userid, password, first_name, last_name, email, 
    phone, org_id, active, created_by
) VALUES (
    1,
    'admin',
    '$2b$12$1djn./SUAcvUYO3Yx7eUKOAxzmNtfwUpdeAV89DovnUU4g60FFOyq',
    'Prakalpa',
    'Administrator',
    'contact@prakalpasoujanya.org',
    '+91 9845024536', -- Using Org phone as default for admin
    1,
    TRUE,
    'SYSTEM'
) ON CONFLICT (id) DO NOTHING;

-- Reset sequence to avoid collision if id 1 was forced
SELECT setval('organizations_id_seq', (SELECT MAX(id) FROM organizations));
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));

-- Migration: Add Proposal Master & Section Metadata Tables
-- Author: Antigravity AI
-- Date: 2026-02-01

-- Table 1: Proposal Master (Multi-NGO Support)
CREATE TABLE IF NOT EXISTS proposal_master (
    proposal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ngo_id INTEGER REFERENCES organizations(id), -- UPDATED to Integer FK
    ngo_name VARCHAR(255) NOT NULL,
    domain VARCHAR(50) NOT NULL,
    sub_domain VARCHAR(100),
    location_village VARCHAR(255),
    location_district VARCHAR(255),
    location_state VARCHAR(255),
    location_lgd_code BIGINT,
    document_name VARCHAR(500),
    document_url TEXT,
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_proposal_ngo ON proposal_master(ngo_id);
CREATE INDEX IF NOT EXISTS idx_proposal_domain ON proposal_master(domain);
CREATE INDEX IF NOT EXISTS idx_proposal_created ON proposal_master(created_at);

-- Table 2: AI Response Metadata (Responses API fields)
CREATE TABLE IF NOT EXISTS ai_response_metadata (
    id BIGSERIAL PRIMARY KEY,
    proposal_id UUID NOT NULL REFERENCES proposal_master(proposal_id) ON DELETE CASCADE,
    section_code VARCHAR(100) NOT NULL,
    version INT NOT NULL DEFAULT 1,
    content TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- OpenAI Responses API Metadata
    openai_response_id VARCHAR(255),
    openai_model VARCHAR(100),
    created_at_openai BIGINT,
    status VARCHAR(50),
    completed_at_openai BIGINT,
    error_message TEXT,
    
    -- Token Usage (Responses API naming)
    input_tokens INT,
    output_tokens INT,
    total_tokens INT,
    
    -- Context Chaining
    previous_response_id VARCHAR(255),
    
    -- Configuration
    temperature DECIMAL(3,2),
    top_p DECIMAL(3,2),
    
    -- Reasoning
    reasoning_summary TEXT,
    
    -- Internal Metadata
    generation_time_ms INT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_response_proposal ON ai_response_metadata(proposal_id, section_code);
CREATE INDEX IF NOT EXISTS idx_ai_response_active ON ai_response_metadata(proposal_id, section_code, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_ai_response_prev_id ON ai_response_metadata(previous_response_id);

-- Constraint: Only one active version per section
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_section 
ON ai_response_metadata(proposal_id, section_code) 
WHERE is_active = TRUE;

-- Trigger: Auto-cleanup old versions (keep max 5)
CREATE OR REPLACE FUNCTION cleanup_old_versions()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM ai_response_metadata
    WHERE proposal_id = NEW.proposal_id
      AND section_code = NEW.section_code
      AND id NOT IN (
          SELECT id FROM ai_response_metadata
          WHERE proposal_id = NEW.proposal_id
            AND section_code = NEW.section_code
          ORDER BY version DESC
          LIMIT 5
      );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_cleanup_versions ON ai_response_metadata;
CREATE TRIGGER trigger_cleanup_versions
AFTER INSERT ON ai_response_metadata
FOR EACH ROW EXECUTE FUNCTION cleanup_old_versions();
