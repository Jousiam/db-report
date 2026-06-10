-- TITLE: Top 20 SQL par temps ecoule cumule (v$sqlarea)
-- Identifie les requetes les plus couteuses du systeme. Un SQL avec
-- avg_elapsed > 10s/exec OU executions > 100k avec avg > 100ms est candidat
-- prioritaire pour optimisation (indexation, plan d'execution, bind variables).
SELECT *
FROM (
  SELECT
    sql_id,
    parsing_schema_name                                          AS schema,
    executions,
    ROUND(elapsed_time / 1000000, 1)                             AS total_elapsed_s,
    ROUND(elapsed_time / NULLIF(executions, 0) / 1000, 1)        AS avg_ms_per_exec,
    ROUND(cpu_time / 1000000, 1)                                 AS cpu_s,
    buffer_gets,
    disk_reads,
    rows_processed,
    SUBSTR(sql_text, 1, 100)                                     AS sql_preview,
    CASE
      WHEN executions = 0                                         THEN 'NOTICE: parsed but never executed'
      WHEN elapsed_time / NULLIF(executions,0) / 1000 > 10000     THEN 'CRITICAL: > 10s par execution — a optimiser'
      WHEN executions > 100000
           AND elapsed_time / executions / 1000 > 100             THEN 'CRITICAL: SQL chaud (>100k exec) + lent — optimiser en priorite'
      WHEN buffer_gets / NULLIF(executions,0) > 1000000           THEN 'WARNING: > 1M buffer gets/exec — full scan suspect'
      WHEN elapsed_time / NULLIF(executions,0) / 1000 > 1000      THEN 'WARNING: > 1s/exec'
      ELSE 'OK'
    END                                                            AS verdict
  FROM v$sqlarea
  WHERE parsing_schema_name NOT IN ('SYS','SYSTEM','DBSNMP','APPQOSSYS','GSMADMIN_INTERNAL','AUDSYS')
  ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 20
;
