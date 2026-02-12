-- ===========================================
-- CORRECTED MIGRATION SCRIPTS
-- These handle BOTH existing databases AND fresh installs
-- ===========================================

-- Part 1: Add missing columns to organizations table
-- These columns exist in models.py but not in init.sql

DO $$
BEGIN
    -- Add ngo_darpan_id if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='ngo_darpan_id') THEN
        ALTER TABLE organizations ADD COLUMN ngo_darpan_id VARCHAR(100) UNIQUE;
    END IF;

    -- Add pan_number if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='pan_number') THEN
        ALTER TABLE organizations ADD COLUMN pan_number VARCHAR(20);
    END IF;

    -- Add status if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='status') THEN
        ALTER TABLE organizations ADD COLUMN status VARCHAR(50) DEFAULT 'PENDING';
    END IF;

    -- Add url if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='url') THEN
        ALTER TABLE organizations ADD COLUMN url VARCHAR(500);
    END IF;

    -- Add email if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='email') THEN
        ALTER TABLE organizations ADD COLUMN email VARCHAR(150);
    END IF;

    -- Add phone if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='phone') THEN
        ALTER TABLE organizations ADD COLUMN phone VARCHAR(20);
    END IF;

    -- Add poc_name if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='poc_name') THEN
        ALTER TABLE organizations ADD COLUMN poc_name VARCHAR(100);
    END IF;

    -- Add address if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='address') THEN
        ALTER TABLE organizations ADD COLUMN address VARCHAR(500);
    END IF;

    -- Add state if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='state') THEN
        ALTER TABLE organizations ADD COLUMN state VARCHAR(100);
    END IF;

    -- Add district if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='district') THEN
        ALTER TABLE organizations ADD COLUMN district VARCHAR(100);
    END IF;

    -- Add city if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='city') THEN
        ALTER TABLE organizations ADD COLUMN city VARCHAR(100);
    END IF;

    -- Add pincode if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='pincode') THEN
        ALTER TABLE organizations ADD COLUMN pincode VARCHAR(20);
    END IF;

    -- Add active if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='active') THEN
        ALTER TABLE organizations ADD COLUMN active BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add created_by if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='created_by') THEN
        ALTER TABLE organizations ADD COLUMN created_by VARCHAR(255);
    END IF;

    -- Add quota management fields
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='max_proposals_per_month') THEN
        ALTER TABLE organizations ADD COLUMN max_proposals_per_month INTEGER DEFAULT 1000;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='token_limit') THEN
        ALTER TABLE organizations ADD COLUMN token_limit INTEGER DEFAULT 10000000;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='organizations' AND column_name='spent_tokens') THEN
        ALTER TABLE organizations ADD COLUMN spent_tokens INTEGER DEFAULT 0;
    END IF;
END $$;

-- Update Prakalpa Foundation to ACTIVE if it exists
UPDATE organizations SET status = 'ACTIVE', active = TRUE 
WHERE id = 1 AND status IS NOT NULL;

-- Part 2: Add missing columns to users table

DO $$
BEGIN
    -- Add userid if it doesn't exist (for login)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='userid') THEN
        ALTER TABLE users ADD COLUMN userid VARCHAR(20) UNIQUE;
    END IF;

    -- Add password if it doesn't exist (renamed from password_hash)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='password') THEN
        ALTER TABLE users ADD COLUMN password VARCHAR(255);
    END IF;

    -- Add first_name if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='first_name') THEN
        ALTER TABLE users ADD COLUMN first_name VARCHAR(100);
    END IF;

    -- Add last_name if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='last_name') THEN
        ALTER TABLE users ADD COLUMN last_name VARCHAR(100);
    END IF;

    -- Add phone if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='phone') THEN
        ALTER TABLE users ADD COLUMN phone VARCHAR(20);
    END IF;

    -- Add active if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='active') THEN
        ALTER TABLE users ADD COLUMN active BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add created_by if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='created_by') THEN
        ALTER TABLE users ADD COLUMN created_by VARCHAR(255);
    END IF;

    -- Add is_org_admin (NEW for this deployment)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='is_org_admin') THEN
        ALTER TABLE users ADD COLUMN is_org_admin BOOLEAN DEFAULT FALSE;
    END IF;

    -- Ensure role column exists (should already exist from init.sql)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='role') THEN
        ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'USER';
    END IF;
END $$;

-- Part 3: Create thematic_domains table if it doesn't exist

CREATE TABLE IF NOT EXISTS thematic_domains (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Part 4: Create organization_domains junction table if it doesn't exist

CREATE TABLE IF NOT EXISTS organization_domains (
    organization_id INTEGER REFERENCES organizations(id),
    domain_id INTEGER REFERENCES thematic_domains(id),
    PRIMARY KEY (organization_id, domain_id)
);

-- Part 5: Create tables for NGO registration workflows

CREATE TABLE IF NOT EXISTS ngo_onboarding_requests (
    id SERIAL PRIMARY KEY,
    requested_by INTEGER REFERENCES users(id) ON DELETE CASCADE,
    ngo_name VARCHAR(500) NOT NULL,
    ngo_darpan_id VARCHAR(100) NOT NULL,
    pan_number VARCHAR(20),
    email VARCHAR(150),
    phone VARCHAR(20) NOT NULL,
    poc_name VARCHAR(100) NOT NULL,
    address VARCHAR(500),
    state VARCHAR(100),
    district VARCHAR(100),
    city VARCHAR(100),
    pincode VARCHAR(20),
    domain_ids INTEGER[],
    status VARCHAR(50) DEFAULT 'PENDING',
    requested_at TIMESTAMP DEFAULT NOW(),
    reviewed_at TIMESTAMP,
    reviewed_by VARCHAR(255),
    rejection_reason TEXT,
    created_org_id INTEGER REFERENCES organizations(id)
);

CREATE INDEX IF NOT EXISTS idx_ngo_onboarding_status ON ngo_onboarding_requests(status);
CREATE INDEX IF NOT EXISTS idx_ngo_onboarding_requested_by ON ngo_onboarding_requests(requested_by);

CREATE TABLE IF NOT EXISTS ngo_join_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    org_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'PENDING',
    requested_at TIMESTAMP DEFAULT NOW(),
    reviewed_at TIMESTAMP,
    reviewed_by VARCHAR(255),
    rejection_reason TEXT,
    UNIQUE(user_id, org_id, status)
);

CREATE INDEX IF NOT EXISTS idx_ngo_join_user ON ngo_join_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_ngo_join_org ON ngo_join_requests(org_id);
CREATE INDEX IF NOT EXISTS idx_ngo_join_status ON ngo_join_requests(status);

-- Part 6: Seed initial thematic domains

INSERT INTO thematic_domains (name, description) VALUES
    ('WASH / JJM', 'Water, Sanitation and Hygiene / Jal Jeevan Mission'),
    ('Education', 'Primary and Secondary Education, Literacy'),
    ('Healthcare', 'Public Health, Maternal Care, Nutrition'),
    ('Livelihoods', 'Skill Development, Agriculture, SHGs'),
    ('Environment', 'Conservation, Climate Action, Waste Management'),
    ('Women Empowerment', 'Gender Equality, Financial Independence')
ON CONFLICT (name) DO NOTHING;
