{{ config(materialized='view') }}

-- =============================================================
-- int_icd9_grouped.sql
-- Maps raw ICD-9 diagnosis codes into standard clinical categories
-- following the methodology from:
--
--   Strack B, DeShazo JP, Gennings C, Olmo JL, Ventura S,
--   Cios KJ, Clore JN. "Impact of HbA1c Measurement on Hospital
--   Readmission Rates: Analysis of 70,000 Clinical Database
--   Patient Records." BioMed Research International, 2014.
--
-- Category ranges:
--   Circulatory      : 390-459, 785
--   Respiratory      : 460-519, 786
--   Digestive        : 520-579, 787
--   Diabetes         : 250.xx (all subcategories)
--   Injury           : 800-999
--   Musculoskeletal  : 710-739
--   Genitourinary    : 580-629, 788
--   Neoplasms        : 140-239
--   Other            : V-codes, E-codes, unclassified
--
-- Note on ICD-9 codes: values are strings because some contain
-- letters (V-codes, E-codes) or decimal points. Integer portion
-- extracted via split_part() for numeric range comparisons.
-- =============================================================

with diagnoses as (

    select
        encounter_id,
        diagnosis_position,
        icd9_code,
        is_primary_diagnosis_flag
    from {{ ref('stg_diagnoses') }}

),

parsed as (

    select
        encounter_id,
        diagnosis_position,
        icd9_code,
        is_primary_diagnosis_flag,

        -- Detect V-codes (supplementary classification) and E-codes (external cause)
        case
            when icd9_code like 'V%' then 'V'
            when icd9_code like 'E%' then 'E'
            else 'N'
        end                                                        as code_type,

        -- Extract integer portion of the code (before decimal point)
        -- For V and E codes, this will be NULL after casting, which we handle below
        case
            when icd9_code like 'V%' or icd9_code like 'E%' then null
            else split_part(icd9_code, '.', 1)::numeric
        end                                                        as icd9_integer

    from diagnoses

),

categorized as (

    select
        encounter_id,
        diagnosis_position,
        icd9_code,
        is_primary_diagnosis_flag,
        code_type,
        icd9_integer,

        case
            -- Diabetes: 250.xx (all diabetes subcategories)
            when icd9_integer = 250 then 'Diabetes'

            -- Circulatory: 390-459 and 785
            when icd9_integer between 390 and 459 then 'Circulatory'
            when icd9_integer = 785 then 'Circulatory'

            -- Respiratory: 460-519 and 786
            when icd9_integer between 460 and 519 then 'Respiratory'
            when icd9_integer = 786 then 'Respiratory'

            -- Digestive: 520-579 and 787
            when icd9_integer between 520 and 579 then 'Digestive'
            when icd9_integer = 787 then 'Digestive'

            -- Injury: 800-999
            when icd9_integer between 800 and 999 then 'Injury'

            -- Musculoskeletal: 710-739
            when icd9_integer between 710 and 739 then 'Musculoskeletal'

            -- Genitourinary: 580-629 and 788
            when icd9_integer between 580 and 629 then 'Genitourinary'
            when icd9_integer = 788 then 'Genitourinary'

            -- Neoplasms: 140-239
            when icd9_integer between 140 and 239 then 'Neoplasms'

            -- Everything else: V-codes, E-codes, or unclassified numeric
            else 'Other'
        end                                                        as diagnosis_category

    from parsed

)

select * from categorized