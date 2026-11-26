-- CREDIT CARD FINANCIAL ANALYTICS | MySQL 9.1 / Power BI
-- Portfolio reconstruction from project conversation and execution logs.
-- Run sections individually on a fresh database, NOT the entire file on an
-- existing project. Imports append rows; repeating them may create duplicates.
-- Replace local file paths as needed. No credentials are included.

-- 01. Database setup
CREATE DATABASE IF NOT EXISTS ccdb;
USE ccdb;
SHOW DATABASES;
SELECT DATABASE();

-- 02. Credit card table (reconstructed from actual DESCRIBE output;
-- keys, defaults and nullability were not supplied).
CREATE TABLE IF NOT EXISTS cc_detail (
    Client_Num INT,
    Card_Category VARCHAR(20),
    Annual_Fees INT,
    Activation_30_Days INT,
    Customer_Acq_Cost INT,
    Week_Start_Date DATE,
    Week_Num VARCHAR(20),
    Qtr VARCHAR(10),
    current_year INT,
    Credit_Limit DECIMAL(10,2),
    Total_Revolving_Bal INT,
    Total_Trans_Amt INT,
    Total_Trans_Ct INT,
    Avg_Utilization_Ratio DECIMAL(10,3),
    Use_Chip VARCHAR(10),
    Exp_Type VARCHAR(50),
    Interest_Earned DECIMAL(10,3),
    Delinquent_Acc VARCHAR(5)
);
-- Customer table: original CREATE TABLE statement / full data types were not
-- available in the conversation. Use your actual cust_detail definition.
-- On your existing database, export it using SHOW CREATE TABLE cust_detail.
DESCRIBE cc_detail;
-- DESCRIBE cust_detail;
-- SHOW CREATE TABLE cust_detail;

-- 03. Enable local CSV loading (trusted local server only; admin privilege).
-- Error 3948 was resolved by enabling both server and Workbench client.
-- In Workbench: Manage Connections > Advanced > Others: OPT_LOCAL_INFILE=1
-- Reopen the connection after changing client settings.
-- SET GLOBAL local_infile = 1;
SHOW GLOBAL VARIABLES LIKE 'local_infile';

-- 04. Corrected credit card import (fresh empty cc_detail only).
-- Original direct import produced zero dates. CSV date format: DD-MM-YYYY.
SELECT STR_TO_DATE('31-12-2023', '%d-%m-%Y') AS Converted_Date;
-- CSV Total_Trans_Vol maps to Total_Trans_Ct; Use Chip maps to Use_Chip;
-- Exp Type maps to Exp_Type. The date is read into a session variable.
/*
LOAD DATA LOCAL INFILE
'C:/Users/HP/Downloads/credit_card.csv'
INTO TABLE cc_detail
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Client_Num, Card_Category, Annual_Fees, Activation_30_Days,
 Customer_Acq_Cost, @week_date, Week_Num, Qtr, current_year,
 Credit_Limit, Total_Revolving_Bal, Total_Trans_Amt, Total_Trans_Ct,
 Avg_Utilization_Ratio, Use_Chip, Exp_Type, Interest_Earned, Delinquent_Acc)
SET Week_Start_Date = STR_TO_DATE(@week_date, '%d-%m-%Y');
SHOW WARNINGS LIMIT 10;
*/

-- 05. Historical date repair (only if original table contains bad dates).
-- This is the actual repair workflow; do not run after a successful import.
/*
CREATE TABLE cc_detail_fixed LIKE cc_detail;
LOAD DATA LOCAL INFILE
'C:/Users/HP/Downloads/credit_card.csv'
INTO TABLE cc_detail_fixed
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Client_Num, Card_Category, Annual_Fees, Activation_30_Days,
 Customer_Acq_Cost, @week_date, Week_Num, Qtr, current_year,
 Credit_Limit, Total_Revolving_Bal, Total_Trans_Amt, Total_Trans_Ct,
 Avg_Utilization_Ratio, Use_Chip, Exp_Type, Interest_Earned, Delinquent_Acc)
SET Week_Start_Date = STR_TO_DATE(@week_date, '%d-%m-%Y');
SHOW WARNINGS LIMIT 10;
SELECT COUNT(*) FROM cc_detail_fixed;
SELECT * FROM cc_detail_fixed LIMIT 10;
SELECT DISTINCT Week_Start_Date FROM cc_detail_fixed ORDER BY Week_Start_Date;
SELECT COUNT(*) AS Invalid_Dates FROM cc_detail_fixed
WHERE Week_Start_Date IS NULL OR CAST(Week_Start_Date AS CHAR) = '0000-00-00';
-- Verified import: 10108 rows, zero warnings, 52 distinct weekly dates.
-- Only rename after validating the corrected table and ensuring backup name is unused.
RENAME TABLE cc_detail TO cc_detail_backup, cc_detail_fixed TO cc_detail;
*/

