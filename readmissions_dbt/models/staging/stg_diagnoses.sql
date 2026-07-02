{{ config(materialized='view') }}

-- =============================================================
-- stg_diagnoses.sql
-- Unpivots the 3 diagnosis columns (diag_1, diag_2, diag_3) from
-- stg_encounters into a long-format table with one row per
-- (encounter, diagnosis_position).
--
-- This makes it easy to:
--   - Join to ICD-9 category lookups (one join, one column)
--   - Count encounters by any diagnosis (regardless of position)
--   - Analyze primary vs secondary vs tertiary diagnosis patterns
-- =============================================================

with encounters as (

    select
        encounter_id,
        diagnosis_1_icd9,
        diagnosis_2_icd9,
        diagnosis_3_icd9
    from {{ ref('stg_encounters') }}

),

unpivoted as (

    -- Diagnosis position 1 (primary diagnosis)
    select
        encounter_id,
        1                    as diagnosis_position,
        diagnosis_1_icd9     as icd9_code
    from encounters
    where diagnosis_1_icd9 is not null

    union all

    -- Diagnosis position 2 (secondary)
    select
        encounter_id,
        2                    as diagnosis_position,
        diagnosis_2_icd9     as icd9_code
    from encounters
    where diagnosis_2_icd9 is not null

    union all

    -- Diagnosis position 3 (tertiary)
    select
        encounter_id,
        3                    as diagnosis_position,
        diagnosis_3_icd9     as icd9_code
    from encounters
    where diagnosis_3_icd9 is not null

),

enriched as (

    select
        encounter_id,
        diagnosis_position,
        icd9_code,
        case when diagnosis_position = 1 then 1 else 0 end as is_primary_diagnosis_flag
    from unpivoted

)

select * from enriched