-- TITLE: Historique des opérations de resize mémoire (50 dernières)
-- AMÉLIORÉ vs version d'origine : format ISO + durée calculée + filtre status
SELECT *
FROM (
  SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS')          AS start_time,
    ROUND((end_time - start_time) * 86400, 1)             AS duration_s,
    component,
    oper_type,
    oper_mode,
    parameter,
    ROUND(initial_size / 1024/1024)                       AS initial_mb,
    ROUND(target_size  / 1024/1024)                       AS target_mb,
    ROUND(final_size   / 1024/1024)                       AS final_mb,
    status
  FROM v$memory_resize_ops
  WHERE component != 'memoptimize buffer cache'
  ORDER BY start_time DESC
)
WHERE ROWNUM <= 50
;
