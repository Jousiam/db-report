-- TITLE: Shared pool — santé sur trois angles
-- NOUVEAU vs version d'origine : combine free memory %, library cache pinhit ratio et
-- soft parse % en un seul tableau de verdicts. Aucun seul angle ne suffit.
WITH sp_total AS (
  SELECT SUM(bytes) AS total_bytes
  FROM v$sgastat
  WHERE pool = 'shared pool'
),
sp_free AS (
  SELECT bytes AS free_bytes
  FROM v$sgastat
  WHERE pool = 'shared pool' AND name = 'free memory'
),
parses AS (
  SELECT
    (SELECT value FROM v$sysstat WHERE name = 'parse count (total)') AS tot,
    (SELECT value FROM v$sysstat WHERE name = 'parse count (hard)')  AS hard
  FROM dual
)
-- Angle 1 : free memory
SELECT
  'Shared pool free %'                                                AS metric,
  TO_CHAR(ROUND(sp_free.free_bytes / sp_total.total_bytes * 100, 1)) || ' %' AS value,
  TO_CHAR(ROUND(sp_total.total_bytes / 1024/1024)) || ' MB total'     AS detail,
  CASE
    WHEN sp_free.free_bytes / sp_total.total_bytes > 0.25
      THEN 'OVERSIZED: > 25% libre, possible de reduire le pool'
    WHEN sp_free.free_bytes / sp_total.total_bytes < 0.05
      THEN 'CRITICAL: < 5% libre, risque ORA-04031'
    WHEN sp_free.free_bytes / sp_total.total_bytes < 0.10
      THEN 'WARNING: < 10% libre, surveiller'
    ELSE 'OK: 10-25% libre'
  END                                                                 AS verdict
FROM sp_total, sp_free
-- Angle 2 : library cache pinhit ratio
UNION ALL
SELECT
  'Library cache ' || namespace                                       AS metric,
  TO_CHAR(ROUND(pinhitratio * 100, 2)) || ' %'                        AS value,
  'reloads=' || TO_CHAR(reloads) || ', invalidations=' || TO_CHAR(invalidations) AS detail,
  CASE
    WHEN pinhitratio < 0.90 OR reloads > 10000
      THEN 'BAD: parsing pressure'
    WHEN pinhitratio < 0.95
      THEN 'WARNING'
    ELSE 'OK'
  END                                                                 AS verdict
FROM v$librarycache
WHERE namespace IN ('SQL AREA', 'BODY', 'TABLE/PROCEDURE', 'TRIGGER')
-- Angle 3 : soft parse %
UNION ALL
SELECT
  'Soft parse %'                                                      AS metric,
  TO_CHAR(ROUND((1 - hard / NULLIF(tot, 0)) * 100, 2)) || ' %'        AS value,
  'total=' || TO_CHAR(tot) || ', hard=' || TO_CHAR(hard)              AS detail,
  CASE
    WHEN (1 - hard / NULLIF(tot, 0)) < 0.90
      THEN 'BAD: bind variables manquantes cote appli'
    WHEN (1 - hard / NULLIF(tot, 0)) < 0.95
      THEN 'WARNING'
    ELSE 'OK'
  END                                                                 AS verdict
FROM parses
;
