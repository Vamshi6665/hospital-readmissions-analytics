{{ config(materialized='table') }}

-- =============================================================
-- dim_patient.sql
-- Patient-level dimension. Grain: one row per unique patient.
--
-- Each patient may have 1 or more encounters. This dimension
-- rolls encounter-level data up to patient-level with:
--   - lifetime encounter count
--   - readmission behavior across all encounters
--   - most common demographics (mode)
--   - first/last encounter markers
--
-- Consumed by:
--   - Power BI: patient-level slicers and KPIs
--   - Python: patient-level features for ML
-- =============================================================

with encounters as (

    select * from {{ ref('fct_encounter') }}

),

patient_stats as (

    select
        patient_id,

        -- ============ VOLUME ============
        count(*)                                                   as total_encounters,
        sum(readmitted_30d_flag)                                   as total_readmissions_30d,
        sum(readmitted_any_flag)                                   as total_readmissions_any,

        -- ============ READMISSION RATES ============
        round(avg(readmitted_30d_flag::numeric) * 100, 2)          as readmission_rate_30d_pct,
        round(avg(readmitted_any_flag::numeric) * 100, 2)          as readmission_rate_any_pct,

        -- ============ UTILIZATION AVERAGES ============
        round(avg(length_of_stay_days::numeric), 2)                as avg_length_of_stay_days,
        round(avg(num_medications::numeric), 2)                    as avg_num_medications,
        round(avg(num_lab_procedures::numeric), 2)                 as avg_num_lab_procedures,
        max(num_inpatient_prior_year)                              as max_inpatient_prior_year,

        -- ============ QUALITY MEASURES ============
        round(avg(a1c_tested_flag::numeric) * 100, 2)              as a1c_testing_rate_pct,
        round(avg(medication_changed_flag::numeric) * 100, 2)      as med_change_rate_pct,

        -- ============ CLINICAL FLAGS (patient level) ============
        max(high_utilizer_flag)                                    as ever_high_utilizer_flag,
        max(long_stay_flag)                                        as ever_long_stay_flag,
        max(complex_case_flag)                                     as ever_complex_case_flag

    from encounters
    group by patient_id

),

patient_demographics as (

    -- Take the most recent encounter's demographics as the patient's canonical attributes
    -- (using distinct on to get one row per patient)
    select distinct on (patient_id)
        patient_id,
        race,
        gender,
        age_bracket,
        age_midpoint,
        age_group,
        weight_bracket
    from encounters
    order by patient_id, encounter_id desc

),

final as (

    select
        s.patient_id,

        -- Demographics
        d.race,
        d.gender,
        d.age_bracket,
        d.age_midpoint,
        d.age_group,
        d.weight_bracket,

        -- Volume
        s.total_encounters,
        s.total_readmissions_30d,
        s.total_readmissions_any,

        -- Rates
        s.readmission_rate_30d_pct,
        s.readmission_rate_any_pct,

        -- Utilization
        s.avg_length_of_stay_days,
        s.avg_num_medications,
        s.avg_num_lab_procedures,
        s.max_inpatient_prior_year,

        -- Quality
        s.a1c_testing_rate_pct,
        s.med_change_rate_pct,

        -- Clinical flags
        s.ever_high_utilizer_flag,
        s.ever_long_stay_flag,
        s.ever_complex_case_flag,

        -- Patient segmentation flag
        case
            when s.total_encounters = 1 then 'Single-encounter'
            when s.total_encounters between 2 and 5 then 'Repeat (2-5)'
            when s.total_encounters between 6 and 10 then 'Frequent (6-10)'
            else 'Very Frequent (10+)'
        end                                                        as patient_encounter_segment

    from patient_stats s
    left join patient_demographics d on s.patient_id = d.patient_id

)

select * from final