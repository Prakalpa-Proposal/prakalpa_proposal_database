# Prakalpa Proposal Database

This repository contains the database initialization scripts for the Prakalpa Proposal application.

## Contents
- `init.sql`: Main entry point for PostgreSQL initialization. Creates tables and default data.

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
        jsonb infrastructure
    }

    villages ||--o{ village_demographics : "has"
    villages {
        int id PK
        string lgd_code UK
        string name
        string district_name
    }

    village_demographics {
        int id PK
        int village_id FK
        int total_population
    }

    organizations ||--o{ users : "has"
    organizations {
        int id PK
        string name
        string email
        string poc_name
        boolean active
    }

    users {
        int id PK
        string userid UK
        string email
        int org_id FK
        boolean active
    }

    organizations ||--o{ proposal_master : "creates"
    proposal_master ||--o{ ai_response_metadata : "contains"
    proposal_master {
        uuid proposal_id PK
        int ngo_id FK
        string status
        string location_village
    }

    ai_response_metadata {
        bigint id PK
        uuid proposal_id FK
        string section_code
        int version
        text content
    }
```
