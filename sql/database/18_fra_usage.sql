-- TITLE: Fast Recovery Area — usage par type
WITH fra AS (
  SELECT name, space_limit, space_used, space_reclaimable
  FROM v$recovery_file_dest
)
SELECT
  fra.name                                                              AS fra_path,
  ROUND(fra.space_limit       / 1024/1024/1024, 2)                      AS limit_gb,
  ROUND(fra.space_used        / 1024/1024/1024, 2)                      AS used_gb,
  ROUND(fra.space_reclaimable / 1024/1024/1024, 2)                      AS reclaimable_gb,
  ROUND(fra.space_used * 100 / NULLIF(fra.space_limit, 0), 1)           AS used_pct,
  CASE
    WHEN fra.space_used > 0.90 * fra.space_limit
         AND fra.space_reclaimable < 0.10 * fra.space_limit             THEN 'CRITICAL: > 90% et peu de reclaimable — ARCH va bloquer LGWR'
    WHEN fra.space_used > 0.90 * fra.space_limit                        THEN 'CRITICAL: > 90% — lancer RMAN DELETE ARCHIVELOG'
    WHEN fra.space_used > 0.80 * fra.space_limit                        THEN 'WARNING: > 80% — surveiller'
    ELSE 'OK'
  END                                                                    AS verdict
FROM fra
UNION ALL
SELECT
  '  ' || file_type                                                      AS fra_path,
  NULL                                                                   AS limit_gb,
  ROUND(SUM(percent_space_used) * fra.space_limit / 100 / 1024/1024/1024, 2),
  ROUND(SUM(percent_space_reclaimable) * fra.space_limit / 100 / 1024/1024/1024, 2),
  ROUND(SUM(percent_space_used), 2),
  TO_CHAR(SUM(number_of_files)) || ' files'                              AS verdict
FROM v$flash_recovery_area_usage, (SELECT space_limit FROM v$recovery_file_dest) fra
WHERE percent_space_used > 0
GROUP BY file_type, fra.space_limit
ORDER BY 1
;
