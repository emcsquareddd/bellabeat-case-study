-- Bellabeat case study — behavioural analysis
-- Source: FitBit Fitness Tracker Data (Kaggle, Mobius), 35 users, Mar–May 2016
-- Analysis window: 2016-04-12 to 2016-05-12 (see DATA VALIDATION below)
-- Coverage by table: activity 35 users, sleep 24, heart rate 15

-- DATA VALIDATION
-- 1. Look into the dates of when the data starts and ends and to check they're all distinct rows and not duplicates
SELECT
  MIN(ActivityDate) AS first_day,
  MAX(ActivityDate) AS last_day,
  DATE_DIFF(MAX(ActivityDate), MIN(ActivityDate), DAY) + 1 AS calendar_days,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT CONCAT(CAST(Id AS STRING), CAST(ActivityDate AS STRING))) AS distinct_user_days
FROM `bellabeat.dailyActivity_clean`;

-- 2. Breakdown into individual users and their start and end dates
SELECT
  Id,
  MIN(ActivityDate) AS first_day,
  MAX(ActivityDate) AS last_day,
  DATE_DIFF(MAX(ActivityDate), MIN(ActivityDate), DAY) + 1 AS span_days,
  COUNT(*) AS rows_present
FROM `bellabeat.dailyActivity_clean`
GROUP BY Id
ORDER BY rows_present;

--3. Check the rest of the other tables you will analyse to check their start and end dates
SELECT 'dailyActivity' AS table_name,
       MIN(ActivityDate) AS first_day,
       MAX(ActivityDate) AS last_day,
       COUNT(DISTINCT Id) AS users,
       COUNT(*) AS rows_total
FROM `bellabeat.dailyActivity_clean`

UNION ALL

SELECT 'sleepDay',
       MIN(sleep_date), MAX(sleep_date), COUNT(DISTINCT Id), COUNT(*)
FROM `bellabeat.dailySleep_clean`

UNION ALL

SELECT 'calories',
      MIN(activity_date), MAX(activity_date), COUNT(DISTINCT Id), COUNT(*)
FROM `bellabeat.hourlyCalories_clean`

UNION ALL

SELECT 'heartrate',
       MIN(DATE(activity_date)), MAX(DATE(activity_date)), COUNT(DISTINCT Id), COUNT(*)
FROM `bellabeat.heartrate_daily`

UNION ALL

SELECT 'hourlySteps',
       MIN(DATE(activity_hour)), MAX(DATE(activity_hour)), COUNT(DISTINCT Id), COUNT(*)
FROM `bellabeat.hourlySteps_clean`

ORDER BY table_name;

-- 4. Check how many users have data on each date to see when enrolment happened
SELECT
  ActivityDate,
  COUNT(DISTINCT Id) AS users_with_data
FROM `bellabeat.dailyActivity_clean`
GROUP BY ActivityDate
ORDER BY ActivityDate;

-- 5. Check whether hourly data exists for days missing from dailyActivity,
-- which would mean cleaning dropped days that were actually tracked
SELECT
  CASE
    WHEN h.day BETWEEN '2016-04-12' AND '2016-05-12' THEN 'in window'
    ELSE 'before window'
  END AS period,
  COUNT(*) AS missing_daily_rows,
  COUNT(DISTINCT h.Id) AS users_affected
FROM (
  SELECT DISTINCT Id, DATE(activity_hour) AS day
  FROM `bellabeat.hourlySteps_clean`
) h
LEFT JOIN `bellabeat.dailyActivity_clean` d
  ON d.Id = h.Id AND d.ActivityDate = h.day
WHERE d.Id IS NULL
GROUP BY period;

-- Time Window: 12 Apr - 12 May 2016. Chosen because enrolment was staggered
-- (2 users to 25 Mar, 10 by 31 Mar, 34 from 1 Apr) so earlier absence
-- reflects recruitment, not non-wear. Also the only period where
-- activity, sleep and heart-rate data all coexist.


-- 6 Questions for behavioural data in order to find 3-4 findings to share with recommendations

-- Q1. Wear consistency: How many days out of the tracked period do people actually wear the device? 

