{{ config(materialized='table') }}

-- =============================================================
-- dim_diagnosis_category.sql
-- Reference dimension for the 9 Strack et al. 2014 diagnosis
-- categories. Provides human-readable descriptions, ICD-9 ranges,
-- and category-level encounter statistics.
--
-- Grain: one row per diagnosis category (9 rows total).
-- Consumed by Power BI slicers and report headers.
-- =============================================================

with categories as (

    select 'Circulatory'      as category_name,
           '390-459, 785'     as icd9_range,
           'Diseases of the circulatory system: heart disease, hypertension, vascular disorders' as clinical_description,
           1                  as display_order
    union all select 'Respiratory', '460-519, 786',
           'Diseases of the respiratory system: pneumonia, COPD, asthma, respiratory failure', 2
    union all select 'Digestive', '520-579, 787',
           'Diseases of the digestive system: gastritis, ulcers, liver disease, GI bleeding', 3
    union all select 'Diabetes', '250.xx',
           'Diabetes mellitus and its complications (all subcategories)', 4
    union all select 'Injury', '800-999',
           'Injuries and poisonings: fractures, wounds, complications of medical care', 5
    union all select 'Musculoskeletal', '710-739',
           'Diseases of the musculoskeletal system: arthritis, back disorders, joint disease', 6
    union all select 'Genitourinary', '580-629, 788',
           'Diseases of the genitourinary system: kidney disease, UTI, urinary tract disorders', 7
    union all select 'Neoplasms', '140-239',
           'Neoplasms (cancers): malignant, benign, and uncertain-behavior tumors', 8
    union all select 'Other', 'V-codes, E-codes, unclassified',
           'Supplementary classifications, external causes, and unclassified diagnoses', 9

),

with_stats as (

    select
        c.category_name,
        c.icd9_range,
        c.clinical_description,
        c.display_order,
        count(f.encounter_id)                                          as total_encounters,
        sum(f.readmitted_30d_flag)                                     as total_readmissions_30d,
        round(avg(f.readmitted_30d_flag::numeric) * 100, 2)            as readmission_rate_30d_pct,
        round(avg(f.length_of_stay_days::numeric), 2)                  as avg_length_of_stay_days
    from categories c
    left join {{ ref('fct_encounter') }} f
        on f.primary_diagnosis_category = c.category_name
    group by c.category_name, c.icd9_range, c.clinical_description, c.display_order

)

select * from with_stats order by display_order