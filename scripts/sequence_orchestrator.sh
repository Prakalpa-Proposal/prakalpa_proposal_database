#!/bin/bash
# sequence_orchestrator.sh
# Automates the sequential deep mining transition across multiple states.

VENV_PYTHON="/projects/git/builds/prakalpa_proposal/backend/venv/bin/python3"
SCRIPT="enrich_registry.py"
LOG_DIR="../logs/udise_scraper"
GOA_PID_FILE="enrichment_goa.pid"

# State Queue in Order of Priority
STATES=("GOA" "KARNATAKA" "KERALA" "ANDHRA PRADESH" "TELANGANA" "TAMIL NADU")

echo "$(date): --- ORCHESTRATOR STARTED ---" >> $LOG_DIR/orchestrator.log

# 1. Wait for current Goa Pilot (if running)
if [ -f "$GOA_PID_FILE" ]; then
    GPID=$(cat "$GOA_PID_FILE")
    if ps -p $GPID > /dev/null; then
        echo "$(date): Waiting for Goa Pilot (PID: $GPID) to finish..." >> $LOG_DIR/orchestrator.log
        while ps -p $GPID > /dev/null; do
            sleep 60
        done
        echo "$(date): Goa Pilot finished." >> $LOG_DIR/orchestrator.log
    fi
fi

# 2. Iterate through the State Queue
for STATE in "${STATES[@]}"; do
    STATE_FILE_NAME=$(echo "$STATE" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    echo "$(date): Launching $STATE State Push..." >> $LOG_DIR/orchestrator.log
    
    nohup $VENV_PYTHON $SCRIPT --state "$STATE" > $LOG_DIR/enrich_$STATE_FILE_NAME.log 2>&1 &
    CURRENT_PID=$!
    echo $CURRENT_PID > "enrichment_${STATE_FILE_NAME}.pid"
    
    echo "$(date): $STATE started with PID: $CURRENT_PID. Waiting for completion..." >> $LOG_DIR/orchestrator.log
    
    while ps -p $CURRENT_PID > /dev/null; do
        sleep 300 # Check every 5 minutes
    done
    
    echo "$(date): $STATE enrichment completed. Proceeding to next state..." >> $LOG_DIR/orchestrator.log
    sleep 30
done

echo "$(date): --- ALL PLANNED STATES COMPLETED ---" >> $LOG_DIR/orchestrator.log
