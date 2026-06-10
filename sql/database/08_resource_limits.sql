-- TITLE: Resource Limits (GV$RESOURCE_LIMIT)
-- FIX vs version précédente : `INITIAL` est un mot réservé Oracle (clause de
-- stockage) et casse le parser quand utilisé comme alias → ORA-00923.
-- Aussi : remplacement de TO_NUMBER(x, '999999999') par TO_NUMBER(x) simple
-- (plus tolérant aux valeurs avec espaces de tête / nombres > 9 chiffres).
SELECT
  inst_id,
  resource_name,
  current_utilization                                       AS current_use,
  max_utilization                                           AS max_use,
  initial_allocation                                        AS initial_alloc,
  limit_value                                               AS limit_val,
  CASE
    WHEN limit_value = 'UNLIMITED' THEN NULL
    ELSE ROUND(max_utilization * 100 / NULLIF(TO_NUMBER(TRIM(limit_value) DEFAULT NULL ON CONVERSION ERROR), 0), 1)
  END                                                       AS max_pct_of_limit,
  CASE
    WHEN limit_value = 'UNLIMITED' THEN 'UNLIMITED'
    WHEN max_utilization * 100 / NULLIF(TO_NUMBER(TRIM(limit_value) DEFAULT NULL ON CONVERSION ERROR), 0) > 90 THEN 'CRITICAL: > 90%'
    WHEN max_utilization * 100 / NULLIF(TO_NUMBER(TRIM(limit_value) DEFAULT NULL ON CONVERSION ERROR), 0) > 80 THEN 'WARNING: > 80%'
    ELSE 'OK'
  END                                                       AS verdict
FROM gv$resource_limit
WHERE resource_name IN ('processes', 'sessions', 'enqueue_locks', 'enqueue_resources',
                        'dml_locks', 'transactions', 'parallel_max_servers',
                        'gcs_resources', 'gcs_shadows')
ORDER BY inst_id, resource_name
;
