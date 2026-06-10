# Pipeline de génération du rapport Word

## Vue d'ensemble

```
[Côté client]   oracle_db_report.sh  →  Rapport_<host>_<sids>_<ts>.html
                                              │
[Côté DB Report]    generate_word.sh  ────────────┤
                  ├─ html_to_json.py  →  collecte.json (intermédiaire)
                  └─ word_builder.py  →  Rapport.docx
```

Le HTML reste produit par le bash chez le client (zéro dépendance Python côté
client). La génération Word se fait côté DB Report avec python3 + python-docx.

## Prérequis (côté DB Report uniquement)

```bash
pip install python-docx
```

## Usage

### Le plus simple : depuis le HTML déjà produit

```bash
./generate_word.sh \
    output/AAAAMMJJ/Rapport_SRV-ORA-01_multi-4db_AAAAMMJJ-HHMM.html \
    rapport.docx \
    --client ACME \
    --logo /chemin/vers/logo_client.png
```

### En deux temps (si on veut éditer le JSON entre les deux)

```bash
# 1. HTML → JSON
python3 python/html_to_json.py rapport.html collecte.json --client ACME

# 2. (optionnel) éditer collecte.json : ajouter la synthèse, les notes DBA,
#    la diffusion, ajuster les verdicts...

# 3. JSON → Word
python3 python/word_builder.py collecte.json rapport.docx --logo logo.png
```

## Enrichir le rapport (synthèse, notes, diffusion)

Le HTML ne contient pas la synthèse manuelle ni les notes DBA. Pour un rapport
client complet, éditer le JSON intermédiaire avant de générer le Word :

```json
{
  "report": {
    "client_name": "ACME",
    "version": "1.0",
    "author": "Prénom NOM",
    "diffusion": [
      {"name": "Jean Dupont", "company": "ACME", "role": "DSI", "email": "..."}
    ]
  },
  "synthesis": {
    "context": "Compte rendu de la vérification mensuelle...",
    "scope": [
      {"server": "SRV-ORA-01", "base": "CDBPROD", "status": "OPEN", "remark": "CDB"}
    ],
    "highlights": [
      {"scope": "global", "text": "Incident FRA résolu le 21/05."},
      {"scope": "CDBPROD", "text": "Purge OPTSTAT à planifier."}
    ]
  },
  "hosts": [ ... ]   // généré par html_to_json.py
}
```

Les sections de base acceptent aussi un champ `"note"` (annotation DBA en
italique sous la section), à ajouter manuellement dans le JSON.

## Design

- Titres : bleu marine (serveur), bleu (base / sous-sections)
- Sorties shell/sqlplus : bloc monospace encadré gris
- Tableaux : en-tête bleu, lignes alternées
- Verdicts colorés automatiquement selon le préfixe :
  - OK / INFO / NOT_CONFIGURED / ACTIVE → vert
  - NOTICE → bleu
  - WARNING / LICENSE → orange
  - CRITICAL / FAILED / ERROR → rouge
- Sommaire Word natif (cliquable, se met à jour à l'ouverture)
- En-tête + pied de page (client, version, date)
