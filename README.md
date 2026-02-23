# Prakalpa Proposal Database

This repository contains the database initialization scripts for the Prakalpa Proposal application.

## Contents
- `init.sql`: Main entry point for PostgreSQL initialization.
- `scripts/`: Python and Shell scripts for the "Foundation Data" strategy (Geography, Demographics, and Amenities).
- `data/`: Local storage for processed datasets.

## 📊 Database Schema

The system follows a **Foundation Data** strategy, pre-populating geography and social infrastructure intelligence:

**Core Persistence:**
- `proposal_master` - Session tracking with `org_id` ownership, `title` identity, `blueprint_id` pinning, `location_pincode` persistence, and Lifecycle audit fields (`archived_at`).
- `proposal_blueprints` - Dynamic configuration storage for section dependencies, UI layout, and LLM parameters.
- `ai_response_metadata` - Versioned AI content and Manual Drafts with `source` tracking (AI vs User).

**Foundation Data:**
- `states`, `districts`, `blocks`, `clusters` - Hierarchical geography.
- `villages` - Master record for habitations with unique LGD codes.
- `village_demographics` - SC/ST population, household stats, and growth trends from NDAP.
- `schools` - Granular infrastructure and enrollment data.

**Domain Data Summary:**
- `jjm_population_data` - Population data from Jal Jeevan Mission.
- `schools_udise_data` - Detailed school infrastructure and enrollment metrics (In-Sync).


## 🚀 Data Foundation Setup

Before generating proposals, you must initialize the geographic and demographic foundation:

1. **Initialize LGD Hierarchy**:
   ```bash
   cd scripts
   python fetch_lgd_master.py  # Fetches latest geography from LGD API
   ```

2. **Ingest NDAP Demographics**:
   ```bash
   # Ingest National Data Analytics Platform statistics
   python ingest_ndap_9307.py
   ```

3. **UDISE+ Infrastructure Sync**:
   ```bash
   cd scripts
   python scrape_udise_data.py --state KARNATAKA  # Sync detailed school data
   ```

4. **Master Setup**:
   Refer to `./scripts/setup_data.sh` for an automated foundational sync.

## Usage
This file is mounted to `/docker-entrypoint-initdb.d/init.sql` in the Postgres Docker container.

## Schema Diagram
```mermaid
erDiagram
    states ||--o{ districts : "has"
    states {
        int id PK
        string name
        string url_slug
        timestamp created_at
    }

    districts ||--o{ blocks : "has"
    districts {
        int id PK
        int state_id FK
        string name
        string url_slug
    }

    blocks ||--o{ clusters : "has"
    blocks {
        int id PK
        int district_id FK
        string name
        string url_slug
    }

    clusters ||--o{ schools : "has"
    clusters {
        int id PK
        int block_id FK
        string name
        string url_slug
    }

    schools {
        int id PK
        string udise_code UK
        string name
        int cluster_id FK
        string category
        string management
        string medium_of_instruction
        text address
        string pincode
        string rating
        jsonb infrastructure
    }

    villages ||--o{ village_demographics : "has"
    villages {
        int id PK
        string lgd_code UK
        string name
        string district_name
        string state_name
        boolean active
    }

    village_demographics {
        int id PK
        int village_id FK
        string lgd_code
        int total_population
        int households
        int sc_population
        int st_population
        int general_population
        string source
        timestamp fetched_at
    }

    organizations ||--o{ users : "has"
    organizations {
        int id PK
        string name
        string url
        string email
        string phone
        string poc_name
        string address
        string state
        string district
        string city
        string pincode
        jsonb domain
        boolean active
    }

    users {
        int id PK
        string userid UK
        string password
        string first_name
        string last_name
        string email
        string phone
        int org_id FK
        boolean active
    }

    proposal_blueprints ||--o{ proposal_master : "governs"
    proposal_blueprints {
        uuid id PK
        string version_label
        jsonb sections_config
        jsonb ui_config
        boolean is_default
        boolean is_published
    }

    organizations ||--o{ proposal_master : "creates"
    proposal_master ||--o{ ai_response_metadata : "contains"
    proposal_master {
        uuid proposal_id PK
        uuid blueprint_id FK
        int org_id FK
        string ngo_name
        string domain
        string sub_domain
        string title
        jsonb tags
        string location_village
        string location_district
        string location_state
        bigint location_lgd_code
        string status
        timestamp created_at
        timestamp updated_at
        string created_by
        string granularity
        string location_pincode
        timestamp archived_at
        string archived_by
    }

    ai_response_metadata {
        bigint id PK
        uuid proposal_id FK
        string section_code
        int version
        text content
        boolean is_active
        string openai_response_id
        string openai_model
        string status
        int input_tokens
        int output_tokens
        int total_tokens
        string previous_response_id
        decimal temperature
        decimal top_p
        text reasoning_summary
        int generation_time_ms
        string source
    }
```
