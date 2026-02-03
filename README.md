# Prakalpa Proposal Database

This repository contains the database initialization scripts for the Prakalpa Proposal application.

## Contents
- `init.sql`: Main entry point for PostgreSQL initialization. Creates tables and default data.

## 📊 Database Schema

The system uses PostgreSQL with the following main tables:

**Core Persistence:**
- `proposal_master` - Top-level session tracking for proposals
- `ai_response_metadata` - Stores every AI generation (versioned) with token usage and context chaining

**Domain Data:**
- `states` - Indian states
- `districts` - Districts within states
- `blocks` - Administrative blocks
- `clusters` - School clusters
- `schools` - Individual school records with demographic data
- `jjm_population_data` - Population data from Jal Jeevan Mission


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

    organizations ||--o{ proposal_master : "creates"
    proposal_master ||--o{ ai_response_metadata : "contains"
    proposal_master {
        uuid proposal_id PK
        int ngo_id FK
        string ngo_name
        string domain
        string sub_domain
        string location_village
        string location_district
        string location_state
        bigint location_lgd_code
        string status
        timestamp created_at
        timestamp updated_at
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
    }
```
