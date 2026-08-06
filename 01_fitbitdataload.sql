-- Uploading the two month files: e.g. dailyActivity 
-- 1. Create table and upload month 1 csv file with written out the schema like below, forcing field type to be string and 1 header row skipped (advance options).
-- Id:INTEGER,ActivityHour:STRING,TotalIntensity:INTEGER,AverageIntensity:FLOAT
-- 2. Check if data loaded correctly and cleanly

SELECT *
FROM `bellabeat.dailyActivity` LIMIT 10;

-- 3. Check table schema to ensure field types uploaded correctly
-- 4. Create temp table for month 2 and upload csv file schema written and 1 header row skipped
-- 5. Check if data for temp table loaded correctly and cleanly

SELECT *
FROM `bellabeat.dailyActivity_m2_temp` LIMIT 5;

-- Note 1: Schema autodetect only worked cleanly for dailyActivity (which had a plain date, no time)

-- 6. Check temp table schema matches with original table
-- 7. Append temp table to original table

INSERT INTO bellabeat.dailyActivity
SELECT * FROM `bellabeat.dailyActivity_m2_temp`;

-- 8. Verification query, run against each table. E.g.
  
SELECT
  COUNT(*)           AS total_rows,
  COUNT(DISTINCT Id) AS distinct_users,
  MIN(ActivityDate)  AS earliest,
  MAX(ActivityDate)  AS latest
FROM bellabeat.dailyActivity;

-- OR

SELECT COUNT(*) AS num_rows, COUNT(DISTINCT Id) AS users
FROM bellabeat.hourlySteps;

-- 9. Once confirmed that both tables combined successfully, drop the temp table

DROP TABLE bellabeat.dailyActivity_m2_temp;

-- Repeat for the rest of the files that are split between two months (hourlyIntensities, hourlyCalories, hourlySteps, dailySleep, heartrateSeconds)

-- Note 2: To be consistent in table naming, change sleepDay to dailySleep
-- Note 3: distinct user counts vary by file — activity 35, sleep 24, heart rate 15.
-- This drop-off is itself a behavioural signal (fewer users track sleep/HR than steps)
-- and feeds the analysis, not just a load check.

