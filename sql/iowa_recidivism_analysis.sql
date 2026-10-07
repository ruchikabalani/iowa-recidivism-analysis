/* ============================================================
   IOWA RECIDIVISM ANALYSIS
   SQL Data Preparation, Validation, and Exploratory Analysis
   ============================================================ */


/* ============================================================
   SECTION 1: DATABASE SETUP
   Create a separate schema for the original source data
   ============================================================ */

-- Step 1: Create the raw data schema
CREATE SCHEMA raw;


/* ============================================================
   SECTION 2: RAW DATA TABLE
   Create a table matching the structure of the source CSV
   ============================================================ */

-- Step 2: Create the raw Iowa recidivism table
CREATE TABLE raw.iowa_recidivism (
    record_id TEXT,
    offender_cd TEXT,
    birth_date DATE,
    age INTEGER,
    race TEXT,
    sex TEXT,
    region_exit TEXT,
    exit_sup TEXT,
    cohort_fiscal_year INTEGER,
    report_fiscal_year INTEGER,
    report_fiscal_year_name TEXT,
    exit_sup_start_date DATE,
    exit_sup_end_date DATE,
    months_supervised NUMERIC,
    exit_sup_reason TEXT,
    charge_id TEXT,
    exit_class TEXT,
    exit_type TEXT,
    exit_subtype TEXT,
    is_recid BOOLEAN,
    new_tech TEXT,
    days_to_recid INTEGER,
    survival_time_months NUMERIC,
    recid_convicting_crime_cd TEXT,
    recid_convicting_crime_cd_class TEXT,
    recid_convicting_crime_type TEXT,
    recid_convicting_crime_subtype TEXT,
    submitted_date DATE,
    total_violence_score NUMERIC,
    violence_risk TEXT,
    total_victimization_score NUMERIC,
    victimization_risk TEXT,
    ranking_number NUMERIC,
    risk_ranking TEXT,
    regcd_exit TEXT,
    work_unit_region_nm TEXT,
    work_unit_nm TEXT
);


/* ============================================================
   SECTION 3: INITIAL DATA VALIDATION
   Validate the imported dataset before beginning analysis
   ============================================================ */

-- Step 3: Verify the total number of imported records
SELECT COUNT(*)
FROM raw.iowa_recidivism;


-- Step 4: Examine the distribution of recidivism outcomes
SELECT
    is_recid,
    COUNT(*) AS record_count
FROM raw.iowa_recidivism
GROUP BY is_recid
ORDER BY is_recid;


-- Step 5: Calculate the overall recidivism rate
-- Step 5: Calculate the overall recidivism rate safely
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE is_recid = TRUE) AS recidivism_records,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE is_recid = TRUE)
        / NULLIF(COUNT(*), 0),
        2
    ) AS recidivism_rate_pct
FROM raw.iowa_recidivism;


/* ============================================================
   SECTION 4: DATA QUALITY CHECKS
   Investigate missing values, identifiers, and consistency
   ============================================================ */

-- Step 6: Validate the relationship between recidivism
-- and availability of days-to-recidivism data
SELECT
    is_recid,
    COUNT(*) AS total_records,
    COUNT(days_to_recid) AS records_with_days,
    COUNT(*) - COUNT(days_to_recid) AS records_missing_days
FROM raw.iowa_recidivism
GROUP BY is_recid
ORDER BY is_recid;


-- Step 7: Check whether record_id can serve as a unique identifier
SELECT
    record_id,
    COUNT(*) AS record_count
FROM raw.iowa_recidivism
GROUP BY record_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- Step 8: Check completeness and uniqueness of offender_cd
SELECT
    COUNT(*) AS total_records,
    COUNT(offender_cd) AS non_null_offender_cd,
    COUNT(DISTINCT offender_cd) AS unique_offenders
FROM raw.iowa_recidivism;


-- Step 9: Identify repeated offender codes, if available
SELECT
    offender_cd,
    COUNT(*) AS record_count
FROM raw.iowa_recidivism
WHERE offender_cd IS NOT NULL
GROUP BY offender_cd
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 10;


