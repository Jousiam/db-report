-- TITLE: PGA Target Advisor avec diagnostic
-- NOUVEAU vs version d'origine : ajoute une colonne diagnostic qui répond à
-- "le PGA target est-il bien dimensionné ?" sans avoir à interpréter le tableau.
-- Permet de distinguer "PGA target trop petit" vs "PGA target ok mais limit
-- mal réglée" pour les diagnostics ORA-00700 / ORA-04036.
SELECT
  ROUND(pga_target_for_estimate / 1024/1024)                                AS target_mb,
  ROUND(pga_target_factor, 2)                                               AS factor,
  estd_pga_cache_hit_percentage                                             AS hit_pct,
  estd_overalloc_count                                                      AS overalloc,
  ROUND(estd_time / 1e6)                                                    AS estd_seconds,
  CASE
    WHEN pga_target_factor = 1 AND estd_overalloc_count = 0
         AND estd_pga_cache_hit_percentage = 100
      THEN 'OK: target rightsized'
    WHEN pga_target_factor = 1 AND estd_overalloc_count > 0
      THEN 'BAD: target undersized (overalloc > 0)'
    WHEN pga_target_factor = 1 AND estd_pga_cache_hit_percentage < 95
      THEN 'BAD: target undersized (hit < 95%)'
    WHEN pga_target_factor < 1 AND estd_overalloc_count = 0
         AND estd_pga_cache_hit_percentage = 100
      THEN 'INFO: PGA reclaimable here'
    WHEN pga_target_factor > 1 AND estd_overalloc_count > 0
      THEN 'INFO: more PGA would help'
    WHEN pga_target_factor = 1
      THEN '← current'
    ELSE ''
  END                                                                       AS diagnostic
FROM v$pga_target_advice
ORDER BY pga_target_factor
;
