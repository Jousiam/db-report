-- TIMEOUT: 30
-- TITLE: Statut des auto-tasks Oracle (fenêtre de maintenance)
-- SIMPLIFIÉ : ne lit que client_name + status. Les colonnes consumer_group /
-- window_group / service_name / attributes provoquaient des jointures internes
-- avec des tables stockées en SYSAUX. Sur une CDB avec SYSAUX saturée (cf.
-- ORA-01654 sur I_STATS_TARGET1), ces jointures pouvaient timeout à 120s.
SELECT
  client_name,
  status,
  attributes
FROM dba_autotask_client
ORDER BY client_name
;
