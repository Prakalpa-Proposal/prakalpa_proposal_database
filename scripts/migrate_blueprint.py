import os
import psycopg2
from psycopg2.extras import Json
from dotenv import load_dotenv

# Explicitly target the database/.env file
env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
load_dotenv(dotenv_path=env_path)

def migrate_live_db():
    conn = psycopg2.connect(os.getenv("DATABASE_URL"))
    cur = conn.cursor()
    
    # Fetch the default blueprint
    cur.execute("SELECT id, sections_config FROM proposal_blueprints WHERE is_default = TRUE;")
    rows = cur.fetchall()
    
    for row_id, config in rows:
        # Inject the schema uniformly across all sections
        for section_key, section_data in config.items():
            if section_key == "COSTS_BUDGETS":
                section_data["math_dependencies"] = ["SOLUTION_DESIGN", "BENEFICIARIES"]
            else:
                section_data["math_dependencies"] = []
                
        # Update the live DB
        cur.execute(
            "UPDATE proposal_blueprints SET sections_config = %s WHERE id = %s;",
            (Json(config), row_id)
        )
        
    conn.commit()
    cur.close()
    conn.close()
    print("Live DB blueprint successfully migrated with uniform math_dependencies.")

if __name__ == "__main__":
    migrate_live_db()
