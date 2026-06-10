-- TITLE: Sessions et cursors usage (open_cursors, session_cached_cursors)
-- RÉÉCRIT : la version précédente lisait v$sesstat (sessions × stats — sur les
-- CDB chargées avec SYSAUX en souffrance, elle pouvait timeout à 120s). Cette
-- version utilise UNIQUEMENT v$sysstat (vue système-wide, fixe, accès instantané).
--
-- Trade-off : on perd le "peak cursors per-session" mais on garde le cache hit
-- ratio système, qui est l'info cle pour dimensionner session_cached_cursors.
SELECT
  'session_cached_cursors'                                                                AS parameter,
  TO_CHAR((SELECT value FROM v$parameter WHERE name = 'session_cached_cursors'))           AS limit_value,
  TO_CHAR((SELECT value FROM v$sysstat   WHERE name = 'session cursor cache hits'))        AS cache_hits,
  TO_CHAR((SELECT value FROM v$sysstat   WHERE name = 'parse count (total)'))              AS parse_total,
  TO_CHAR(ROUND(
    (SELECT value FROM v$sysstat WHERE name = 'session cursor cache hits') * 100 /
    NULLIF((SELECT value FROM v$sysstat WHERE name = 'parse count (total)'), 0),
    1
  )) || ' %'                                                                                AS hit_ratio,
  CASE
    WHEN (SELECT value FROM v$sysstat WHERE name = 'parse count (total)') = 0 THEN 'NO ACTIVITY'
    WHEN (SELECT value FROM v$sysstat WHERE name = 'session cursor cache hits') * 100 /
         NULLIF((SELECT value FROM v$sysstat WHERE name = 'parse count (total)'), 0) < 30
        THEN 'WARNING: < 30%, augmenter session_cached_cursors'
    WHEN (SELECT value FROM v$sysstat WHERE name = 'session cursor cache hits') * 100 /
         NULLIF((SELECT value FROM v$sysstat WHERE name = 'parse count (total)'), 0) < 60
        THEN 'NOTICE: cache hit modéré (30-60 %)'
    ELSE 'OK'
  END                                                                                       AS verdict
FROM dual
UNION ALL
SELECT
  'open_cursors',
  TO_CHAR((SELECT value FROM v$parameter WHERE name = 'open_cursors')),
  TO_CHAR((SELECT value FROM v$sysstat   WHERE name = 'opened cursors cumulative')),
  '(cumulative)',
  '',
  ''
FROM dual
;
