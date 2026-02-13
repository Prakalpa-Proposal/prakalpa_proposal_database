CREATE TABLE IF NOT EXISTS proposal_blueprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_label VARCHAR(100) NOT NULL,
    sections_config JSONB NOT NULL,
    ui_config JSONB,
    is_default BOOLEAN DEFAULT FALSE,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_single_default ON proposal_blueprints (is_default) WHERE (is_default = TRUE);

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='proposal_master' AND column_name='blueprint_id') THEN
        ALTER TABLE proposal_master ADD COLUMN blueprint_id UUID REFERENCES proposal_blueprints(id);
    END IF;
END $$;

INSERT INTO proposal_blueprints (version_label, is_default, is_published, sections_config, ui_config)
SELECT 'V1.0', TRUE, TRUE, '{
  "RAW_DATA_SKELETON": {"model": "gpt-3.5-turbo", "min_words": 100, "temperature": 0.2, "dependencies": [], "prompt_method": "build_raw_data_skeleton_prompt"},
  "COMMUNITY_PROFILE": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.3, "dependencies": ["RAW_DATA_SKELETON"], "prompt_method": "build_community_profile_prompt", "requires_raw_data": true},
  "NEEDS_ASSESSMENT": {"model": "gpt-3.5-turbo", "min_words": 300, "temperature": 0.5, "dependencies": ["COMMUNITY_PROFILE"], "prompt_method": "build_community_needs_prompt"},
  "BENEFITS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.7, "dependencies": ["NEEDS_ASSESSMENT", "SOLUTION_DESIGN"], "prompt_method": "build_benefits_prompt"},
  "BENEFICIARIES": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.6, "dependencies": ["COMMUNITY_PROFILE", "SOLUTION_DESIGN"], "prompt_method": "build_beneficiaries_prompt", "requires_raw_data": true},
  "ENVIRONMENTAL_FACTORS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.5, "dependencies": ["COMMUNITY_PROFILE"], "prompt_method": "build_environmental_factors_prompt"},
  "NGO_CREDENTIALS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.4, "dependencies": [], "prompt_method": "build_ngo_credentials_prompt"},
  "COMMITMENT_ASSURANCE": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.5, "dependencies": ["NGO_CREDENTIALS"], "prompt_method": "build_commitment_assurance_prompt"},
  "CAPABILITY_SKILLS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.6, "dependencies": ["NGO_CREDENTIALS"], "prompt_method": "build_capability_skills_prompt"},
  "COMMUNITY_ID_FOCUS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.5, "dependencies": ["COMMUNITY_PROFILE"], "prompt_method": "build_community_id_focus_prompt"},
  "COSTS_BUDGETS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.3, "dependencies": ["SOLUTION_DESIGN", "BENEFICIARIES"], "prompt_method": "build_costs_budgets_prompt", "requires_raw_data": true},
  "COMMERCIAL_TCS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.4, "dependencies": ["COSTS_BUDGETS"], "prompt_method": "build_commercial_terms_prompt"},
  "RELATIONSHIP_MANAGEMENT": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.6, "dependencies": ["STAKEHOLDERS_MANAGEMENT"], "prompt_method": "build_relationship_management_prompt"},
  "RISKS": {"model": "gpt-3.5-turbo", "min_words": 400, "temperature": 0.5, "dependencies": ["COMMUNITY_PROFILE", "SOLUTION_DESIGN"], "prompt_method": "build_risks_mitigation_prompt"},
  "IMPACT_ASSESSMENT": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.6, "dependencies": ["BENEFITS", "BENEFICIARIES", "SOLUTION_DESIGN"], "prompt_method": "build_impact_creation_prompt", "requires_raw_data": true},
  "SOLUTION_DESIGN": {"model": "gpt-3.5-turbo", "min_words": 1000, "temperature": 0.6, "dependencies": ["NEEDS_ASSESSMENT", "COMMUNITY_PROFILE"], "prompt_method": "build_solution_design_prompt", "requires_raw_data": true},
  "SHARED_RESPONSIBILITY": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.5, "dependencies": ["STAKEHOLDERS_MANAGEMENT"], "prompt_method": "build_shared_responsibility_prompt"},
  "STAKEHOLDERS_MANAGEMENT": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.6, "dependencies": ["COMMUNITY_PROFILE", "BENEFICIARIES"], "prompt_method": "build_stakeholders_management_prompt"},
  "SUSTAINABILITY": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.6, "dependencies": ["SOLUTION_DESIGN", "IMPACT_ASSESSMENT", "COSTS_BUDGETS"], "prompt_method": "build_sustainability_prompt"},
  "PROJECT_OPERATIONS": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.5, "dependencies": ["SOLUTION_DESIGN"], "prompt_method": "build_project_operations_prompt"},
  "PARTNERS_SMES": {"model": "gpt-3.5-turbo", "min_words": 500, "temperature": 0.5, "dependencies": ["SOLUTION_DESIGN"], "prompt_method": "build_partners_smes_prompt"}
}',
'[
  {"label": "B - Benefits", "code": "B", "fields": ["Benefits / Goals / Value Creation", "Beneficiaries"]},
  {"label": "E - Environment", "code": "E", "fields": ["Environmental Factors"]},
  {"label": "C - Community", "code": "C", "fields": ["Community Profile", "Community Needs & Problems", "NGO Credentials", "Commitment / Assurance", "Capability / Skills", "Community ID & Focus", "Costs & Budgets", "Commercial / T&Cs"]},
  {"label": "R - Risks", "code": "R", "fields": ["Relationship Management", "Risks / Mitigation"]},
  {"label": "I - Impact", "code": "I", "fields": ["Impact Creation & Assessment"]},
  {"label": "S - Solution", "code": "S", "fields": ["Solution / Design", "Shared Responsibility", "Stakeholders Management", "Sustainability"]},
  {"label": "P - Project", "code": "P", "fields": ["Project Operations", "Partners / SMEs"]}
]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM proposal_blueprints WHERE version_label = 'V1.0');

UPDATE proposal_master 
SET blueprint_id = (SELECT id FROM proposal_blueprints WHERE version_label = 'V1.0' LIMIT 1)
WHERE blueprint_id IS NULL;
