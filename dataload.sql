-- Uploading the two month files: dailyActivity 
-- 1. Create table and upload month 1 csv file with schema auto-detected
-- 2. Check if data loaded correctly and cleanly

SELECT *
FROM `bellabeat.dailyActivity` LIMIT 10

-- 3. Check table schema to ensure field types uploaded correctly
-- 4. Create temp table for month 2 and upload csv file schema auto-detected and 1 header row skipped (advance options)
-- 5. Check if data for temp table loaded correctly and cleanly

SELECT *
FROM `bellabeat.dailyActivity_m2_temp` LIMIT 5

-- 6. Check temp table schema matches with original table
-- 7. Append temp table to original table

INSERT INTO bellabeat.dailyActivity
SELECT * FROM `bellabeat.dailyActivity_m2_temp`

-- 8. Verify the new combined table to ensure date range matches
  
SELECT
  COUNT(*)           AS total_rows,
  COUNT(DISTINCT Id) AS distinct_users,
  MIN(ActivityDate)  AS earliest,
  MAX(ActivityDate)  AS latest
FROM bellabeat.dailyActivity;

-- 9. Once confirmed that both tables combined successfully, drop the temp table

DROP TABLE bellabeat.dailyActivity_m2_temp;

-- Repeat for the rest of the files that are split between two months
