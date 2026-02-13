-- Prakalpa Proposal Database Initial Schema
-- Consolidated Authoritative Version - 2026-02-06

-- ==========================================
-- 1. GEOGRAPHY & MASTER INFRASTRUCTURE
-- ==========================================

-- LGD Master (Authoritative Geography from data.gov.in)
CREATE TABLE IF NOT EXISTS lgd_master (
    id SERIAL PRIMARY KEY,
    village_code VARCHAR(50) UNIQUE NOT NULL,
    village_name TEXT,
    subdistrict_code TEXT,
    subdistrict_name TEXT,
    district_code TEXT,
    district_name TEXT,
    state_code TEXT,
    state_name TEXT,
    pincode TEXT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Regional Discovery: Village-Pincode Mapping
CREATE TABLE IF NOT EXISTS village_pincode_mapping (
    id SERIAL PRIMARY KEY,
    pincode TEXT NOT NULL,
    village_name TEXT NOT NULL,
    district_name TEXT NOT NULL,
    state_name TEXT NOT NULL,
    UNIQUE(pincode, village_name, district_name, state_name)
);

-- Sync Status for Background Jobs
CREATE TABLE IF NOT EXISTS sync_status (
    job_name TEXT PRIMARY KEY,
    last_offset INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 2. VILLAGE DATA & DEMOGRAPHICS
-- ==========================================

-- Existing Villages table (Application specific)
CREATE TABLE IF NOT EXISTS villages (
    id SERIAL PRIMARY KEY,
    lgd_code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    district_name VARCHAR(100),
    state_name VARCHAR(100),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Village Demographics (Populated via JJM Scraper)
CREATE TABLE IF NOT EXISTS village_demographics (
    id SERIAL PRIMARY KEY,
    village_id INTEGER REFERENCES villages(id),
    lgd_code VARCHAR(50) UNIQUE,
    total_population INTEGER,
    households INTEGER,
    sc_population INTEGER,
    st_population INTEGER,
    general_population INTEGER,
    source VARCHAR(100),
    status VARCHAR(50), -- SUCCESS, FAILED, PENDING
    fetched_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- District Demographics (NDAP 9307 - District Level Context)
CREATE TABLE IF NOT EXISTS district_demographics (
    id SERIAL PRIMARY KEY,
    state_name TEXT NOT NULL,
    district_name TEXT NOT NULL,
    year_code TEXT NOT NULL,
    total_population INTEGER,
    sc_population INTEGER,
    st_population INTEGER,
    general_population INTEGER,
    source_file TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(state_name, district_name, year_code)
);

-- Village Amenities Raw (NDAP 7121 - Infrastructure Gaps)
-- Detailed amenities for village-level research
CREATE TABLE IF NOT EXISTS village_amenities_raw (
    country TEXT,
    state TEXT,
    district TEXT,
    sub_district TEXT,
    ulb_rlb_village TEXT,
    year TEXT,
    name_of_the_subdistrict_head_quarter_of_village TEXT,
    name_of_the_district_head_quarter_of_village TEXT,
    name_of_the_nearest_statutory_town TEXT,
    nearest_government_or_private_pre_primary_school_facility TEXT,
    nearest_location_with_pre_primary_school_facility_if_not_a TEXT,
    distance_to_the_nearest_location_with_pre_primary_school_fac TEXT,
    nearest_government_or_private_primary_school_facility TEXT,
    nearest_location_with_primary_school_facility_if_not_availa TEXT,
    distance_to_the_nearest_location_with_primary_school_facilit TEXT,
    nearest_government_or_private_medical_school_facility TEXT,
    nearest_location_with_middle_school_facility_if_not_availab TEXT,
    distance_to_the_nearest_location_with_middle_school_facility TEXT,
    nearest_government_or_private_secondary_school_facility TEXT,
    nearest_location_with_secondary_school_facility_if_not_avai TEXT,
    distance_to_the_nearest_location_with_secondary_school_facil TEXT,
    nearest_government_or_private_senior_secondary_school_facili TEXT,
    nearest_location_with_senior_secondary_school_facility_if_n TEXT,
    distance_to_the_nearest_location_with_senior_secondary_schoo TEXT,
    nearest_government_or_private_arts_and_science_degree_colleg TEXT,
    nearest_location_with_arts_and_science_degree_college_facili TEXT,
    distance_to_the_nearest_location_with_arts_and_science_degre TEXT,
    nearest_government_or_private_engineering_college_facility TEXT,
    nearest_location_with_engineering_college_facility_if_not_a TEXT,
    distance_to_the_nearest_location_with_engineering_college_fa TEXT,
    nearest_government_or_private_medical_college_facility TEXT,
    nearest_location_with_medical_college_facility_if_not_avail TEXT,
    distance_to_the_nearest_location_with_medical_college_facili TEXT,
    nearest_governmnet_or_private_management_institute_facility TEXT,
    nearest_locationwith_management_institute_facility_if_not_a TEXT,
    distance_to_the_nearest_location_with_management_institute_f TEXT,
    nearest_government_or_private_polytechnic_college_facility TEXT,
    nearest_location_with_polytechnic_college_facility_if_not_a TEXT,
    distance_to_the_nearest_location_with_polytechnic_college_fa TEXT,
    nearest_government_or_private_vocational_training_school_or_ TEXT,
    nearest_location_with_vocational_training_school_or_iti_faci TEXT,
    distance_to_the_nearest_location_with_vocational_training_sc TEXT,
    nearest_government_or_private_non_formal_training_center_fac TEXT,
    nearest_location_with_non_formal_training_center_facility_i TEXT,
    distance_to_the_nearest_location_with_non_formal_training_ce TEXT,
    nearest_government_or_private_school_for_disabled_facility TEXT,
    nearest_location_with_school_for_disabled_facility_if_not_a TEXT,
    distance_to_the_nearest_location_with_school_for_disabled_fa TEXT,
    nearest_other_government_or_private_educational_facility TEXT,
    nearest_location_with_other_educational_facility_if_not_ava TEXT,
    distance_to_the_nearest_location_with_other_education_facili TEXT,
    distance_to_the_nearest_location_with_community_health_centr TEXT,
    distance_to_the_nearest_location_with_primary_health_centre_ TEXT,
    distance_to_the_nearest_location_with_primary_heallth_sub_ce TEXT,
    distance_to_the_nearest_location_with_maternity_and_child_we TEXT,
    distance_to_the_nearest_location_with_tuberculosis_tb_clinic TEXT,
    distance_to_nearest_location_with_allopathic_hospital_if_no TEXT,
    distance_to_the_nearest_location_with_alternative_medicine_h TEXT,
    distance_to_nearest_location_with_dispensary_if_not_availab TEXT,
    distance_to_the_nearest_location_with_veterinary_hospital_if TEXT,
    distance_to_the_nearest_location_with_mobile_health_clinic_i TEXT,
    distance_to_the_nearest_location_with_family_welfare_center_ TEXT,
    number_of_villages_with_filtered_tap_water TEXT,
    number_of_villages_with_filtered_tap_water_functioning_all_o TEXT,
    number_of_villages_with_filtered_tap_water_functioning_in_su TEXT,
    number_of_villages_with_unfiltered_tap_water TEXT,
    number_of_villages_with_unfiltered_tap_water_functioning_all TEXT,
    number_of_villages_with_unfiltered_tap_water_functioning_in_ TEXT,
    number_of_villages_with_covered_wells TEXT,
    number_of_villages_with_covered_wells_functioning_all_over_t TEXT,
    number_of_villages_with_covered_wells_functioning_in_summer_ TEXT,
    number_of_villages_with_uncovered_wells TEXT,
    number_of_villages_with_filtered_uncovered_wells_functioning TEXT,
    number_of_villages_with_uncovered_wells_functioning_in_summe TEXT,
    number_of_villages_with_hand_pumps TEXT,
    number_of_villages_with_filtered_hand_pumps_functioning_all_ TEXT,
    number_of_villages_with_filtered_hand_pumps_functioning_in_s TEXT,
    number_of_villages_with_tube_and_borehole_wells TEXT,
    number_of_villages_with_tube_and_borehole_wells_functioning_ TEXT,
    number_of_villages_with_tube_and_borehole_wells_functioning_2 TEXT,
    number_of_villages_with_spring TEXT,
    number_of_villages_with_spring_functioning_all_over_the_year TEXT,
    number_of_villages_with_spring_functioning_in_summer_months_ TEXT,
    number_of_villages_with_river_canals TEXT,
    number_of_villages_with_river_canals_functioning_all_over_th TEXT,
    number_of_villages_with_river_canals_functioning_in_summer_m TEXT,
    number_of_villages_with_tanks_ponds_or_lakes TEXT,
    number_of_villages_with_tanks_ponds_or_lakes_functioning_all TEXT,
    number_of_villages_with_tanks_ponds_or_lakes_functioning_in_ TEXT,
    number_of_villages_with_other_water_functionings TEXT,
    number_of_villages_with_other_water_functionings_all_over_th TEXT,
    number_of_villages_with_other_water_functionings_in_summer_m TEXT,
    number_of_villages_with_closed_drainage TEXT,
    number_of_villages_with_open_drainage TEXT,
    number_of_villages_with_no_drainage TEXT,
    number_of_villages_with_open_pucca_drainage_covered_with_til TEXT,
    number_of_villages_with_open_pucca_drainage_uncovered TEXT,
    number_of_villages_with_open_kuccha_drainage TEXT,
    discharge_of_drain_water_into_water_bodies_or_to_a_sewer_pla TEXT,
    area_covered_under_total_sanitation_campaign_tsc TEXT,
    number_of_villages_with_community_toilet_complex_including_b TEXT,
    number_of_villages_with_community_toilet_complex_excluding_b TEXT,
    number_of_villages_with_rural_production_centres_or_sanitary TEXT,
    number_of_villages_with_rural_production_mart_or_sanitary_ha TEXT,
    number_of_villages_with_community_waste_disposal_system_afte TEXT,
    number_of_villages_with_community_bio_gas_or_recycle_of_wast TEXT,
    number_of_villages_with_no_system_garbage_on_road_street TEXT,
    number_of_villages_with_post_office TEXT,
    distance_to_the_nearest_location_with_post_office_if_not_ava TEXT,
    number_of_villages_with_sub_post_office TEXT,
    distance_to_the_nearest_location_with_sub_post_office_if_not TEXT,
    number_of_villages_with_post_and_telegraph_office TEXT,
    distance_to_the_nearest_village_or_town_name_with_post_and_t TEXT,
    number_of_villages_with_village_pin_code TEXT,
    distance_to_the_nearest_location_with_village_pin_code_if_no TEXT,
    postal_index_number_pin_code_of_the_village TEXT,
    number_of_villages_with_telephone_landlines TEXT,
    distance_to_the_nearest_location_with_telephone_landlines_if TEXT,
    number_of_villages_with_public_call_office_mobile_pco TEXT,
    distance_to_the_nearest_location_with_public_call_office_mob TEXT,
    number_of_villages_with_mobile_phone_coverage TEXT,
    distance_to_the_nearest_location_with_mobile_phone_coverage_ TEXT,
    number_of_villages_with_internet_cafes_common_service_centre TEXT,
    distance_to_the_nearest_location_with_internet_cafes_common_ TEXT,
    number_of_villages_with_private_courier_facility TEXT,
    distance_to_the_nearest_location_with_private_courier_facili TEXT,
    number_of_villages_with_public_bus_service TEXT,
    distance_to_the_nearest_location_with_public_bus_service_if_ TEXT,
    number_of_villages_with_private_bus_service TEXT,
    distance_to_the_nearest_location_with_private_bus_service_if TEXT,
    number_of_villages_with_railway_stations TEXT,
    distance_to_the_nearest_village_or_town_name_with_railway_st TEXT,
    number_of_villages_with_auto_modified_autos TEXT,
    distance_to_the_nearest_location_with_auto_modified_autos_if TEXT,
    number_of_villages_with_taxies TEXT,
    distance_to_the_nearest_location_with_taxi_if_not_available_ TEXT,
    number_of_villages_with_vans TEXT,
    distance_to_the_nearest_location_with_vans_if_not_available_ TEXT,
    number_of_villages_with_tractors TEXT,
    distance_to_the_nearest_location_with_tractors_if_not_availa TEXT,
    number_of_villages_with_cycle_pulled_rickshaws_manual_driven TEXT,
    distance_to_the_nearest_location_with_cycle_pulled_rickshaws TEXT,
    number_of_villages_with_cycle_pulled_rickshaws_machine_drive TEXT,
    distance_to_the_nearest_location_with_cycle_pulled_rickshaws_2 TEXT,
    number_of_villages_with_carts_drivens_by_animals TEXT,
    distance_to_the_nearest_location_with_carts_drivens_by_anima TEXT,
    number_of_villages_with_sea_river_ferry_service TEXT,
    distance_to_the_nearest_location_with_sea_river_ferry_servic TEXT,
    number_of_villages_with_national_highway TEXT,
    distance_to_the_nearest_national_highway_if_not_available_wi TEXT,
    number_of_villages_with_state_highway TEXT,
    distance_to_the_nearest_state_highway_if_not_available_withi TEXT,
    number_of_villages_with_major_district_roads TEXT,
    distance_to_the_nearest_major_district_road_if_not_available TEXT,
    number_of_villages_with_other_district_roads TEXT,
    distance_to_the_nearest_other_district_road_if_not_available TEXT,
    number_of_villages_with_black_topped_pucca_roads TEXT,
    distance_to_the_nearest_black_topped_pucca_road_if_not_avail TEXT,
    number_of_villages_with_gravel_kuchha_roads TEXT,
    distance_to_the_nearest_gravel_kuchha_roads_if_not_available TEXT,
    number_of_villages_with_water_bounded_macadam_type_of_road TEXT,
    distance_to_the_nearest_water_bounded_macadam_if_not_availab TEXT,
    number_of_villages_with_all_weather_road TEXT,
    distance_to_the_nearest_all_weather_road_if_not_available_wi TEXT,
    number_of_villages_with_navigable_waterways_river_canals TEXT,
    distance_to_the_nearest_navigable_waterways_river_canal_if_n TEXT,
    number_of_villages_with_footpath TEXT,
    distance_to_the_nearest_foothpath_if_not_available_within_th TEXT,
    number_of_villages_with_atms TEXT,
    distance_to_the_nearest_atm_if_not_available_within_the_vill TEXT,
    number_of_villages_with_commercial_banks TEXT,
    distance_to_the_nearest_commercial_bank_if_not_available_wit TEXT,
    number_of_villages_with_cooperative_banks TEXT,
    distance_to_the_nearest_cooperative_bank_if_not_available_wi TEXT,
    number_of_villages_with_agricultural_credit_societies TEXT,
    distance_to_the_nearest_agricultural_credit_societies_if_not TEXT,
    number_of_villages_with_self_help_group_shg TEXT,
    distance_to_the_nearest_self_help_group_shg_if_not_available TEXT,
    number_of_villages_with_public_distribution_system_pds_shops TEXT,
    distance_to_the_nearest_public_distribution_system_pds_shop_ TEXT,
    number_of_villages_with_mandis_regular_market TEXT,
    distance_to_the_nearest_mandis_regular_market_if_not_availab TEXT,
    number_of_villages_with_weekly_haat TEXT,
    distance_to_the_nearest_weekly_haat_if_not_available_within_ TEXT,
    number_of_villages_with_agricultural_marketing_society TEXT,
    distance_to_the_nearest_agricultural_marketing_society_if_no TEXT,
    number_of_villages_with_nutritional_centres_integrated_child TEXT,
    distance_to_the_nearest_nutritional_centres_integrated_child TEXT,
    number_of_villages_with_nutritional_centres_anganwadi_centres TEXT,
    distance_to_nearest_nutritional_centres_anganwadi_centres_if TEXT,
    number_of_villages_with_other_nutritional_centres TEXT,
    distance_to_the_nearest_other_nutritional_centres_if_not_ava TEXT,
    number_of_villages_with_accredited_social_health_activist_as TEXT,
    distance_to_the_nearest_accredited_social_health_activist_as TEXT,
    number_of_villages_with_community_centre_with_or_without_tv TEXT,
    distance_to_nearest_community_centre_with_or_without_tv_if_n TEXT,
    number_of_villages_with_sports_field TEXT,
    distance_to_the_nearest_sports_field_if_not_available_within TEXT,
    number_of_villages_with_sports_club_recreation_centres TEXT,
    distance_to_the_nearest_sports_club_recreation_centre_if_not TEXT,
    number_of_villages_with_cinema_video_halls TEXT,
    distance_to_the_nearest_cinema_video_hall_if_not_available_w TEXT,
    number_of_villages_with_custom_public_library TEXT, -- Renamed to avoid reserved words
    distance_to_the_nearest_public_library_if_not_available_with TEXT,
    number_of_villages_with_public_reading_rooms TEXT,
    distance_to_the_nearest_public_reading_room_if_not_available TEXT,
    number_of_villages_with_daily_newspaper_supply TEXT,
    distance_to_the_nearest_daily_newspaper_supply_if_not_availa TEXT,
    number_of_villages_with_assembly_polling_station TEXT,
    distance_to_the_nearest_assembly_polling_station_if_not_avai TEXT,
    number_of_villages_with_birth_and_death_registration_office TEXT,
    distance_to_the_nearest_birth_and_death_registration_office_ TEXT,
    number_of_villages_with_power_supply_for_domestic_use TEXT,
    number_of_hours_of_power_supply_for_domestic_use_in_summer_f TEXT,
    number_of_hours_of_power_supply_for_domestic_use_from_winter TEXT,
    number_of_villages_with_power_supply_for_agricultural_use TEXT,
    number_of_hours_of_power_supply_for_agricultural_use_in_summ TEXT,
    number_of_hours_of_power_supply_for_agricultural_use_in_wint TEXT,
    number_of_villages_with_power_supply_for_commercial_use TEXT,
    number_of_hours_of_power_supply_for_commercial_use_in_summer TEXT,
    number_of_hours_of_power_supply_for_commercial_use_in_winter TEXT,
    number_of_villages_with_power_supply_for_all_users TEXT,
    number_of_hours_of_power_supply_for_all_users_in_summer_from TEXT,
    first_agricultural_commodities_the_village TEXT,
    first_manufactural_commodities_in_the_village TEXT,
    first_handicrafts_commodities_in_the_village TEXT,
    second_agricultural_commodities_the_village TEXT,
    second_manufactural_commodities_in_the_village TEXT,
    second_handicrafts_commodities_in_the_village TEXT,
    third_agricultural_commodities_the_village TEXT,
    third_manufactural_commodities_in_the_village TEXT,
    third_handicrafts_commodities_in_the_village TEXT,
    distance_between_village_and_sub_district_head_quarter TEXT,
    distance_between_the_village_and_district_head_quarter TEXT,
    distance_between_village_and_nearest_statutory_town TEXT,
    total_geographical_area_covered_by_village TEXT,
    number_of_village_households TEXT,
    rural_population TEXT,
    male_rural_population TEXT,
    female_rural_population TEXT,
    scheduled_castes_rural_population TEXT,
    scheduled_castes_male_rural_population TEXT,
    scheduled_castes_female_rural_population TEXT,
    scheduled_tribes_rural_population TEXT,
    scheduled_tribes_male_rural_population TEXT,
    scheduled_tribes_female_rural_population TEXT,
    number_of_villages_with_government_pre_primary_schools TEXT,
    number_of_government_pre_primary_schools TEXT,
    number_of_villages_with_private_pre_primary_schools TEXT,
    number_of_private_pre_primary_schools TEXT,
    number_of_villages_with_government_primary_schools TEXT,
    number_of_government_primary_schools TEXT,
    number_of_villages_with_private_primary_schools TEXT,
    number_of_private_primary_schools TEXT,
    number_of_villages_with_government_middle_schools TEXT,
    number_of_government_middle_schools TEXT,
    number_of_villages_with_private_middle_schools TEXT,
    number_of_private_middle_schools TEXT,
    number_of_villages_with_government_secondary_schools TEXT,
    number_of_government_secondary_schools TEXT,
    number_of_villages_with_private_secondary_schools TEXT,
    number_of_private_secondary_schools TEXT,
    number_of_villages_with_government_senior_secondary_schools TEXT,
    number_of_government_senior_secondary_schools TEXT,
    number_of_villages_with_private_senior_secondary_schools TEXT,
    number_of_private_senior_secondary_schools TEXT,
    number_of_villages_with_government_arts_and_science_degree_c TEXT,
    number_of_government_arts_and_science_degree_colleges TEXT,
    number_of_villages_with_private_arts_and_science_degree_coll TEXT,
    number_of_private_arts_and_science_degree_colleges TEXT,
    number_of_villages_with_government_engineering_colleges TEXT,
    number_of_government_engineering_colleges TEXT,
    number_of_villages_with_private_engineering_colleges TEXT,
    number_of_private_engineering_colleges TEXT,
    number_of_villages_with_government_medical_colleges TEXT,
    number_of_government_medical_colleges TEXT,
    number_of_villages_with_private_medical_college TEXT,
    number_of_private_medical_colleges TEXT,
    number_of_villages_with_government_management_institutes TEXT,
    number_of_government_management_institutes TEXT,
    number_of_villages_with_private_management_institutes TEXT,
    number_of_private_management_institutes TEXT,
    number_of_villages_with_government_polytechnic_colleges TEXT,
    number_of_government_polytechnic_colleges TEXT,
    number_of_villages_with_private_polytechnic_colleges TEXT,
    number_of_private_polytechnic_colleges TEXT,
    villages_with_government_vocational_training_schools_or_indu TEXT,
    number_of_government_vocational_training_school_or_industria TEXT,
    number_of_villages_with_private_vocational_training_school_o TEXT,
    number_of_private_vocational_training_school_or_industrial_t TEXT,
    number_of_villages_with_government_non_formal_training_cente TEXT,
    number_of_government_non_formal_training_centres TEXT,
    number_of_villages_with_private_non_formal_training_centers TEXT,
    number_of_private_non_formal_training_centres TEXT,
    number_of_villages_with_government_schools_for_disabled TEXT,
    number_of_government_schools_for_disabled TEXT,
    number_of_villages_with_private_schools_for_disabled TEXT,
    number_of_private_schools_for_disabled TEXT,
    number_of_villages_with_other_government_educational_facilit TEXT,
    number_of_government_other_educational_facilities TEXT,
    number_of_villages_with_other_private_educational_facilities TEXT,
    number_of_other_private_educational_facilities TEXT,
    number_of_community_health_centers TEXT,
    number_of_doctors_in_community_health_centres TEXT,
    number_of_doctors_available_in_community_health_centres TEXT,
    number_of_para_medical_staff_in_community_health_centres TEXT,
    number_of_para_medical_staff_available_in_community_health_c TEXT,
    number_of_primary_health_centers TEXT,
    number_of_doctors_in_primary_health_care_centres TEXT,
    number_of_doctors_available_in_primary_health_care_centres TEXT,
    number_of_para_medical_staff_in_primary_health_care_centres TEXT,
    number_of_para_medical_staff_available_in_primary_health_car TEXT,
    number_of_primary_health_sub_centers TEXT,
    number_of_doctors_in_primary_health_sub_centers TEXT,
    number_of_doctors_available_in_primary_health_sub_centers TEXT,
    number_of_para_medical_staff_in_primary_heallth_sub_centre TEXT,
    number_of_para_medical_staff_available_in_primary_heallth_su TEXT,
    number_of_maternity_and_child_welfare_centres TEXT,
    number_of_doctors_in_maternity_and_child_welfare_centres TEXT,
    number_of_doctors_available_in_maternity_and_child_welfare_c TEXT,
    number_of_para_medical_staff_in_maternity_and_child_welfare_ TEXT,
    number_of_para_medical_staff_available_in_maternity_and_chil TEXT,
    number_of_tuberculosis_tb_clinics TEXT,
    number_of_doctors_in_tb_clinics TEXT,
    number_of_doctors_available_in_tb_clinics TEXT,
    number_of_para_medical_staff_in_tuberculosis_tb_clinics TEXT,
    number_of_para_medical_staff_available_in_tuberculosis_tb_cl TEXT,
    number_of_allopathic_hospitals TEXT,
    number_of_doctors_in_allopathic_hospitals TEXT,
    number_of_doctors_available_in_allopathic_hospitals TEXT,
    number_of_para_medical_staff_in_allopathic_hospitals TEXT,
    number_of_para_medical_staff_available_in_allopathic_hospita TEXT,
    number_of_alternative_medicine_hospitals TEXT,
    number_of_doctors_in_alternative_medicine_hospitals TEXT,
    number_of_doctors_available_in_alternative_medicine_hospital TEXT,
    number_of_para_medical_staff_in_alternative_medicine_hospita TEXT,
    number_of_para_medical_staff_available_in_alternative_medici TEXT,
    number_of_dispensaries TEXT,
    number_of_doctors_at_dispensaries TEXT,
    number_of_doctors_available_at_dispensaries TEXT,
    number_of_para_medical_staff_at_dispensaries TEXT,
    number_of_para_medical_staff_available_at_dispensaries TEXT,
    number_of_veterinary_hospitals TEXT,
    number_of_doctors_at_veterinary_hospitals TEXT,
    number_of_doctors_available_at_veterinary_hospitals TEXT,
    number_of_para_medical_staff_at_veternity_hospitals TEXT,
    number_of_para_medical_staff_available_at_veternity_hospital TEXT,
    number_of_mobile_health_clinics TEXT,
    number_of_doctors_at_mobile_health_clinics TEXT,
    number_of_doctors_available_at_mobile_health_clinics TEXT,
    number_of_para_medical_staff_at_mobile_health_clinics TEXT,
    number_of_para_medical_staff_available_at_mobile_health_clin TEXT,
    number_of_family_welfare_centers TEXT,
    number_of_doctors_in_family_welfare_centers TEXT,
    number_of_doctors_available_in_family_welfare_centers TEXT,
    number_of_para_medical_staff_in_family_welfare_centers TEXT,
    number_of_para_medical_staff_available_in_family_welfare_cen TEXT,
    number_of_non_government_medical_facilities_having_out_patie TEXT,
    number_of_non_government_medical_facilities_having_in_patien TEXT,
    number_of_non_government_charitable_medical_facilities TEXT,
    number_of_non_government_medical_practitioners_with_mbbs_deg TEXT,
    number_of_non_government_medical_practitioners_with_other_de TEXT,
    number_of_non_government_medical_practitioners_with_no_degre TEXT,
    number_of_non_government_traditional_and_faith_healers TEXT,
    number_of_non_government_medicine_or_medical_shops TEXT,
    number_of_other_non_government_medical_facilities TEXT,
    number_of_hours_of_power_supply_for_all_users_in_winter_from TEXT,
    forest_land_area_uom_ha_hectare TEXT,
    land_area_under_non_agricultural_uses_uom_ha_hectare TEXT,
    barren_and_un_cultivable_land_area_in_hectare_uom_ha_hectare TEXT,
    permanent_pastures_and_other_grazing_land_area_uom_ha_hectar TEXT,
    land_area_under_miscellaneous_tree_crops_etc_uom_ha_hectare TEXT,
    culturable_waste_land_area_uom_ha_hectare TEXT,
    fallows_land_other_than_current_fallows_area_uom_ha_hectare TEXT,
    current_fallows_land_area_uom_ha_hectare TEXT,
    net_land_area_sown_uom_ha_hectare TEXT,
    total_unirrigated_land_area_uom_ha_hectare TEXT,
    land_area_irrigated_by_sources_uom_ha_hectare TEXT,
    total_land_area_irrigated_by_canals_uom_ha_hectare TEXT,
    total_land_area_covered_by_wells_or_tube_wells_uom_ha_hectar TEXT,
    total_land_area_irrigated_by_tanks_or_lakes_uom_ha_hectare TEXT,
    total_land_area_irrigated_by_waterfalls_uom_ha_hectare TEXT,
    total_land_area_irrigated_by_other_water_sources_specify_uom TEXT
);

-- ==========================================
-- 3. APPLICATION DOMAIN & PROPOSALS
-- ==========================================

-- Thematic Domains (Primary & Secondary NGO Domains)
CREATE TABLE IF NOT EXISTS thematic_domains (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Organizations (NGOs)
CREATE TABLE IF NOT EXISTS organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(500) NOT NULL,
    url VARCHAR(500),
    email VARCHAR(150),
    phone VARCHAR(20),
    poc_name VARCHAR(100),
    address VARCHAR(500),
    state VARCHAR(100),
    district VARCHAR(100),
    city VARCHAR(100),
    pincode VARCHAR(20),
    ngo_darpan_id VARCHAR(100) UNIQUE,
    pan_number VARCHAR(20),
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, ACTIVE, SUSPENDED
    active BOOLEAN DEFAULT FALSE,
    max_proposals_per_month INTEGER DEFAULT 1000,
    token_limit INTEGER DEFAULT 10000000,
    spent_tokens INTEGER DEFAULT 0,
    logo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255)
);

-- Junction table for Organization domains
CREATE TABLE IF NOT EXISTS organization_domains (
    organization_id INTEGER REFERENCES organizations(id),
    domain_id INTEGER REFERENCES thematic_domains(id),
    PRIMARY KEY (organization_id, domain_id)
);

-- Users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    userid VARCHAR(20) UNIQUE,
    password VARCHAR(255), -- Aligned with models.py
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(50) DEFAULT 'USER',
    is_org_admin BOOLEAN DEFAULT FALSE,
    org_id INTEGER REFERENCES organizations(id),
    active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255)
);

-- NGO Registration Workflow Tables
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

-- Proposal Blueprints (Versioned Logic)
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

-- Proposal Master (Consolidated Header)
CREATE TABLE IF NOT EXISTS proposal_master (
    proposal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id UUID REFERENCES proposal_blueprints(id),
    ngo_id INTEGER REFERENCES organizations(id) NOT NULL,
    ngo_name VARCHAR(255) NOT NULL,
    domain VARCHAR(50) NOT NULL,
    sub_domain VARCHAR(100),
    location_village VARCHAR(255),
    location_district VARCHAR(255),
    location_state VARCHAR(255),
    location_lgd_code BIGINT,
    title VARCHAR(500),
    document_url TEXT,
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255),
    tags JSONB DEFAULT '[]'
);