-- 06. Initial customer import (requires actual customer table and matching CSV order).
/*
SELECT COUNT(*) FROM cust_detail;
LOAD DATA LOCAL INFILE
'C:/Users/HP/Downloads/customer.csv'
INTO TABLE cust_detail
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;
SHOW WARNINGS LIMIT 10;
SELECT * FROM cust_detail LIMIT 10;
SELECT COUNT(*) FROM cust_detail;
*/

-- 07. Additional records (run once per file, after checking no prior import).
-- Successful execution logs: 185 rows per file, zero warnings.
/*
LOAD DATA LOCAL INFILE
'C:/Users/HP/Downloads/cust_add.csv'
INTO TABLE cust_detail
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;
SHOW WARNINGS LIMIT 10;

LOAD DATA LOCAL INFILE
'C:/Users/HP/Downloads/cc_add.csv'
INTO TABLE cc_detail
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Client_Num, Card_Category, Annual_Fees, Activation_30_Days,
 Customer_Acq_Cost, @week_date, Week_Num, Qtr, current_year,
 Credit_Limit, Total_Revolving_Bal, Total_Trans_Amt, Total_Trans_Ct,
 Avg_Utilization_Ratio, Use_Chip, Exp_Type, Interest_Earned, Delinquent_Acc)
SET Week_Start_Date = STR_TO_DATE(@week_date, '%d-%m-%Y');
SHOW WARNINGS LIMIT 10;
*/

-- 08. Historical wrong-table import repair.
-- cc_add.csv was mistakenly loaded into cust_detail. 370 invalid rows were
-- identified and deleted; this is NOT a routine data refresh step.
/*
SELECT * FROM cust_detail WHERE Customer_Age = 0;
CREATE TABLE cust_detail_backup LIKE cust_detail;
INSERT INTO cust_detail_backup SELECT * FROM cust_detail;
SELECT COUNT(*) FROM cust_detail_backup; -- observed 10663
SELECT COUNT(*) AS Wrong_Records FROM cust_detail
WHERE Customer_Age = 0 AND State_cd = 'Week-53'
AND Marital_Status = '31-12-2023';
-- Inspect matching rows, verify backup, and confirm InnoDB before deletion.
SELECT * FROM cust_detail
WHERE Customer_Age = 0 AND State_cd = 'Week-53'
AND Marital_Status = '31-12-2023';
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;
DELETE FROM cust_detail
WHERE Customer_Age = 0 AND State_cd = 'Week-53'
AND Marital_Status = '31-12-2023';
SELECT ROW_COUNT() AS Deleted_Records;
-- Action Output confirmed 370 affected rows. Validate before committing.
SELECT COUNT(*) FROM cust_detail;
SELECT COUNT(*) FROM cust_detail WHERE Customer_Age = 0;
-- Execute COMMIT only if results match expectations; otherwise ROLLBACK.
-- COMMIT;
-- ROLLBACK;
-- SET SQL_SAFE_UPDATES = 1;
*/

-- 09. Final validation (read-only; run after both tables exist).
/*
SELECT COUNT(*) AS Credit_Card_Records FROM cc_detail;
SELECT COUNT(*) AS Total_Customers FROM cust_detail;
SELECT COUNT(*) AS Incorrect_Records FROM cust_detail WHERE Customer_Age = 0;
SELECT Client_Num, COUNT(*) AS Total FROM cust_detail
GROUP BY Client_Num HAVING COUNT(*) > 1;
SELECT * FROM cc_detail LIMIT 10;
SELECT DISTINCT Week_Start_Date FROM cc_detail ORDER BY Week_Start_Date;
SELECT COUNT(*) AS Invalid_Dates FROM cc_detail
WHERE Week_Start_Date IS NULL OR CAST(Week_Start_Date AS CHAR) = '0000-00-00';
SELECT
    (SELECT COUNT(*) FROM cc_detail) AS Credit_Card_Records,
    (SELECT COUNT(*) FROM cust_detail) AS Customer_Records,
    (SELECT COUNT(*) FROM cust_detail WHERE Customer_Age = 0) AS Incorrect_Records,
    (SELECT COUNT(DISTINCT Week_Start_Date) FROM cc_detail) AS Total_Weeks;
-- Expected: 10293 / 10293 / 0 / 53. Final combined output not supplied.
-- Customer duplicate query returned zero rows in the execution screenshot.
*/

-- 10. Optional security cleanup after imports (admin privilege).
-- SET GLOBAL local_infile = 0;
-- Remove OPT_LOCAL_INFILE=1 from Workbench connection settings and reconnect.
-- Power BI: connect to ccdb on localhost:3306; use cc_detail and cust_detail.
-- After validation and commit: Home > Refresh. No backup tables in the model.
