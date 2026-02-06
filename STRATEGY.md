# Database Loading Strategy

This document outlines the strategy for loading large-scale datasets into the Prakalpa Proposal database.

## Master Setup Script

The `database/scripts/setup_data.sh` script is the automated entry point for all foundation data.

**Usage:**
```bash
cd database/scripts
./setup_data.sh --all              # Run all ingestion steps
./setup_data.sh --lgd              # Just LGD Geography
./setup_data.sh --ndap-stats       # Just District Demographics
./setup_data.sh --ndap-amenities   # Just Village Amenities
```

## 1. Large Datasets (NDAP 7121 Village Amenities)

The `village_amenities_raw` dataset is approximately 2.3GB. The source file should be named `data_7121.csv` and placed in `database/source_data_files/NDAP_DS_7121/`.

### Strategy: PostgreSQL COPY
The setup script uses the high-performance `COPY` command to stream the CSV data directly into the database.

**Manual Command:**
```bash
cat database/source_data_files/NDAP_DS_7121/data_7121.csv | docker exec -i prakalpa_proposal-db-1 psql -U ravi -d prakalpa_proposal -c "COPY village_amenities_raw FROM STDIN WITH (FORMAT csv, HEADER true);"
```

**Why COPY?**
- **Performance**: `COPY` is significantly faster than multiple `INSERT` statements.
- **Memory Efficiency**: Streaming from `STDIN` avoids loading the entire file into memory.

## 2. Foundational Master Data (LGD Master)

**LGD Master Sync:**
```bash
cd database/scripts
./setup_data.sh --lgd
```

## 3. Application Metadata (NDAP 9307 Demographics)

**District Context Ingestion:**
```bash
cd database/scripts
# Default expects 9307_all_files.zip in source_data_files/ 
./setup_data.sh --ndap-stats
# Or specify a custom path
./setup_data.sh --ndap-stats --file /path/to/custom_9307.zip
```

## 4. Standalone Environment

The `database/` folder is designed to be standalone. It contains:
- `init.sql`: The full authoritative schema.
- `.env`: Database connection parameters.
- `scripts/`: Automated and manual runners for foundational data.
- `source_data_files/`: Raw source data (CSVs, Zips).

This independence allows the database to be primed and maintained without running the Flask application.
