-- TITLE: Options Oracle utilisees (DBA_FEATURE_USAGE_STATISTICS) — vigilance licences
SELECT
  name                                            AS feature_name,
  detected_usages,
  TO_CHAR(first_usage_date, 'YYYY-MM-DD')         AS first_used,
  TO_CHAR(last_usage_date,  'YYYY-MM-DD')         AS last_used,
  currently_used,
  CASE
    WHEN name IN ('Diagnostic Pack','ADDM','AWR Report','Active Session History (ASH)',
                  'Automatic Workload Repository','Real-Time SQL Monitoring')
         THEN 'LICENSE: Diagnostic Pack requis'
    WHEN name IN ('Tuning Pack','SQL Tuning Advisor','SQL Access Advisor',
                  'SQL Profile','Real-Time SQL Monitoring','Automatic SQL Tuning Advisor')
         THEN 'LICENSE: Tuning Pack requis'
    WHEN name LIKE '%Partition%'
         THEN 'LICENSE: Partitioning option requis'
    WHEN name LIKE '%Advanced Compression%' OR name LIKE '%OLTP Compression%'
         THEN 'LICENSE: Advanced Compression requis'
    WHEN name LIKE '%Advanced Security%' OR name LIKE '%Transparent Data Encryption%' OR name LIKE '%TDE%'
         THEN 'LICENSE: Advanced Security requis'
    WHEN name LIKE '%Database Vault%'
         THEN 'LICENSE: Database Vault requis'
    WHEN name LIKE '%Spatial%' OR name LIKE '%Multimedia%'
         THEN 'LICENSE: Spatial and Graph requis'
    WHEN name LIKE '%RAC%' OR name LIKE '%Real Application Clusters%'
         THEN 'LICENSE: RAC requis'
    WHEN name LIKE '%Active Data Guard%'
         THEN 'LICENSE: Active Data Guard requis'
    WHEN name LIKE '%In-Memory%'
         THEN 'LICENSE: In-Memory option requis'
    ELSE ''
  END                                              AS license_check
FROM dba_feature_usage_statistics
WHERE detected_usages > 0
  AND name NOT LIKE 'Heat Map'
ORDER BY last_usage_date DESC NULLS LAST, name
;
