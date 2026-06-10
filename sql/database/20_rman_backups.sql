-- TITLE: Sauvegardes RMAN (30 derniers jours)
WITH last_success AS (
  SELECT MAX(start_time) AS last_ok
  FROM v$rman_backup_job_details
  WHERE status = 'COMPLETED' AND input_type IN ('DB FULL','DB INCR','RECVR AREA')
)
SELECT *
FROM (
  SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS')        AS start_time,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS')        AS end_time,
    input_type,
    status,
    ROUND(elapsed_seconds / 60, 1)                      AS duration_min,
    ROUND(input_bytes  / 1024/1024/1024, 2)             AS input_gb,
    ROUND(output_bytes / 1024/1024/1024, 2)             AS output_gb,
    CASE
      WHEN status = 'COMPLETED' AND
           start_time = (SELECT last_ok FROM last_success) AND
           start_time < SYSDATE - 1                     THEN 'CRITICAL: aucun backup reussi depuis > 24h'
      WHEN status = 'COMPLETED'                         THEN 'OK'
      WHEN status = 'COMPLETED WITH WARNINGS'           THEN 'WARNING'
      WHEN status LIKE 'FAILED%'                        THEN 'FAILED'
      ELSE status
    END                                                 AS verdict
  FROM v$rman_backup_job_details
  WHERE start_time >= SYSDATE - 30
  ORDER BY start_time DESC
)
WHERE ROWNUM <= 50
;
