#!/bin/bash

# Prakalpa Proposal - Master Database Setup Script
# Automatically ingests foundational data (LGD, NDAP, Amenities)

# Set base directory (one level up from scripts/)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$BASE_DIR/scripts"

# Load .env variables
if [ -f "$BASE_DIR/.env" ]; then
    export $(grep -v '^#' "$BASE_DIR/.env" | xargs)
else
    echo "Error: .env file not found in $BASE_DIR"
    exit 1
fi

DB_USER=${DB_USER:-ravi}
DB_NAME=${DB_NAME:-prakalpa_proposal}

function show_help {
    echo "Usage: ./setup_data.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all              Run all ingestion steps"
    echo "  --lgd              Sync LGD Master (Full Geography from API)"
    echo "  --ndap-stats       Ingest District Demographics (NDAP 9307)"
    echo "  --ndap-amenities   Ingest Village Amenities (NDAP 7121 - Massive CSV)"
    echo "  --file [PATH]      Specify path to source file (used with --ndap-stats)"
    echo "  --help             Show this help message"
}

# --- Ingestion Functions ---

function ingest_lgd {
    echo ">>> Starting LGD Master Sync..."
    python3 "$SCRIPT_DIR/fetch_lgd_master.py"
}

function ingest_9307 {
    local source_file=$1
    if [ -z "$source_file" ]; then
        source_file="$BASE_DIR/source_data_files/9307_all_files.zip"
    fi

    if [ -f "$source_file" ]; then
        echo ">>> Ingesting District Demographics (9307) from $source_file..."
        python3 "$SCRIPT_DIR/ingest_ndap_9307.py" --file "$source_file"
    else
        echo "Error: Source file $source_file not found. Skipping NDAP 9307."
    fi
}

function ingest_7121 {
    local csv_file="$BASE_DIR/source_data_files/NDAP_DS_7121/data_7121.csv"
    
    if [ -f "$csv_file" ]; then
        echo ">>> Ingesting Village Amenities (7121) via COPY from $csv_file..."
        # Note: Using docker exec assuming DB is running in container named prakalpa_proposal-db-1
        cat "$csv_file" | docker exec -i prakalpa_proposal-db-1 psql -U "$DB_USER" -d "$DB_NAME" -c "COPY village_amenities_raw FROM STDIN WITH (FORMAT csv, HEADER true);"
        echo ">>> Amenities ingestion complete."
    else
        echo "Error: Source file $csv_file not found. Skipping NDAP 7121."
    fi
}

# --- Argument Parsing ---

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

SOURCE_PATH=""
RUN_LGD=false
RUN_9307=false
RUN_7121=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            RUN_LGD=true
            RUN_9307=true
            RUN_7121=true
            shift
            ;;
        --lgd)
            RUN_LGD=true
            shift
            ;;
        --ndap-stats)
            RUN_9307=true
            shift
            ;;
        --ndap-amenities)
            RUN_7121=true
            shift
            ;;
        --file)
            SOURCE_PATH="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# --- Execution ---

if [ "$RUN_LGD" = true ]; then ingest_lgd; fi
if [ "$RUN_9307" = true ]; then ingest_9307 "$SOURCE_PATH"; fi
if [ "$RUN_7121" = true ]; then ingest_7121; fi

echo "Done."
