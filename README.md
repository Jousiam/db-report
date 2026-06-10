# DB Report v2.9 — version Bash

Version Bash + sqlplus de DB Report v2.9 (il existe aussi une implémentation Python). Produit
exactement le même rapport HTML modernisé, sans aucune dépendance hors de
`bash`, `sqlplus` et les outils Unix standards.

## Quand utiliser cette version vs la Python

| Tu veux… | Choisis |
|---|---|
| Un rapport HTML moderne, c'est tout | **Bash** (cette version) |
| Ingérer les résultats dans DB Report ou un autre outil (JSON) | Python |
| Aucune installation possible sur le serveur DBA | **Bash** |
| Tu maintiens un parc de bases hétérogènes et tu veux du code lisible par tous les DBA | **Bash** |
| Tu veux ajouter des règles de diagnostic complexes (corrélations entre sections, scoring) | Python |

Les deux versions utilisent les **mêmes 7 requêtes SQL** (à la virgule près) et
le **même CSS/JS embarqués** dans la sortie. Le rapport généré est identique
visuellement.

## Prérequis

- Bash 4+ (toutes distros Linux récentes)
- Oracle Database avec `sqlplus` dans le PATH
- Connexion SYSDBA possible localement (`/ as sysdba`)
- `pgrep` (dans `procps-ng`, présent par défaut)

Aucun `pip`, aucun `apt`, aucun `yum`. C'est le point.

## Installation

```bash
git clone <ce-repo>
cd db-report-v2.9
chmod +x oracle_db_report.sh
```

## Usage

```bash
# Détecte les bases sur l'hôte et produit un rapport par instance
./oracle_db_report.sh

# Cible une SID précise
./oracle_db_report.sh --sid PROD

# Change le dossier de sortie
./oracle_db_report.sh --output-dir /var/audit/output
```

Le rapport sort dans `output/YYYYMMDD/Rapport_<sid>_<timestamp>.html`.

## Structure

```
db-report-v2.9/
├── oracle_db_report.sh         # Orchestrateur (équivalent de la version d'origine mais propre)
├── lib/
│   ├── utils.sh                # Logging, html_escape, slugify
│   ├── detect.sh               # pgrep + fallback /etc/oratab
│   └── render.sh               # Wrappers HTML pour les sections
├── sql/
│   ├── header.sql              # SET MARKUP HTML ON + autres directives sqlplus
│   └── database/               # Les 7 requêtes améliorées (mêmes que Python)
│       ├── 01_system_info.sql
│       ├── 02_memory_coherence.sql    [NOUVEAU vs version d'origine]
│       ├── 03_pga_advice.sql          [NOUVEAU]
│       ├── 04_shared_pool_health.sql  [NOUVEAU]
│       ├── 05_buffer_cache_advice.sql [NOUVEAU]
│       ├── 06_alert_log_errors.sql    [AMÉLIORÉ]
│       └── 07_top_wait_events.sql     [NOUVEAU]
└── templates/
    ├── style.css               # Le CSS moderne (theme picker compris)
    └── script.js               # Le JS (copy buttons, search, theme, etc.)
```

## Différences techniques avec la version d'origine `Yacine31/db_report`

1. **`set -euo pipefail` ciblé** : on l'active globalement mais on relâche
   localement autour de chaque `sqlplus` pour qu'une requête en erreur
   n'arrête pas tout le rapport.
2. **Détection via `pgrep`** (avec fallback `/etc/oratab`) plutôt que
   `ps -eaf | grep pmon | egrep -v 'grep|ASM|APX1' | cut -d _ -f3`.
3. **HTML semantique** : la version d'origine concatène des chaînes ; ici chaque
   section est un vrai `<section>` avec un id, un titre, et le contenu
   sqlplus encapsulé.
4. **Format de date ISO 8601** dans toutes les requêtes (la version d'origine a un
   `DD-MM-YYYY HH-MI-SS` ambigu, voir `docs/IMPROVEMENTS.md`).
5. **Sortie HTML moderne** : sommaire latéral, copie de section vers Word,
   theme picker, filtre de recherche, bouton retour en haut. Le d'origine
   produit du HTML 2010 strict avec `<tr:hover>`.

## Pour porter les autres requêtes de la version d'origine

Le repo `Yacine31/db_report` contient ~35 SQL files que je n'ai pas portés.
Procédure d'ajout :

1. Récupère le SQL d'origine depuis `https://github.com/Yacine31/db_report/blob/main/sql/`
2. Nettoie les directives SQL*Plus inutiles (`COL`, `BREAK`, etc. — celles
   qu'on déclare déjà dans `sql/header.sql`)
3. Ajoute en première ligne : `-- TITLE: Description de la section`
4. Garde le `;` à la fin
5. Sauve dans `sql/database/NN_nom.sql` avec un préfixe numérique pour
   l'ordre

L'orchestrateur prendra automatiquement le fichier au prochain lancement.
