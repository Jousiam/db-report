-- TITLE: Objets invalides
SELECT
  owner,
  object_type,
  COUNT(*) AS invalid_count,
  LISTAGG(object_name, ', ' ON OVERFLOW TRUNCATE)
    WITHIN GROUP (ORDER BY object_name)        AS object_names,
  CASE
    WHEN owner IN ('SYS','SYSTEM','XDB','MDSYS','CTXSYS')
         AND COUNT(*) > 0                       THEN 'CRITICAL: invalides dans schema systeme — lancer $ORACLE_HOME/rdbms/admin/utlrp.sql'
    WHEN COUNT(*) > 50                          THEN 'WARNING: > 50 invalides — recompiler le schema'
    WHEN COUNT(*) > 10                          THEN 'NOTICE: > 10 invalides'
    ELSE 'OK'
  END                                            AS verdict
FROM dba_objects
WHERE status = 'INVALID'
GROUP BY owner, object_type
ORDER BY (CASE WHEN owner IN ('SYS','SYSTEM') THEN 0 ELSE 1 END), COUNT(*) DESC
;
