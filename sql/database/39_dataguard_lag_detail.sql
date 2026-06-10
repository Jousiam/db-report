-- TITLE: Data Guard — apply lag et processes (si configure)
-- Ne sort de donnees que si la base a un role STANDBY ou si v$dataguard_stats
-- est peuplee. Sinon une ligne info indique "non applicable".
-- NB : v$dataguard_stats.value est une chaine d'intervalle "+DD HH:MI:SS"
-- (ex "+00 00:01:30"). On NE tente PAS de la convertir en nombre (fragile) :
-- on detecte simplement si l'intervalle est non nul, et le DBA lit la valeur
-- exacte dans la colonne VALUE.
COLUMN metric  FORMAT a22
COLUMN value   FORMAT a22
COLUMN unit    FORMAT a14
COLUMN verdict FORMAT a60
SELECT *
FROM (
  -- Cas 1 : pas de DG -> une ligne info
  SELECT
    'Statut'                                                AS metric,
    'NOT_CONFIGURED'                                        AS value,
    NULL                                                    AS unit,
    'OK: pas de Data Guard sur cette base'                  AS verdict
  FROM dual
  WHERE (SELECT database_role FROM v$database) = 'PRIMARY'
    AND (SELECT dataguard_broker FROM v$database) = 'DISABLED'
    AND NOT EXISTS (SELECT 1 FROM v$dataguard_stats)
  UNION ALL
  -- Cas 2 : DG actif -> metriques de lag (verdict base sur intervalle non nul)
  SELECT
    name                                                    AS metric,
    value                                                   AS value,
    unit                                                    AS unit,
    CASE
      WHEN name = 'apply lag'
           AND value IS NOT NULL
           AND value NOT LIKE '+00 00:00:00%'               THEN 'WARNING: apply lag non nul — voir valeur'
      WHEN name = 'transport lag'
           AND value IS NOT NULL
           AND value NOT LIKE '+00 00:00:00%'               THEN 'WARNING: transport lag non nul — voir valeur'
      ELSE 'OK'
    END                                                     AS verdict
  FROM v$dataguard_stats
  UNION ALL
  -- Cas 3 : processus de standby (MRP, RFS, LNS)
  SELECT
    'process: ' || process                                  AS metric,
    status                                                  AS value,
    'seq=' || TO_CHAR(sequence#)                            AS unit,
    CASE
      WHEN status = 'ERROR'                                 THEN 'CRITICAL: process en ERROR'
      WHEN status IN ('CONNECTED','ATTACHED','APPLYING_LOG','RECEIVING','WAIT_FOR_LOG','IDLE','CLOSING') THEN 'OK'
      WHEN status = 'WAIT_FOR_GAP'                          THEN 'WARNING: en attente d''un gap — voir section archive gap'
      ELSE 'NOTICE: status = ' || status
    END                                                     AS verdict
  FROM v$managed_standby
  WHERE process IN ('MRP0','LSP0','RFS','LNS')
)
;
