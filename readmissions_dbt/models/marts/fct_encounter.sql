{{ config(materialized='table') }}

-- =============================================================
-- fct_encounter.sql
-- Grain: one row per hospital encounter.
--
-- This is the primary analytical fact table consumed by:
--   - Power BI dashboards (HRRP KPIs, drill-downs)
--   - Python ML notebooks (readmission prediction features)
--
-- Joins staging encounters with intermediate transformations
-- (ICD-9 primary diagnosis category, numeric age) and computes
-- derived flags for A1C testing, high-utilization patients, etc.
-- =============================================================

with encounters as (

    select * from {{ ref('stg_encounters') }}

),

primary_diagnosis as (

    -- Get the primary diagnosis (position 1) with its Strack category
    select
        encounter_id,
        icd9_code               as primary_diagnosis_icd9,
        diagnosis_category      as primary_diagnosis_category
    from {{ ref('int_icd9_grouped') }}
    where is_primary_diagnosis_flag = 1

),

age_numeric as (

    select
        encounter_id,
        age_midpoint,
        age_group
    from {{ ref('int_age_numeric') }}

),

joined as (

    select
        -- ============ IDENTIFIERS ============
        e.encounter_id,
        e.patient_id,

        -- ============ DEMOGRAPHICS ============
        e.race,
        e.gender,
        e.age_bracket,
        a.age_midpoint,
        a.age_group,
        e.weight_bracket,

        -- ============ ADMISSION CONTEXT ============
        e.admission_type_id,
        e.discharge_disposition_id,
        e.admission_source_id,
        e.length_of_stay_days,
        e.payer_code,
        e.medical_specialty,

        -- ============ UTILIZATION METRICS ============
        e.num_lab_procedures,
        e.num_procedures,
        e.num_medications,
        e.num_outpatient_prior_year,
        e.num_emergency_prior_year,
        e.num_inpatient_prior_year,
        e.num_diagnoses,

        -- Total prior-year encounters (derived utilization metric)
        (e.num_outpatient_prior_year + e.num_emergency_prior_year + e.num_inpatient_prior_year)
                                            as total_prior_year_encounters,

        -- ============ DIAGNOSIS ============
        pd.primary_diagnosis_icd9,
        coalesce(pd.primary_diagnosis_category, 'Other')
                                            as primary_diagnosis_category,

        -- ============ LAB RESULTS ============
        e.max_glucose_serum,
        e.a1c_result,

        -- A1C testing quality measure (CMS-style compliance flag)
        case when e.a1c_result is not null then 1 else 0 end
                                            as a1c_tested_flag,

        -- ============ MEDICATION BEHAVIOR ============
        e.medication_changed_flag,
        e.on_diabetes_medication_flag,

        -- ============ DERIVED CLINICAL FLAGS ============
        -- High utilization: >2 prior-year encounters
        case
            when (e.num_outpatient_prior_year + e.num_emergency_prior_year + e.num_inpatient_prior_year) > 2
            then 1 else 0
        end                                 as high_utilizer_flag,

        -- Long stay: length of stay > 7 days (typical hospital threshold)
        case when e.length_of_stay_days > 7 then 1 else 0 end
                                            as long_stay_flag,

        -- Complex case: 8+ diagnoses on this encounter
        case when e.num_diagnoses >= 8 then 1 else 0 end
                                            as complex_case_flag,

        -- ============ TARGET VARIABLES ============
        e.readmitted_30d_flag,
        e.readmitted_any_flag,
        e.readmitted_raw

    from encounters e
    left join primary_diagnosis pd on e.encounter_id = pd.encounter_id
    left join age_numeric a on e.encounter_id = a.encounter_id

)

select * from joined