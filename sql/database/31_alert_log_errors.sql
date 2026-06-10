-- TITLE: Erreurs ORA-* sur les 30 derniers jours (alert log) — classifies par criticite
SELECT *
FROM (
  SELECT
    TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS')   AS event_at,
    SUBSTR(message_text, 1, 200)                              AS error_message,
    CASE
      WHEN message_text LIKE '%ORA-600%'
        OR message_text LIKE '%ORA-7445%'                      THEN 'CRITICAL: erreur interne Oracle — ouvrir SR'
      WHEN message_text LIKE '%ORA-1578%'                      THEN 'CRITICAL: corruption bloc detectee'
      WHEN message_text LIKE '%ORA-19815%'
        OR message_text LIKE '%ORA-19809%'                     THEN 'CRITICAL: FRA saturee — archivage bloque imminent'
      WHEN message_text LIKE '%ORA-1652%'                      THEN 'WARNING: TEMP plein'
      WHEN message_text LIKE '%ORA-1653%'                      THEN 'WARNING: extension data segment impossible'
      WHEN message_text LIKE '%ORA-1654%'                      THEN 'WARNING: extension index impossible'
      WHEN message_text LIKE '%ORA-1655%'                      THEN 'WARNING: extension cluster impossible'
      WHEN message_text LIKE '%ORA-1555%'                      THEN 'NOTICE: snapshot too old — undo insuffisant'
      WHEN message_text LIKE '%ORA-12751%'                     THEN 'NOTICE: CPU time limit exceeded'
      WHEN message_text LIKE '%ORA-1109%'                      THEN 'NOTICE: database not open (operation pendant arret)'
      WHEN message_text LIKE '%ORA-3137%'
        OR message_text LIKE '%ORA-3113%'
        OR message_text LIKE '%ORA-3114%'                      THEN 'NOTICE: deconnexion brutale client'
      ELSE 'NOTICE'
    END                                                         AS verdict
  FROM v$diag_alert_ext
  WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '30' DAY
    AND message_text LIKE '%ORA-%'
  ORDER BY originating_timestamp DESC
)
WHERE ROWNUM <= 100
;