-- 1a. Create view as this is what we'll keep referring back to to limit date range between 2016-04-12 and 2016-05-12
CREATE VIEW `bellabeat.user_wear` AS
WITH days AS (
  SELECT day FROM UNNEST(GENERATE_DATE_ARRAY('2016-04-12','2016-05-12')) AS day
),
grid AS (
  SELECT u.Id, d.day
  FROM (SELECT DISTINCT Id FROM `bellabeat.dailyActivity_clean`) u
  CROSS JOIN days d
)
SELECT
  g.Id,
  31 AS window_days,
  COUNTIF(a.Id IS NOT NULL) AS days_with_data,
  COUNTIF(a.wear_status = 'worn') AS days_worn,
  ROUND(COUNTIF(a.wear_status = 'worn') / 31 * 100, 1) AS pct_days_worn
FROM grid g
LEFT JOIN `bellabeat.dailyActivity_clean` a
  ON a.Id = g.Id AND a.ActivityDate = g.day
GROUP BY g.Id;

-- b. Wear consistency band breakdown
WITH banded AS (
  SELECT
    Id,
    pct_days_worn,
    CASE
      WHEN pct_days_worn = 100 THEN 'every day'
      WHEN pct_days_worn >= 80 THEN 'most days'
      WHEN pct_days_worn >= 25 THEN 'sporadic'
      WHEN pct_days_worn >  0  THEN 'minimal'
      ELSE 'stopped'
    END AS wear_band
  FROM `bellabeat.user_wear`
)
SELECT
  wear_band,
  COUNT(*) AS users,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct_of_users
FROM banded
GROUP BY wear_band
ORDER BY MIN(pct_days_worn) DESC;

-- c. Mean & median 
SELECT
  COUNT(*) AS users_all,
  COUNTIF(pct_days_worn > 0) AS users_active,
  COUNTIF(pct_days_worn = 100) AS users_every_day,

  ROUND(AVG(pct_days_worn), 1) AS mean_all,
  ROUND(AVG(CASE WHEN pct_days_worn > 0 THEN pct_days_worn END), 1) AS mean_active,

  APPROX_QUANTILES(pct_days_worn, 2)[OFFSET(1)] AS median_all,
  APPROX_QUANTILES(CASE WHEN pct_days_worn > 0 THEN pct_days_worn END, 2)[OFFSET(1)] AS median_active
FROM `bellabeat.user_wear`;

--Q2. Weekly patterns: does device wear hold consistent across the week, and does activity vary by day?
--2a. Wear by day of week
WITH days AS (
  SELECT day FROM UNNEST(GENERATE_DATE_ARRAY('2016-04-12','2016-05-12')) AS day
),
grid AS (
  SELECT u.Id, d.day
  FROM (SELECT DISTINCT Id FROM `bellabeat.dailyActivity_clean`) u
  CROSS JOIN days d
)
SELECT
  EXTRACT(DAYOFWEEK FROM g.day) AS day_number,
  FORMAT_DATE('%A', g.day) AS day,
  COUNTIF(a.Id IS NOT NULL) AS days_with_data,
  COUNTIF(a.wear_status = 'worn') AS days_worn,
  ROUND(COUNTIF(a.wear_status = 'worn') / (COUNT(*)) * 100, 1) AS pct_days_worn
FROM grid g
LEFT JOIN `bellabeat.dailyActivity_clean` a
  ON a.Id = g.Id AND a.ActivityDate = g.day
GROUP BY day_number, day
ORDER BY day_number;

-- 2b. Activity by day of week
SELECT
  EXTRACT(DAYOFWEEK FROM ActivityDate) AS day_number,
  FORMAT_DATE('%A', ActivityDate) AS day,
  COUNT(*) AS user_days,
  ROUND(AVG(TotalSteps),1) AS avg_steps,
  ROUND(AVG(VeryActiveMinutes),1) AS avg_VActiveMins,
  ROUND(AVG(FairlyActiveMinutes),1) AS avg_FActiveMins,
  ROUND(AVG(LightlyActiveMinutes),1) AS avg_LActiveMins,
  ROUND(AVG(SedentaryMinutes),1) AS avg_sedMins

