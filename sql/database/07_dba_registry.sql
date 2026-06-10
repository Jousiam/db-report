-- TITLE: Fonctionnalités installées (DBA_REGISTRY)
-- FIX vs version précédente : la colonne MODIFIED de DBA_REGISTRY est un
-- VARCHAR2(30) (chaîne déjà formatée par Oracle), pas un DATE/TIMESTAMP.
-- Le TO_CHAR provoquait ORA-01722.
SELECT
  comp_id,
  comp_name,
  version,
  status,
  modified,
  schema,
  procedure                                     AS validation_proc
FROM dba_registry
ORDER BY status, comp_name
;
