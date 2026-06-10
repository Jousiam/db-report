-- TITLE: Bascules de redolog par jour (30 derniers jours)
-- AMÉLIORÉ vs version d'origine : format date ISO + alerte si dépassement seuil 24/jour
SELECT
  TO_CHAR(TRUNC(first_time), 'YYYY-MM-DD')               AS day,
  COUNT(*)                                                AS switches_count,
  ROUND(AVG(blocks * block_size) / 1024/1024, 1)          AS avg_size_mb,
  ROUND(SUM(blocks * block_size) / 1024/1024)             AS total_size_mb,
  CASE
    WHEN COUNT(*) > 96 THEN 'CRITICAL: > 96/jour (~4/h)'
    WHEN COUNT(*) > 48 THEN 'WARNING: > 48/jour (~2/h)'
    WHEN COUNT(*) > 24 THEN 'NOTICE: > 24/jour (~1/h)'
    ELSE 'OK'
  END                                                     AS verdict
FROM v$archived_log
WHERE first_time >= SYSDATE - 30
  AND dest_id = (SELECT MIN(dest_id) FROM v$archived_log WHERE first_time >= SYSDATE - 30)
GROUP BY TRUNC(first_time)
ORDER BY day DESC
;
