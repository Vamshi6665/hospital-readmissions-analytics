{{ config(materialized='view') }}

-- =============================================================
-- stg_medications.sql
-- Unpivots the 24 medication columns from raw.diabetic_data into
-- a long-format table with one row per (encounter, medication).
--
-- Each row represents a drug the patient was assessed on during
-- the encounter, with:
--   - dose_status: 'No', 'Steady', 'Up', or 'Down'
--   - on_medication_flag: 1 if actually taking the drug (not 'No')
--   - dose_changed_flag: 1 if dose was adjusted ('Up' or 'Down')
--
-- Note: 5 medication columns contain hyphens (combination drugs)
-- and require double-quoting in SQL.
-- =============================================================

with source as (

    select * from {{ source('kaggle_raw', 'diabetic_data') }}

),

unpivoted as (

    select encounter_id::integer as encounter_id, 'metformin' as medication_name, metformin as dose_status from source
    union all select encounter_id::integer, 'repaglinide', repaglinide from source
    union all select encounter_id::integer, 'nateglinide', nateglinide from source
    union all select encounter_id::integer, 'chlorpropamide', chlorpropamide from source
    union all select encounter_id::integer, 'glimepiride', glimepiride from source
    union all select encounter_id::integer, 'acetohexamide', acetohexamide from source
    union all select encounter_id::integer, 'glipizide', glipizide from source
    union all select encounter_id::integer, 'glyburide', glyburide from source
    union all select encounter_id::integer, 'tolbutamide', tolbutamide from source
    union all select encounter_id::integer, 'pioglitazone', pioglitazone from source
    union all select encounter_id::integer, 'rosiglitazone', rosiglitazone from source
    union all select encounter_id::integer, 'acarbose', acarbose from source
    union all select encounter_id::integer, 'miglitol', miglitol from source
    union all select encounter_id::integer, 'troglitazone', troglitazone from source
    union all select encounter_id::integer, 'tolazamide', tolazamide from source
    union all select encounter_id::integer, 'examide', examide from source
    union all select encounter_id::integer, 'citoglipton', citoglipton from source
    union all select encounter_id::integer, 'insulin', insulin from source
    union all select encounter_id::integer, 'glyburide-metformin', "glyburide-metformin" from source
    union all select encounter_id::integer, 'glipizide-metformin', "glipizide-metformin" from source
    union all select encounter_id::integer, 'glimepiride-pioglitazone', "glimepiride-pioglitazone" from source
    union all select encounter_id::integer, 'metformin-rosiglitazone', "metformin-rosiglitazone" from source
    union all select encounter_id::integer, 'metformin-pioglitazone', "metformin-pioglitazone" from source

),

enriched as (

    select
        encounter_id,
        medication_name,
        dose_status,
        case when dose_status = 'No' then 0 else 1 end             as on_medication_flag,
        case when dose_status in ('Up', 'Down') then 1 else 0 end  as dose_changed_flag,
        case
            when dose_status = 'Up' then 1
            when dose_status = 'Down' then -1
            else 0
        end                                                        as dose_direction
    from unpivoted

)

select * from enriched