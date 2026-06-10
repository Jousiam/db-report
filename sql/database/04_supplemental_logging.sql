-- TITLE: Mode de la base (journalisation, role, protection)
-- COLUMN forcees pour eviter que sqlplus coupe les en-tetes en rabotant la
-- colonne a la largeur de la donnee (YES/NO).
COLUMN log_mode          FORMAT a14
COLUMN open_mode         FORMAT a12
COLUMN database_role     FORMAT a16
COLUMN flashback_on      FORMAT a13
COLUMN force_logging     FORMAT a14
COLUMN supplemental_log  FORMAT a18
COLUMN protection_mode   FORMAT a20
COLUMN verdict           FORMAT a80
SELECT
  log_mode,
  open_mode,
  database_role,
  flashback_on,
  force_logging,
  -- Supplemental logging consolide en UNE colonne lisible (au lieu de 3
  -- colonnes min/pk/all que sqlplus rabotait en "SUPP_LOG" / "SUP" / "SUP").
  CASE
    WHEN supplemental_log_data_all = 'YES' THEN 'ALL'
    WHEN supplemental_log_data_min = 'YES'
      OR supplemental_log_data_pk  = 'YES'
      OR supplemental_log_data_ui  = 'YES'
      OR supplemental_log_data_fk  = 'YES' THEN 'PARTIEL'
    WHEN supplemental_log_data_min = 'IMPLICIT' THEN 'IMPLICITE'
    ELSE 'AUCUN'
  END                                                   AS supplemental_log,
  protection_mode,
  CASE
    WHEN log_mode = 'NOARCHIVELOG'                                  THEN 'CRITICAL: NOARCHIVELOG — PITR impossible, perte de donnees garantie'
    WHEN open_mode NOT IN ('READ WRITE','READ ONLY','MOUNTED')      THEN 'WARNING: open_mode anormal'
    WHEN database_role = 'PRIMARY' AND force_logging = 'NO'         THEN 'WARNING: FORCE LOGGING desactive sur primaire (DG peut perdre des changements)'
    WHEN database_role = 'PRIMARY' AND flashback_on = 'NO'          THEN 'NOTICE: FLASHBACK off — pas de retour rapide possible'
    ELSE 'OK'
  END                                                   AS verdict
FROM v$database
;