FROM `bellabeat.dailyActivity_clean`
WHERE ActivityDate BETWEEN '2016-04-12' AND '2016-05-12'
AND wear_status = 'worn'

GROUP BY day_number, day
ORDER BY day_number;

-- Q4. Time-of-day activity: when across the day are people active?
SELECT
  hour_of_day,
  COUNT(*) AS user_hours,
  ROUND(AVG(StepTotal), 1) AS avg_steps,
  COUNTIF(StepTotal = 0) AS hours_with_no_steps
FROM `bellabeat.hourlySteps_clean`
WHERE activity_date BETWEEN '2016-04-12' AND '2016-05-12'
GROUP BY hour_of_day
ORDER BY hour_of_day;
-- NOTE: activity_hour is stored as UTC, but peak times align with normal
-- waking patterns, indicating the values are already local time. Treated as local.

-- Q5. Sleep behaviour: how many users record sleep, and how consistently?
-- 5a. Daily minute totals: distribution across worn days
SELECT
  COUNT(*) AS user_days,
  ROUND(AVG(total_mins), 1) AS mean_mins,
  APPROX_QUANTILES(total_mins, 4) AS quartiles,
  COUNTIF(total_mins >= 1400) AS days_near_24h,
  COUNTIF(total_mins BETWEEN 1000 AND 1399) AS days_partial,
  COUNTIF(total_mins < 1000) AS days_low
FROM (
  SELECT
    Id,
    ActivityDate,
    VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes + SedentaryMinutes AS total_mins
  FROM `bellabeat.dailyActivity_clean`
  WHERE ActivityDate BETWEEN '2016-04-12' AND '2016-05-12'
    AND wear_status = 'worn'
);

-- 5b. Daily minute totals: average per user
SELECT
  Id,
  COUNT(*) AS days,
  ROUND(AVG(total_mins), 0) AS avg_mins,
  ROUND(AVG(total_mins) / 60, 1) AS avg_hours,
  COUNTIF(total_mins >= 1400) AS days_near_24h
FROM (
  SELECT
    Id,
    VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes + SedentaryMinutes AS total_mins
  FROM `bellabeat.dailyActivity_clean`
  WHERE ActivityDate BETWEEN '2016-04-12' AND '2016-05-12'
    AND wear_status = 'worn'
)
GROUP BY Id
ORDER BY avg_hours DESC;

-- NOTE on 5a/5b: initially read as wear duration. Cross-referencing with
-- sleep data showed the inverse — users with the LOWEST minute totals track
-- sleep most. Sleep minutes are excluded from daily activity totals
-- (verified in 5d below: activity minutes + time in bed = ~1440 on complete
-- days). These totals indicate whether sleep was recorded, not how long the
-- device was worn.

--5c. Sleep tracking per user   
SELECT
  Id,
  COUNT(*) AS nights_tracked,
  ROUND(COUNT(*) / 31 * 100, 1) AS pct_nights_tracked,
  ROUND(AVG(TotalMinutesAsleep) / 60, 1) AS avg_hours_asleep,
  ROUND(AVG(TotalTimeInBed - TotalMinutesAsleep), 0) AS avg_mins_awake_in_bed
FROM `bellabeat.dailySleep_clean`
WHERE sleep_date BETWEEN '2016-04-12' AND '2016-05-12'
GROUP BY Id
ORDER BY nights_tracked DESC;

--5d. To confirm sleep+activeMinutes mechanism
SELECT
  a.Id,
  a.ActivityDate,
  a.VeryActiveMinutes + a.FairlyActiveMinutes + a.LightlyActiveMinutes + a.SedentaryMinutes AS activity_mins,
  s.TotalTimeInBed,
  a.VeryActiveMinutes + a.FairlyActiveMinutes + a.LightlyActiveMinutes + a.SedentaryMinutes + s.TotalTimeInBed AS combined_mins
FROM `bellabeat.dailyActivity_clean` a
JOIN `bellabeat.dailySleep_clean` s
  ON s.Id = a.Id AND s.sleep_date = a.ActivityDate
WHERE a.ActivityDate BETWEEN '2016-04-12' AND '2016-05-12'
LIMIT 20; -- sample check