-- Proposal Targets (Regional Coverage)
CREATE TABLE IF NOT EXISTS proposal_targets (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER REFERENCES proposal_master(id) ON DELETE CASCADE,
    state_name TEXT NOT NULL,
    district_name TEXT NOT NULL,
    block_name TEXT,
    village_name TEXT,
    lgd_code TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AI Response Metadata (For refining prompts)
CREATE TABLE IF NOT EXISTS ai_response_metadata (
    id BIGSERIAL PRIMARY KEY,
    proposal_id UUID REFERENCES proposal_master(proposal_id) NOT NULL,
    section_code VARCHAR(100) NOT NULL,
    version INTEGER DEFAULT 1,
    content TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    openai_response_id VARCHAR(255),
    openai_model VARCHAR(100),
    created_at_openai BIGINT,
    status VARCHAR(50),
    completed_at_openai BIGINT,
    error_message TEXT,
    input_tokens INTEGER,
    output_tokens INTEGER,
    total_tokens INTEGER,
    previous_response_id VARCHAR(255),
    temperature NUMERIC(3, 2),
    top_p NUMERIC(3, 2),
    reasoning_summary TEXT,
    source VARCHAR(50) DEFAULT 'AI_GENERATED',
    generation_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 4. SCHOOLS UDISE DATA & ENRICHMENT
-- ==========================================

-- UDISE+ Comprehensive School Data
CREATE TABLE IF NOT EXISTS schools_udise_data (
    id SERIAL PRIMARY KEY,
    udise_code VARCHAR(20) NOT NULL,
    school_id INTEGER, -- UDISE internal school ID
    year_id INTEGER NOT NULL, -- 11=2024-25, 12=2025-26
    
    -- Scraping Metadata
    last_scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scrape_status VARCHAR(20) DEFAULT 'success', -- success, failed, partial
    retry_count INTEGER DEFAULT 0,
    error_message TEXT,
    
    -- Store complete API responses as JSONB for flexibility
    basic_info JSONB, -- /school/by-year
    report_card JSONB, -- /school/report-card
    facility_data JSONB, -- /school/facility
    profile_data JSONB, -- /school/profile
    enrollment_social JSONB, -- /getSocialData?flag=1 (caste)
    enrollment_religion JSONB, -- /getSocialData?flag=2 (religion, BPL, CWSN)
    enrollment_mainstreamed JSONB, -- /getSocialData?flag=3
    enrollment_ews JSONB, -- /getSocialData?flag=4
    enrollment_rte JSONB, -- /getSocialData?flag=5
    
    -- Extracted Summary Fields (for easy querying)
    total_students INTEGER,
    total_boys INTEGER,
    total_girls INTEGER,
    total_teachers INTEGER,
    has_internet BOOLEAN,
    has_library BOOLEAN,
    has_playground BOOLEAN,
    has_electricity BOOLEAN,
    
    UNIQUE(udise_code, year_id)
);

CREATE INDEX idx_schools_udise_udise_code ON schools_udise_data(udise_code);
CREATE INDEX idx_schools_udise_year_id ON schools_udise_data(year_id);
CREATE INDEX idx_schools_udise_scrape_status ON schools_udise_data(scrape_status);

-- View: Student Population (Most Frequently Used)
CREATE OR REPLACE VIEW school_student_population_view AS
SELECT 
    s.udise_code,
    s.name AS school_name,
    st.name AS state,
    d.name AS district,
    b.name AS block,
    c.name AS cluster,
    u.total_students,
    u.total_boys,
    u.total_girls,
    (u.enrollment_social->>'students_sc')::INTEGER as students_sc,
    (u.enrollment_social->>'students_st')::INTEGER as students_st,
    (u.enrollment_social->>'students_obc')::INTEGER as students_obc,
    (u.enrollment_religion->>'students_bpl')::INTEGER as students_bpl,
    (u.enrollment_religion->>'students_cwsn')::INTEGER as students_cwsn,
    u.year_id,
    u.last_scraped_at
FROM schools s
LEFT JOIN clusters c ON s.cluster_id = c.id
LEFT JOIN blocks b ON c.block_id = b.id
LEFT JOIN districts d ON b.district_id = d.id
LEFT JOIN states st ON d.state_id = st.id
LEFT JOIN LATERAL (
    SELECT * FROM schools_udise_data 
    WHERE udise_code = s.udise_code 
    ORDER BY year_id DESC 
    LIMIT 1
) u ON true;

-- View: Infrastructure Details
CREATE OR REPLACE VIEW school_infra_view AS
SELECT 
    s.udise_code,
    s.name AS school_name,
    st.name AS state,
    d.name AS district,
    (u.facility_data->>'clsrmsInst')::INTEGER as total_classrooms,
    (u.facility_data->>'clsrmsGd')::INTEGER as classrooms_good,
    (u.facility_data->>'clsrmsMaj')::INTEGER as classrooms_major_repair,
    u.has_library,
    u.has_playground,
    u.has_electricity,
    (u.facility_data->>'toiletbFun')::INTEGER as toilets_boys_functional,
    (u.facility_data->>'toiletgFun')::INTEGER as toilets_girls_functional,
    (u.facility_data->>'drinkWaterYn')::INTEGER as has_drinking_water
FROM schools s
LEFT JOIN clusters c ON s.cluster_id = c.id
LEFT JOIN blocks b ON c.block_id = b.id
LEFT JOIN districts d ON b.district_id = d.id
LEFT JOIN states st ON d.state_id = st.id
LEFT JOIN LATERAL (
    SELECT * FROM schools_udise_data 
    WHERE udise_code = s.udise_code 
    ORDER BY year_id DESC 
    LIMIT 1
) u ON true;

-- View: Digital Facilities
CREATE OR REPLACE VIEW school_digital_facilities_view AS
SELECT 
    s.udise_code,
    s.name AS school_name,
    st.name AS state,
    d.name AS district,
    u.has_internet,
    (u.facility_data->>'laptopTot')::INTEGER as laptops_total,
    (u.facility_data->>'tabletsTot')::INTEGER as tablets_total,
    (u.facility_data->>'projectorTot')::INTEGER as projectors_total,
    (u.facility_data->>'printerTot')::INTEGER as printers_total,
    (u.facility_data->>'ictLabYn')::INTEGER as has_ict_lab
FROM schools s
LEFT JOIN clusters c ON s.cluster_id = c.id
LEFT JOIN blocks b ON c.block_id = b.id
LEFT JOIN districts d ON b.district_id = d.id
LEFT JOIN states st ON d.state_id = st.id
LEFT JOIN LATERAL (
    SELECT * FROM schools_udise_data 
    WHERE udise_code = s.udise_code 
    ORDER BY year_id DESC 
    LIMIT 1
) u ON true;

-- View: Teacher Information
CREATE OR REPLACE VIEW school_teacher_view AS
SELECT 
    s.udise_code,
    s.name AS school_name,
    st.name AS state,
    d.name AS district,
    u.total_teachers,
    (u.report_card->>'totMale')::INTEGER as teachers_male,
    (u.report_card->>'totFemale')::INTEGER as teachers_female,
    (u.report_card->>'tchReg')::INTEGER as teachers_regular,
    (u.report_card->>'totTchPgraduateAbove')::INTEGER as teachers_postgraduate
FROM schools s
LEFT JOIN clusters c ON s.cluster_id = c.id
LEFT JOIN blocks b ON c.block_id = b.id
LEFT JOIN districts d ON b.district_id = d.id
LEFT JOIN states st ON d.state_id = st.id
LEFT JOIN LATERAL (
    SELECT * FROM schools_udise_data 
    WHERE udise_code = s.udise_code 
    ORDER BY year_id DESC 
    LIMIT 1
) u ON true;

-- ==========================================
-- 5. SEED DATA & TRIGGERS
-- ==========================================

-- Initial Thematic Domains
INSERT INTO thematic_domains (name, description) VALUES
    ('WASH / JJM', 'Water, Sanitation and Hygiene / Jal Jeevan Mission'),
    ('Education', 'Primary and Secondary Education, Literacy'),
    ('Healthcare', 'Public Health, Maternal Care, Nutrition'),
    ('Livelihoods', 'Skill Development, Agriculture, SHGs'),
    ('Environment', 'Conservation, Climate Action, Waste Management'),
    ('Women Empowerment', 'Gender Equality, Financial Independence')
ON CONFLICT (name) DO NOTHING;

-- Default Organization
INSERT INTO organizations (id, name, status, active) 
VALUES (1, 'Tech4SocialGood', 'ACTIVE', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Test NGO for Proposal Generation (Matching ID 1 details for template fields)
INSERT INTO organizations (
    id, name, url, email, phone, poc_name, address, state, district, city, pincode, 
    ngo_darpan_id, status, active
) 
VALUES (
    2, 'Prakalpa Test NGO for Proposal Generation', 'https://www.prakalpasooujanya.g', 
    'contact@prakalpasoujanya.org', '+91 9845024536', 'Vijay Paul', 'Indiranagar', 
    'Karnataka', 'Bangalore Urban', 'Bangalore', '560038', 
    'KA/2026/9999999', 'ACTIVE', TRUE
)
ON CONFLICT (id) DO NOTHING;

-- Synchronize the serial sequence
SELECT setval('organizations_id_seq', (SELECT MAX(id) FROM organizations));

-- Default Admin User (Password: admin123 - for dev only)
INSERT INTO users (org_id, email, password, first_name, last_name, role, active)
VALUES (1, 'admin@tech4socialgood.org', 'pbkdf2:sha256:600000$admin_hash_placeholder', 'Admin', 'User', 'ADMIN', TRUE)
ON CONFLICT DO NOTHING;

-- Update Trigger for proposal_master
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_proposal_master_updated_at
    BEFORE UPDATE ON proposal_master
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Seed V1.0 Blueprint (Mirror of refined config.py)
INSERT INTO proposal_blueprints (version_label, is_default, is_published, sections_config, ui_config)
VALUES ('V1.0', TRUE, TRUE, '{
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
]'::jsonb);
