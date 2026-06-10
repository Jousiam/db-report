# Schéma JSON de collecte DB Report

Contrat entre la **collecte** (bash, côté client) et la **génération** (Python, côté DB Report).

Le bash produit un seul fichier JSON par audit. Ce JSON est auto-suffisant : il
contient toutes les données nécessaires à la génération HTML *et* Word, sans
nouvel accès à la base.

## Structure générale

```json
{
  "schema_version": "1.0",
  "report": {
    "client_name": "NOM CLIENT",
    "title": "Rapport Mensuel des Bases de Données",
    "subtitle": "Oracle 19c / OEL",
    "generated_at": "2026-05-20T16:33:00",
    "version": "1.0",
    "author": "Prénom NOM"
  },
  "synthesis": {
    "context": "Ceci est le compte rendu...",
    "scope": [
      {"server": "hostprd01", "base": "APPPROD", "status": "OPEN", "remark": "Single Instance, Noarchivelog"}
    ],
    "highlights": [
      {"scope": "global", "text": "Il faudra prévoir une date pour..."},
      {"scope": "APPPROD", "text": "Alertes toujours présentes malgré..."}
    ]
  },
  "hosts": [
    {
      "hostname": "hostprd01",
      "system_sections": [
        {
          "id": "hostname",
          "title": "Hostname",
          "type": "preformatted",
          "content": "hostprd01"
        },
        {
          "id": "cpu",
          "title": "CPU",
          "type": "preformatted",
          "content": "Architecture: x86_64\n..."
        }
      ],
      "databases": [
        {
          "sid": "APPPROD",
          "sections": [
            {
              "id": "oracle_home",
              "title": "Oracle Home et niveau de patch",
              "type": "preformatted",
              "content": "ORACLE_HOME=/u01/...\nOPatch succeeded.",
              "note": "",
              "verdict": null
            },
            {
              "id": "db_characteristics",
              "title": "Résumé des caractéristiques de la base",
              "type": "table",
              "columns": ["SYSTEM_ITEM", "SYSTEM_VALUE"],
              "rows": [
                ["Database name", "APPPROD"],
                ["Database size", "208.221 GB"]
              ],
              "note": "Taille précédente : 197.206 GB",
              "verdict": null
            },
            {
              "id": "tablespaces",
              "title": "État d'occupation des tablespaces",
              "type": "table",
              "columns": ["TABLESPACE", "USED_PCT", "VERDICT"],
              "rows": [
                ["SYSAUX", "73.2", "OK"],
                ["USERS", "96.1", "CRITICAL: > 95% of max"]
              ],
              "verdict_column": 2,
              "note": ""
            }
          ]
        }
      ]
    }
  ]
}
```

## `system_sections` vs `system` (rétrocompatibilité)

Le format recommandé est **`system_sections`** : une liste ordonnée de sections
génériques (même schéma que les sections de base). Le générateur les rend une à
une sous un titre « Configuration système », dans l'ordre fourni. C'est le
format produit par le bridge `html_to_json.py` à partir du HTML.

L'ancien format **`system`** (dict à clés figées `instances`/`listeners`/
`disk_usage`/`storage_disks`) reste supporté en fallback pour compatibilité,
mais n'est plus le format cible.

## Types de section

| `type` | Rendu | Champs requis |
|--------|-------|---------------|
| `preformatted` | Bloc monospace encadré (sortie shell/sqlplus brute) | `content` |
| `table` | Tableau avec en-tête | `columns`, `rows` |
| `text` | Paragraphe(s) de prose | `content` |
| `keyvalue` | Tableau 2 colonnes label/valeur | `rows` (paires) |

## Verdicts

Si une section `table` contient une colonne de verdict, indiquer son index
0-based dans `verdict_column`. Le générateur colore alors la cellule :

- `OK`, `INFO`, vide → vert clair
- `NOTICE` → bleu clair
- `WARNING`, `LICENSE` → orange clair
- `CRITICAL`, `FAILED`, `ERROR` → rouge clair

La détection est faite sur le **préfixe** du texte de la cellule (avant `:`).

## Champ `note`

Texte libre du DBA ajouté sous la section (commentaire d'analyse). Vide par
défaut. C'est l'équivalent des annotations manuelles dans le rapport d'origine
(« Erreurs connues et acceptées », « Base à passer en enterprise edition »).

## Multi-host / multi-base

`hosts[]` peut contenir plusieurs serveurs, chacun avec un bloc
`system_sections[]` (rendu une fois) et un tableau `databases[]`. Le générateur
produit :

```
Sommaire
─ Serveur hostprd01
   ├─ Configuration système (Hostname, CPU, Mémoire, Stockage...)
   ├─ Base APPPROD  (N sections)
   └─ Base APPPPRD (N sections)
─ Serveur hostpprd01
   └─ ...
```

## Anonymisation

Le bash applique l'anonymisation SHA-256 (mode full/partial/none) AVANT
d'écrire le JSON, donc le JSON transféré vers DB Report est déjà conforme RGPD.
Les `client_name`, `hostname`, `sid` peuvent être pseudonymisés à la source.
