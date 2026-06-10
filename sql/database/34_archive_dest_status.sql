-- TITLE: Statut des destinations d'archivage — detection FRA/dest en erreur
-- L'absence de detection sur v$archive_dest est ce qui a permis a l'incident
-- FRA pleine de degenerer en cascade de blocages. Cette section sort le
-- verdict CRITICAL des qu'une destination a un message d'erreur ou un statut
-- different de VALID.
SELECT
  dest_id,
  status,
  target,
  archiver,
  destination,
  log_sequence,
  SUBSTR(error, 1, 100)                          AS error_message,
  CASE
    WHEN status = 'VALID' AND error IS NULL      THEN 'OK'
    WHEN status = 'INACTIVE'                     THEN 'NOTICE: destination inactive'
    WHEN status = 'DEFERRED'                     THEN 'WARNING: destination differee'
    WHEN status = 'ERROR'                        THEN 'CRITICAL: destination en erreur — ' || SUBSTR(error,1,60)
    WHEN error LIKE '%ORA-19815%'                THEN 'CRITICAL: FRA saturee (ORA-19815) — agrandir db_recovery_file_dest_size'
    WHEN error LIKE '%ORA-19809%'                THEN 'CRITICAL: limite db_recovery_file_dest_size atteinte (ORA-19809)'
    WHEN error LIKE '%ORA-19504%'                THEN 'CRITICAL: filesystem destination plein (ORA-19504)'
    WHEN error IS NOT NULL                       THEN 'WARNING: ' || SUBSTR(error,1,60)
    ELSE 'OK'
  END                                            AS verdict
FROM v$archive_dest
WHERE status != 'INACTIVE' OR target != 'PRIMARY'
ORDER BY dest_id
;
