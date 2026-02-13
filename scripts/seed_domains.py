import os
import sys
import psycopg2
from dotenv import load_dotenv

# Setup paths relative to script location
BASE_DIR = os.path.join(os.path.dirname(__file__), '..')
env_path = os.path.join(BASE_DIR, '.env')
load_dotenv(env_path)

DB_URL = os.getenv("DATABASE_URL")

def get_db_connection():
    if not DB_URL:
        print("Error: DATABASE_URL not found in .env")
        sys.exit(1)
    return psycopg2.connect(DB_URL)

def seed_domains():
    domains = [
        {"name": "WASH / JJM", "description": "Water, Sanitation and Hygiene / Jal Jeevan Mission"},
        {"name": "Education", "description": "Primary and Secondary Education, Literacy"},
        {"name": "Healthcare", "description": "Public Health, Maternal Care, Nutrition"},
        {"name": "Livelihoods", "description": "Skill Development, Agriculture, SHGs"},
        {"name": "Environment", "description": "Conservation, Climate Action, Waste Management"},
        {"name": "Women Empowerment", "description": "Gender Equality, Financial Independence"}
    ]
    
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        print(f"Connected to database. Starting domain seeding...")
        
        for d in domains:
            # Check if exists
            cur.execute("SELECT id FROM thematic_domains WHERE name = %s", (d["name"],))
            existing = cur.fetchone()
            
            if not existing:
                cur.execute(
                    "INSERT INTO thematic_domains (name, description) VALUES (%s, %s)",
                    (d["name"], d["description"])
                )
                print(f"Added domain: {d['name']}")
            else:
                print(f"Domain already exists: {d['name']}")
        
        conn.commit()
        cur.close()
        print("Seeding complete!")
        
    except Exception as e:
        print(f"Error seeding domains: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    seed_domains()
