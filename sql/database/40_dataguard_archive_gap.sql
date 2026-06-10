-- TITLE: Data Guard — gaps d'archivage (uniquement si standby)
SELECT *
FROM (
  -- Cas 1 : pas de standby OU pas de gap → ligne info
  SELECT
    'Statut'                                                AS context,
    CASE
      WHEN (SELECT database_role FROM v$database) NOT LIKE '%STANDBY%'  THEN 'NOT_APPLICABLE'
      WHEN NOT EXISTS (SELECT 1 FROM v$archive_gap)                     THEN 'NO_GAP'
      ELSE 'GAP_DETECTED'
    END                                                     AS state,
    NULL                                                    AS thread_num,
    NULL                                                    AS low_seq,
    NULL                                                    AS high_seq,
    NULL                                                    AS missing,
    CASE
      WHEN (SELECT database_role FROM v$database) NOT LIKE '%STANDBY%'  THEN 'OK: pas applicable (pas un standby)'
      WHEN NOT EXISTS (SELECT 1 FROM v$archive_gap)                     THEN 'OK: aucun gap d''archivage detecte'
      ELSE 'voir lignes suivantes'
    END                                                     AS verdict
  FROM dual
  UNION ALL
  -- Cas 2 : gap(s) trouves
  SELECT
    'Gap thread ' || thread#                                AS context,
    'MISSING'                                               AS state,
    TO_CHAR(thread#)                                        AS thread_num,
    TO_CHAR(low_sequence#)                                  AS low_seq,
    TO_CHAR(high_sequence#)                                 AS high_seq,
    TO_CHAR(high_sequence# - low_sequence# + 1)             AS missing,
    CASE
      WHEN high_sequence# - low_sequence# >= 10             THEN 'CRITICAL: gap >= 10 archives'
      WHEN high_sequence# - low_sequence# >= 3              THEN 'WARNING: gap >= 3 archives'
      ELSE 'NOTICE: gap detecte'
    END                                                     AS verdict
  FROM v$archive_gap
)
;
