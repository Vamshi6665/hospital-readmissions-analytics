{{ config(materialized='view') }}

-- =============================================================
-- int_age_numeric.sql
-- Converts the categorical age bracket ('[60-70)') into a
-- numeric midpoint (65) for downstream ML and analytics.
-- =============================================================

with encounters as (

    select
        encounter_id,
        age_bracket
    from {{ ref('stg_encounters') }}

),

converted as (

    select
        encounter_id,
        age_bracket,
        case age_bracket
            when '[0-10)'   then 5
            when '[10-20)'  then 15
            when '[20-30)'  then 25
            when '[30-40)'  then 35
            when '[40-50)'  then 45
            when '[50-60)'  then 55
            when '[60-70)'  then 65
            when '[70-80)'  then 75
            when '[80-90)'  then 85
            when '[90-100)' then 95
            else null
        end                                                        as age_midpoint,

        case
            when age_bracket in ('[0-10)', '[10-20)', '[20-30)') then 'Young'
            when age_bracket in ('[30-40)', '[40-50)', '[50-60)') then 'Middle'
            when age_bracket in ('[60-70)', '[70-80)') then 'Senior'
            when age_bracket in ('[80-90)', '[90-100)') then 'Elderly'
            else 'Unknown'
        end                                                        as age_group

    from encounters

)

select * from converted