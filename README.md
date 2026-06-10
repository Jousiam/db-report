# DB Report v2.9

Générateur de rapport d'audit pour bases de données **Oracle**. Collecte côté
client en **Bash + sqlplus** (zéro dépendance), produit un **rapport HTML
moderne** auto-suffisant, et permet une génération **Word (.docx)** optionnelle
côté serveur.

Inspiré du projet open-source [`Yacine31/db_report`](https://github.com/Yacine31/db_report),
réécrit avec une couverture d'audit étendue (40 sections), des verdicts
automatiques, et une sortie HTML repensée.

---

## Points clés

- **40 requêtes d'audit** couvrant identité, mémoire, stockage, sauvegarde,
  sécurité, sessions, maintenance, diagnostic profond et réplication.
- **Verdicts automatiques** sur 4 niveaux (`OK` / `NOTICE` / `WARNING` /
  `CRITICAL`) calculés à partir de seuils DBA standard, colorés dans le rapport.
- **Zéro dépendance côté client** : seulement `bash`, `sqlplus` et les outils
  Unix de base. Aucun `pip`, `apt` ou `yum`.
- **Rapport HTML moderne** : sommaire latéral, recherche, sélecteur de thème,
  multi-bases en onglets, et **copie de section vers Word** (avec transposition
  automatique des tableaux larges pour rester lisibles).
- **Pipeline Word optionnel** (côté serveur, via `python-docx`) à partir d'un
  JSON de collecte.

---

## Prérequis

**Côté client (collecte) :**
- Bash 4+ (toutes distributions Linux récentes)
- Oracle Database avec `sqlplus` dans le `PATH`
- Connexion SYSDBA locale possible (`/ as sysdba`)
- `pgrep` (paquet `procps-ng`, présent par défaut)

**Côté serveur (génération Word, optionnel) :**
- Python 3.10+
- `pip install python-docx`

---

## Installation

```bash
git clone https://github.com/Jousiam/db-report.git
cd db-report
chmod +x oracle_db_report.sh generate_word.sh
```

---

## Usage

### Rapport HTML

```bash
# Détecte toutes les bases de l'hôte et produit un rapport combiné
./oracle_db_report.sh

# Cibler une instance précise
./oracle_db_report.sh --sid PROD

# Changer le dossier de sortie
./oracle_db_report.sh --output-dir /var/audit/output

# Options utiles
./oracle_db_report.sh --query-timeout 180   # timeout par requête (défaut 120s)
./oracle_db_report.sh --verbose             # logs détaillés
```

Sortie : `output/AAAAMMJJ/Rapport_<hôte>_<sid|multi-Ndb>_<horodatage>.html`.

En présence de plusieurs instances, un seul HTML est produit avec un sélecteur
d'onglets par base et une section « Configuration système » partagée.

### Rapport Word (optionnel)

À lancer côté serveur, à partir d'un rapport HTML déjà produit :

```bash
./generate_word.sh rapport.html rapport.docx --client ACME --logo logo.png
```

Voir [`docs/WORD_PIPELINE.md`](docs/WORD_PIPELINE.md) pour le détail et
l'enrichissement (synthèse, notes DBA, diffusion).

---

## Les 40 sections d'audit

| Catégorie | Sections |
|-----------|----------|
| **Identité & configuration** | 01 système, 02 taille base, 03 statut instance, 04 mode de la base, 05 paramètres init, 06 NLS, 07 DBA_REGISTRY, 08 resource limits |
| **Diagnostics mémoire** | 09 cohérence SGA+PGA vs RAM, 10 PGA advisor, 11 shared pool (3 angles), 12 buffer cache (knee), 13 historique resize |
| **Stockage** | 14 tablespaces, 15 datafiles, 16 redo logs, 17 bascules redo |
| **Recovery / Backup** | 18 FRA, 19 config RMAN, 20 backups RMAN |
| **Sécurité / Schémas** | 21 SYSAUX occupants, 22 utilisateurs, 23 profiles, 24 taille objets par schéma |
| **Sessions & activité** | 25 sessions actives, 26 cursors usage |
| **Maintenance** | 27 auto-tasks, 28 jobs en échec, 29 objets invalides, 30 feature usage (licences) |
| **Diagnostic profond** | 31 erreurs alert log, 32 top wait events, 33 chaînes de blocage, 34 destinations d'archivage, 35 sessions longues, 36 top SQL, 37 index UNUSABLE |
| **Réplication / HA** | 38 synthèse réplication, 39 Data Guard apply lag, 40 Data Guard archive gap |

La synthèse réplication (38) détecte automatiquement Data Guard, Dbvisit,
GoldenGate et Streams, et indique pour chacun `NOT_CONFIGURED` / `ACTIVE` /
`DEGRADED` / `ERROR`.

---

## Philosophie des verdicts

Chaque section comparant des valeurs à des seuils DBA standard produit une
colonne `VERDICT` :

| Niveau | Sens |
|--------|------|
| `OK` | valeur dans les normes |
| `NOTICE` | observation à connaître, pas d'action requise |
| `WARNING` | situation à surveiller, action recommandée |
| `CRITICAL` | action urgente, risque de panne ou de perte de données |

Les verdicts sont des **opinions outillées** : un point de départ pour le DBA,
pas une vérité absolue. Le contexte (PROD vs DEV, charge réelle, ressources
disponibles) reste toujours décisif.

---

## Structure du projet

```
db-report/
├── oracle_db_report.sh         # Orchestrateur (collecte + génération HTML)
├── generate_word.sh            # Wrapper de génération Word
├── lib/
│   ├── utils.sh                # Logging, html_escape, slugify
│   ├── detect.sh               # Détection des SID (pgrep + fallback /etc/oratab)
│   └── render.sh               # Assemblage HTML des sections
├── sql/
│   ├── header.sql              # Directives sqlplus (SET MARKUP HTML ON, etc.)
│   └── database/               # Les 40 requêtes d'audit (01-40)
├── python/
│   ├── html_to_json.py         # Bridge HTML -> JSON de collecte
│   └── word_builder.py         # Génération .docx (python-docx)
├── templates/
│   ├── style.css               # CSS du rapport HTML
│   └── script.js               # JS (copie Word, recherche, thème, verdicts)
└── docs/
    ├── COLLECT_SCHEMA.md       # Schéma JSON de collecte
    ├── IMPROVEMENTS.md         # Détail des améliorations / verdicts
    ├── MIGRATION.md            # Porter d'autres requêtes depuis le projet d'origine
    └── WORD_PIPELINE.md        # Pipeline de génération Word
```

---

## Résilience & robustesse

- **`timeout` par requête** (défaut 120 s, surchargeable via `-- TIMEOUT: N` en
  tête d'un fichier SQL) : une requête qui gèle n'arrête pas tout le rapport.
- **`NLS_LANG=AMERICAN_AMERICA.AL32UTF8`** forcé pour préserver les accents.
- **Détecteur d'erreur intelligent** : si une requête renvoie à la fois une
  erreur ORA non bloquante *et* une table, la table est affichée avec un
  avertissement plutôt que masquée.
- **Détection CDB** : passage automatique sur `CDB$ROOT` si la base est un CDB.
- **En-têtes de colonnes protégés** contre la troncature sqlplus, cellules
  nettoyées des espaces parasites.

---

## Pour ajouter d'autres requêtes

Le projet d'origine `Yacine31/db_report` contient d'autres requêtes non portées.
Procédure d'ajout dans `sql/database/` :

1. Récupérer le SQL depuis [le repo d'origine](https://github.com/Yacine31/db_report/blob/main/sql/).
2. Retirer les directives SQL*Plus déjà déclarées dans `sql/header.sql`.
3. Ajouter en première ligne : `-- TITLE: Description de la section`.
4. Conserver le `;` final.
5. Sauvegarder sous `sql/database/NN_nom.sql` (préfixe numérique = ordre).

L'orchestrateur prend automatiquement le fichier au lancement suivant.

Voir [`docs/MIGRATION.md`](docs/MIGRATION.md) pour le détail.

---

## Confidentialité

Le rapport peut contenir des noms de serveurs, de bases, de schémas et des
extraits de configuration. Avant toute diffusion hors du périmètre client,
vérifiez le contenu. Le `.gitignore` exclut par défaut les rapports générés
(`*.html`, `*.docx`, `*.pdf`, `output/`) pour éviter de committer des données
réelles par mégarde.

---

## Crédits

Dérivé de [`Yacine31/db_report`](https://github.com/Yacine31/db_report) (Yacine
Oumghar). Merci de vérifier la licence du projet d'origine avant toute
redistribution publique.