-- Step 10: Profile missing values in key analytical fields
SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (WHERE age IS NULL) AS missing_age,
    COUNT(*) FILTER (WHERE race IS NULL) AS missing_race,
    COUNT(*) FILTER (WHERE sex IS NULL) AS missing_sex,
    COUNT(*) FILTER (WHERE region_exit IS NULL) AS missing_region,

    COUNT(*) FILTER (WHERE months_supervised IS NULL)
        AS missing_months_supervised,

    COUNT(*) FILTER (WHERE exit_sup_reason IS NULL)
        AS missing_exit_reason,

    COUNT(*) FILTER (WHERE is_recid IS NULL)
        AS missing_recid,

    COUNT(*) FILTER (WHERE violence_risk IS NULL)
        AS missing_violence_risk,

    COUNT(*) FILTER (WHERE risk_ranking IS NULL)
        AS missing_risk_ranking

FROM raw.iowa_recidivism;


/* ============================================================
   SECTION 5: CATEGORICAL DATA PROFILING
   Review category values for consistency and unusual values
   ============================================================ */

-- Step 11: Review race categories
SELECT
    race,
    COUNT(*) AS records
FROM raw.iowa_recidivism
GROUP BY race
ORDER BY records DESC;


-- Step 12: Review sex categories
SELECT
    sex,
    COUNT(*) AS records
FROM raw.iowa_recidivism
GROUP BY sex
ORDER BY records DESC;


-- Step 13: Review risk-ranking categories
SELECT
    risk_ranking,
    COUNT(*) AS records
FROM raw.iowa_recidivism
GROUP BY risk_ranking
ORDER BY records DESC;


/* ============================================================
   SECTION 6: NUMERIC DATA PROFILING & OUTLIER REVIEW
   Check ranges and investigate potentially unusual values
   ============================================================ */

-- Step 14: Review ranges and averages of key numeric fields
SELECT
    MIN(age) AS min_age,
    MAX(age) AS max_age,
    ROUND(AVG(age), 2) AS avg_age,

    MIN(months_supervised) AS min_months_supervised,
    MAX(months_supervised) AS max_months_supervised,
    ROUND(AVG(months_supervised), 2) AS avg_months_supervised,

    MIN(days_to_recid) AS min_days_to_recid,
    MAX(days_to_recid) AS max_days_to_recid

FROM raw.iowa_recidivism;


-- Step 15: Investigate unusually long supervision periods
-- Values above 120 months are reviewed, not automatically removed
SELECT
    age,
    race,
    sex,
    months_supervised,
    exit_sup_start_date,
    exit_sup_end_date,
    exit_sup_reason,
    is_recid
FROM raw.iowa_recidivism
WHERE months_supervised > 120
ORDER BY months_supervised DESC;


/* ============================================================
   SECTION 7: ANALYTICS LAYER
   Create an analysis-ready version while preserving raw data
   ============================================================ */

-- Step 16: Create a separate schema for analytical datasets
CREATE SCHEMA analytics;


-- Step 17: Create the cleaned and analysis-ready table
CREATE TABLE analytics.recidivism_clean AS

SELECT
    age,

    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS age_group,

    race,

    COALESCE(sex, 'Unknown') AS sex,

    region_exit,
    cohort_fiscal_year,

    exit_sup_start_date,
    exit_sup_end_date,
    months_supervised,

    CASE
        WHEN months_supervised < 6 THEN '<6 months'
        WHEN months_supervised < 12 THEN '6-11 months'
        WHEN months_supervised < 24 THEN '12-23 months'
        WHEN months_supervised < 60 THEN '24-59 months'
        ELSE '60+ months'
    END AS supervision_duration_group,

    exit_sup_reason,
    exit_class,
    exit_type,
    exit_subtype,

    is_recid,

    CASE
        WHEN is_recid = TRUE THEN 1
        ELSE 0
    END AS recidivism_flag,

    days_to_recid,
    survival_time_months,

    recid_convicting_crime_type,
    recid_convicting_crime_subtype,

    COALESCE(risk_ranking, 'Unknown') AS risk_ranking,

    work_unit_region_nm,
    work_unit_nm

FROM raw.iowa_recidivism;


/* ============================================================
   SECTION 8: POST-TRANSFORMATION VALIDATION
   Confirm key metrics remain consistent after transformation
   ============================================================ */

