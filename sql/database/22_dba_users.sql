-- TITLE: Utilisateurs de la base (DBA_USERS)
-- oracle_maintained sert UNIQUEMENT au filtre WHERE (exclure les comptes
-- Oracle systeme). On ne l'affiche PAS en colonne : sqlplus la rabotait a la
-- largeur de la donnee (Y/N) en tronquant l'en-tete en "O", et l'info est
-- redondante (le WHERE garantit deja N, sauf pour les 3 comptes systeme inclus).
COLUMN username             FORMAT a30
COLUMN account_status       FORMAT a16
COLUMN default_tablespace   FORMAT a20
COLUMN temporary_tablespace FORMAT a20
COLUMN profile              FORMAT a20
COLUMN authentication_type  FORMAT a14
SELECT
  username,
  account_status,
  default_tablespace,
  temporary_tablespace,
  profile,
  authentication_type,
  TO_CHAR(created,       'YYYY-MM-DD HH24:MI:SS')        AS created,
  TO_CHAR(expiry_date,   'YYYY-MM-DD HH24:MI:SS')        AS expiry_date,
  TO_CHAR(last_login,    'YYYY-MM-DD HH24:MI:SS')        AS last_login
FROM dba_users
WHERE oracle_maintained = 'N'   -- Filtre les comptes Oracle systeme
   OR username IN ('SYS', 'SYSTEM', 'DBSNMP')
ORDER BY oracle_maintained, username
;
