-- TITLE: Profiles (limites par compte)
SELECT
  profile,
  resource_name,
  resource_type,
  limit
FROM dba_profiles
WHERE profile IN (SELECT DISTINCT profile FROM dba_users WHERE oracle_maintained = 'N')
   OR profile = 'DEFAULT'
ORDER BY profile, resource_type, resource_name
;
