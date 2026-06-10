-- TITLE: Jobs scheduler en echec (30 derniers jours)
SELECT *
FROM (
  SELECT
    TO_CHAR(log_date,        'YYYY-MM-DD HH24:MI:SS')   AS log_date,
    owner,
    job_name,
    status,
    error#                                              AS error_code,
    ROUND(EXTRACT(SECOND FROM run_duration)
        + EXTRACT(MINUTE FROM run_duration) * 60
        + EXTRACT(HOUR   FROM run_duration) * 3600, 1)  AS duration_s,
    SUBSTR(additional_info, 1, 150)                     AS additional_info,
    CASE
      WHEN job_name LIKE 'ORA$AT_OS_OPT%'               THEN 'CRITICAL: auto stats collection en echec — stats CBO perimees'
      WHEN job_name LIKE 'ORA$AT_SA%'                   THEN 'WARNING: segment advisor KO'
      WHEN job_name LIKE 'ORA$AT_SQ%'                   THEN 'WARNING: SQL tuning advisor KO'
      WHEN job_name LIKE 'PURGE%' OR job_name LIKE '%CLEANUP%' THEN 'WARNING: job de purge KO — espace risque'
      WHEN error# IN (1652,1653,1654,1655)              THEN 'CRITICAL: ORA-' || error# || ' espace insuffisant'
      WHEN error# = 12751                               THEN 'WARNING: CPU time limit exceeded (resource manager)'
      ELSE status
    END                                                 AS verdict
  FROM dba_scheduler_job_run_details
  WHERE log_date >= SYSDATE - 30
    AND status IN ('FAILED', 'STOPPED', 'BROKEN')
  ORDER BY log_date DESC
)
WHERE ROWNUM <= 50
;
