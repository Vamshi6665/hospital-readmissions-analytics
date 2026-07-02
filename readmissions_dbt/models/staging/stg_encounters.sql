{{ config(materialized='view') }}

-- =============================================================
-- stg_encounters.sql
-- Cleaned hospital encounter records from the UCI Diabetes 130-US
-- Hospitals dataset. One row per hospital encounter.
--
-- Note on column quoting:
--   The raw table preserves original CSV column casing.
--   Mixed-case columns (A1Cresult, diabetesMed) require double
--   quotes to preserve case in Postgres.
-- =============================================================

with source as (

    select * from {{ source('kaggle_raw', 'diabetic_data') }}

),

renamed as (

    select
        -- Identifiers
        encounter_id::integer                              as encounter_id,
        patient_nbr::integer                               as patient_id,

        -- Demographics
        nullif(race, 'None')                               as race,
        gender,
        age                                                as age_bracket,
        nullif(weight, 'None')                             as weight_bracket,

        -- Admission context
        admission_type_id::integer                         as admission_type_id,
        discharge_disposition_id::integer                  as discharge_disposition_id,
        admission_source_id::integer                       as admission_source_id,
        time_in_hospital::integer                          as length_of_stay_days,

        -- Payer / provider
        nullif(payer_code, 'None')                         as payer_code,
        nullif(medical_specialty, 'None')                  as medical_specialty,

        -- Utilization metrics
        num_lab_procedures::integer                        as num_lab_procedures,
        num_procedures::integer                            as num_procedures,
        num_medications::integer                           as num_medications,
        number_outpatient::integer                         as num_outpatient_prior_year,
        number_emergency::integer                          as num_emergency_prior_year,
        number_inpatient::integer                          as num_inpatient_prior_year,
        number_diagnoses::integer                          as num_diagnoses,

        -- Primary diagnoses (ICD-9 codes as text; grouped in downstream models)
        diag_1                                             as diagnosis_1_icd9,
        diag_2                                             as diagnosis_2_icd9,
        diag_3                                             as diagnosis_3_icd9,

        -- Lab results (mixed-case column A1Cresult needs quoting)
        nullif(max_glu_serum, 'None')                      as max_glucose_serum,
        nullif("A1Cresult", 'None')                        as a1c_result,

        -- Medication behavior flags (mixed-case column diabetesMed needs quoting)
        case when "change" = 'Ch' then 1 else 0 end        as medication_changed_flag,
        case when "diabetesMed" = 'Yes' then 1 else 0 end  as on_diabetes_medication_flag,

        -- Target variables
        case when readmitted = '<30' then 1 else 0 end     as readmitted_30d_flag,
        case when readmitted in ('<30','>30') then 1 else 0 end as readmitted_any_flag,
        readmitted                                         as readmitted_raw

    from source

),

filtered as (

    -- Remove encounters with no valid encounter_id (defensive)
    select *
    from renamed
    where encounter_id is not null

)

select * from filtered