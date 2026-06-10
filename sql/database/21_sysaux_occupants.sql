-- TITLE: SYSAUX Occupants — taille par composant + verdict
WITH total AS (
  SELECT SUM(space_usage_kbytes) AS total_kb
  FROM v$sysaux_occupants WHERE space_usage_kbytes > 0
)
SELECT
  o.occupant_name,
  o.schema_name,
  ROUND(o.space_usage_kbytes / 1024, 1)                                AS size_mb,
  ROUND(o.space_usage_kbytes * 100 / t.total_kb, 1)                    AS pct_of_sysaux,
  o.move_procedure,
  CASE
    WHEN o.occupant_name = 'SM/OPTSTAT'
         AND o.space_usage_kbytes * 100 / t.total_kb > 30               THEN 'WARNING: stats history > 30% — exec dbms_stats.alter_stats_history_retention(7)'
    WHEN o.occupant_name = 'SM/AWR'
         AND o.space_usage_kbytes * 100 / t.total_kb > 40               THEN 'WARNING: AWR > 40% — reduire retention via dbms_workload_repository'
    WHEN o.occupant_name = 'AUDSYS'
         AND o.space_usage_kbytes / 1024 > 500                          THEN 'WARNING: audit trail > 500MB — exec dbms_audit_mgmt.clean_audit_trail'
    WHEN o.occupant_name = 'LOGMNR'
         AND o.space_usage_kbytes / 1024 > 100                          THEN 'NOTICE: LogMiner dictionnaire > 100MB'
    ELSE 'OK'
  END                                                                   AS verdict
FROM v$sysaux_occupants o, total t
WHERE o.space_usage_kbytes > 0
ORDER BY o.space_usage_kbytes DESC
;
