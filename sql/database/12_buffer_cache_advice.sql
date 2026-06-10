-- TITLE: Buffer cache advice avec détection du knee
-- NOUVEAU vs version d'origine : pas de section sur v$db_cache_advice dans la version d'origine.
-- Lit la courbe de read_factor à différents facteurs et marque où se trouve
-- le knee (coude) qui révèle le bon dimensionnement.
SELECT
  ROUND(size_for_estimate)                                       AS cache_mb,
  ROUND(size_factor, 2)                                          AS factor,
  buffers_for_estimate                                           AS buffers,
  ROUND(estd_physical_read_factor, 3)                            AS read_factor,
  estd_physical_reads                                            AS estd_reads,
  CASE
    WHEN size_factor = 1
      THEN '← current'
    WHEN size_factor < 1 AND estd_physical_read_factor <= 1.05
      THEN 'INFO: cache reclaimable here'
    WHEN size_factor < 1 AND estd_physical_read_factor > 1.5
      THEN 'OK: sharp degradation if smaller'
    WHEN size_factor > 1 AND estd_physical_read_factor < 0.95
      THEN 'INFO: larger cache would still help'
    WHEN size_factor > 1 AND estd_physical_read_factor >= 0.95
      THEN 'OK: plateau reached'
    ELSE ''
  END                                                            AS diagnostic
FROM v$db_cache_advice
WHERE name = 'DEFAULT'
  AND block_size = (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size')
ORDER BY size_factor
;
