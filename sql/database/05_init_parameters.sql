-- TITLE: Paramètres d'initialisation (modifies ou critiques)
-- Affiche tous les parametres non-default + les parametres memoire/processes critiques
-- meme s'ils sont à leur valeur par défaut (utile pour audit).
-- NB : on n'affiche QUE la colonne SOURCE (default/modified). L'ancienne colonne
-- "modified_at" (issue de v$parameter.ismodified) etait redondante avec SOURCE
-- et son en-tete etait tronque en "MODIFIED_A" par sqlplus.
COLUMN name   FORMAT a32
COLUMN value  FORMAT a45
COLUMN source FORMAT a10
SELECT
  name,
  value,
  CASE isdefault WHEN 'TRUE' THEN 'default' ELSE 'modified' END  AS source,
  description
FROM v$parameter
WHERE isdefault = 'FALSE'
   OR name IN (
        'sga_max_size', 'sga_target', 'pga_aggregate_target', 'pga_aggregate_limit',
        'memory_target', 'memory_max_target',
        'db_cache_size', 'shared_pool_size', 'large_pool_size', 'java_pool_size',
        'processes', 'sessions',
        'open_cursors', 'session_cached_cursors',
        'cursor_sharing', 'optimizer_mode',
        'compatible', 'db_files',
        'undo_management', 'undo_retention'
   )
ORDER BY name
;
