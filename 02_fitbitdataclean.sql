-- Convert all ActivityHour type to timestamps for hourlyIntensities, hourlyCalories, hourlySteps
-- 1. Conduct verification step to check the parse works on all rows for each table (edit table in query accordingly)
-- Result: all tables returned 0 failed_parses, confirming every row parsed cleanly before building the clean tables.

SELECT COUNT(*) AS total,
       COUNTIF(SAFE.PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', ActivityHour) IS NULL) AS failed_parses
FROM bellabeat.hourlyIntensities;

-- 2. Create new cleaned table for each
CREATE OR REPLACE TABLE bellabeat.hourlyIntensities_clean AS
SELECT
  Id,
  PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', ActivityHour) AS activity_hour,
  EXTRACT(DATE FROM PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', ActivityHour)) AS activity_date,
  EXTRACT(HOUR FROM PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', ActivityHour)) AS hour_of_day,
  TotalIntensity,
  AverageIntensity
FROM bellabeat.hourlyIntensities;

-- Note: don't forget to adjust columns according to each file i.e. hourlyCalories, you'd take out TotalIntensity & AverageIntensity and replace with Calories column

-- For dailySleep, same verification query but slight change in new table creation, taking out activity_hour and only keeping the extracted date as hour is redundant

CREATE OR REPLACE TABLE bellabeat.dailySleep_clean AS
  SELECT
  Id,
  EXTRACT(DATE FROM PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', SleepDay)) AS sleep_date,
  TotalSleepRecords,
  TotalMinutesAsleep,
  TotalTimeInBed

  FROM bellabeat.dailySleep;

-- For heartrateSeconds,same verification query, different query for new table creation. Collapses original 3.6m per second readings to approx. one row per user per day
CREATE OR REPLACE TABLE bellabeat.heartrate_daily AS
SELECT
  Id,
  EXTRACT(DATE FROM PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', Time)) AS activity_date,
  ROUND(AVG(Value), 1) AS avg_heart_rate, --main marketing-relevant number (typical HR)
  MIN(Value)           AS min_heart_rate, --rough proxy for resting heart rate, touches recovery/stress
  MAX(Value)           AS max_heart_rate  --exertion peaks
FROM bellabeat.heartrateSeconds
GROUP BY Id, activity_date;

-- Check after creation
SELECT COUNT(*) AS user_days, COUNT(DISTINCT Id) AS users
FROM bellabeat.heartrate_daily;

-- Quality Check
-- 1. dailySleep_clean
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) - COUNT(DISTINCT FORMAT ('%t|%t', Id, sleep_date)) AS duplicate_rows,
  COUNTIF(TotalMinutesAsleep > TotalTimeInBed) AS asleep_exceeds_inbed,
  COUNTIF(TotalSleepRecords > 1) AS multi_session_days,
  COUNTIF(TotalMinutesAsleep = 0) AS zero_sleep_rows
  FROM bellabeat.dailySleep_clean

-- 2. 
