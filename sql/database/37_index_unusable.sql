-- TITLE: Index UNUSABLE — detection + verdict rebuild
-- Un index UNUSABLE n'est plus maintenu par Oracle. Toute requete qui l'aurait
-- utilise tombe en full scan. Diagnostic ET fix sont identiques : ALTER INDEX
-- ... REBUILD ONLINE.
SELECT
  i.owner,
  i.index_name,
  i.table_owner,
  i.table_name,
  i.index_type,
  i.uniqueness,
  i.partitioned,
  i.status,
  CASE
    WHEN i.owner IN ('SYS','SYSTEM')
         AND i.status = 'UNUSABLE'           THEN 'CRITICAL: index systeme UNUSABLE — rebuild URGENT'
    WHEN i.status = 'UNUSABLE'               THEN 'WARNING: rebuild requis (ALTER INDEX ' || i.owner || '.' || i.index_name || ' REBUILD ONLINE;)'
    WHEN i.status = 'INVALID'                THEN 'WARNING: index INVALID — investigation'
    WHEN i.status = 'N/A' AND i.partitioned = 'YES' THEN 'NOTICE: index partitionne — voir DBA_IND_PARTITIONS'
    ELSE 'OK'
  END                                         AS verdict
FROM dba_indexes i
WHERE i.status NOT IN ('VALID','N/A')
   OR (i.partitioned = 'YES'
       AND EXISTS (SELECT 1 FROM dba_ind_partitions p
                   WHERE p.index_owner = i.owner
                     AND p.index_name = i.index_name
                     AND p.status = 'UNUSABLE'))
ORDER BY (CASE WHEN i.owner IN ('SYS','SYSTEM') THEN 0 ELSE 1 END), i.owner, i.index_name
FETCH FIRST 50 ROWS ONLY
;