-- Step 18: Validate record count and overall recidivism rate
SELECT
    COUNT(*) AS total_records,
    SUM(recidivism_flag) AS recidivism_records,
    ROUND(AVG(recidivism_flag) * 100, 2) AS recidivism_rate_pct
FROM analytics.recidivism_clean;


/* ============================================================
   SECTION 9: RECIDIVISM ANALYSIS
   Explore patterns across demographic and supervision factors
   ============================================================ */

-- Step 19: Analyze recidivism rate by age group
SELECT
    age_group,
    COUNT(*) AS total_records,
    SUM(recidivism_flag) AS recidivism_records,
    ROUND(AVG(recidivism_flag) * 100, 2) AS recidivism_rate_pct
FROM analytics.recidivism_clean
GROUP BY age_group
ORDER BY recidivism_rate_pct DESC;


-- Step 20: Analyze recidivism rate by risk ranking
SELECT
    risk_ranking,
    COUNT(*) AS total_records,
    SUM(recidivism_flag) AS recidivism_records,
    ROUND(AVG(recidivism_flag) * 100, 2) AS recidivism_rate_pct
FROM analytics.recidivism_clean
GROUP BY risk_ranking
ORDER BY recidivism_rate_pct DESC;


-- Step 21: Analyze recidivism by supervision duration
SELECT
    supervision_duration_group,
    COUNT(*) AS total_records,
    SUM(recidivism_flag) AS recidivism_records,
    ROUND(AVG(recidivism_flag) * 100, 2) AS recidivism_rate_pct
FROM analytics.recidivism_clean
GROUP BY supervision_duration_group
ORDER BY recidivism_rate_pct DESC;


-- Step 22: Analyze recidivism by exit region/facility
SELECT
    region_exit,
    COUNT(*) AS total_records,
    SUM(recidivism_flag) AS recidivism_records,
    ROUND(AVG(recidivism_flag) * 100, 2) AS recidivism_rate_pct
FROM analytics.recidivism_clean
GROUP BY region_exit
ORDER BY recidivism_rate_pct DESC;


/* ============================================================
   SECTION 10: TREND ANALYSIS USING WINDOW FUNCTIONS
   Demonstrate CTEs, LAG(), and year-over-year comparisons
   ============================================================ */

-- Step 23: Calculate cohort recidivism trends and
-- year-over-year percentage-point changes
WITH yearly_recidivism AS (
    SELECT
        cohort_fiscal_year,
        COUNT(*) AS total_records,
        SUM(recidivism_flag) AS recidivism_records,
        ROUND(AVG(recidivism_flag) * 100, 2) AS recidivism_rate_pct
    FROM analytics.recidivism_clean
    GROUP BY cohort_fiscal_year
)

SELECT
    cohort_fiscal_year,
    total_records,
    recidivism_records,
    recidivism_rate_pct,

    LAG(recidivism_rate_pct) OVER (
        ORDER BY cohort_fiscal_year
    ) AS previous_year_rate,

    ROUND(
        recidivism_rate_pct -
        LAG(recidivism_rate_pct) OVER (
            ORDER BY cohort_fiscal_year
        ),
        2
    ) AS yoy_change_pct_points

FROM yearly_recidivism
ORDER BY cohort_fiscal_year;


/* ============================================================
   SECTION 11: REGIONAL RANKING USING WINDOW FUNCTIONS
   Rank regions/facilities based on observed recidivism rate
   ============================================================ */

-- Step 24: Rank regions from highest to lowest recidivism rate
WITH regional_recidivism AS (
    SELECT
        region_exit,
        COUNT(*) AS total_records,
        SUM(recidivism_flag) AS recidivism_records,
        ROUND(AVG(recidivism_flag) * 100, 2) AS recidivism_rate_pct
    FROM analytics.recidivism_clean
    GROUP BY region_exit
)

SELECT
    region_exit,
    total_records,
    recidivism_records,
    recidivism_rate_pct,

    RANK() OVER (
        ORDER BY recidivism_rate_pct DESC
    ) AS recidivism_rate_rank

FROM regional_recidivism
ORDER BY recidivism_rate_rank;