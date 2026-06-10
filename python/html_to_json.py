"""
Convertit un rapport HTML DB Report (multi-DB) en JSON de collecte pour word_builder.

Permet de générer le Word à partir du HTML déjà produit par la version bash,
sans réaccéder à la base. Le bash continue de produire le HTML ; ce module
extrait sa structure et la sérialise en JSON, que word_builder consomme.

Usage:
    python -m db_report.word.html_to_json rapport.html collecte.json \
        --client ACME --title "Rapport Mensuel"
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from html.parser import HTMLParser
from html import unescape


class DbReportHTMLParser(HTMLParser):
    """Extrait hosts → systeme + bases → sections depuis le HTML DB Report."""

    def __init__(self):
        super().__init__()
        self.hostname = None
        self.system_sections = []     # liste ordonnée des sections système
        self.databases = {}          # sid -> [sections]
        self._current_sid = None
        self._in_section = False
        self._section_id = None
        self._section_title = None
        self._capture_title = False
        self._capture_pre = False
        self._pre_buf = []
        self._in_table = False
        self._table_rows = []
        self._current_row = None
        self._cell_buf = None
        self._capture_cell = False
        self._group_sid = None        # data-sid courant
        self._div_depth = 0           # profondeur de div pour fermer le group
        self._group_div_depth = None  # profondeur où le db-group a ouvert
        self._capture_p = False
        self._p_buf = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = a.get("class", "")
        if tag == "div":
            self._div_depth += 1
            if "db-group" in cls:
                self._group_sid = a.get("data-sid")
                self._group_div_depth = self._div_depth
                if self._group_sid and self._group_sid not in self.databases:
                    self.databases[self._group_sid] = []
        if tag == "section" and "section" in cls:
            self._in_section = True
            self._section_id = a.get("id", "")
            self._section_title = None
            self._pre_buf = []
            self._table_rows = []
        if tag == "h3" and self._in_section:
            self._capture_title = True
        if tag == "pre" and self._in_section:
            self._capture_pre = True
            self._pre_buf = []
        if tag == "p" and self._in_section and not self._in_table:
            self._capture_p = True
            self._p_buf = []
        if tag == "table" and self._in_section:
            self._in_table = True
            self._table_rows = []
        if tag == "tr" and self._in_table:
            self._current_row = []
        if tag in ("td", "th") and self._in_table:
            self._capture_cell = True
            self._cell_buf = []

    def handle_endtag(self, tag):
        if tag == "h3" and self._capture_title:
            self._capture_title = False
        if tag == "pre" and self._capture_pre:
            self._capture_pre = False
        if tag == "p" and self._capture_p:
            self._capture_p = False
        if tag in ("td", "th") and self._capture_cell:
            self._capture_cell = False
            self._current_row.append(unescape("".join(self._cell_buf)).strip())
        if tag == "tr" and self._in_table and self._current_row is not None:
            self._table_rows.append(self._current_row)
            self._current_row = None
        if tag == "table" and self._in_table:
            self._in_table = False
        if tag == "section" and self._in_section:
            self._finalize_section()
            self._in_section = False
        if tag == "div":
            # Fermeture du db-group quand on remonte au-dessus de sa profondeur
            if self._group_div_depth is not None and self._div_depth == self._group_div_depth:
                self._group_sid = None
                self._group_div_depth = None
            self._div_depth -= 1

    def handle_data(self, data):
        if self._capture_title:
            self._section_title = (self._section_title or "") + data
        if self._capture_pre:
            self._pre_buf.append(data)
        if self._capture_p:
            self._p_buf.append(data)
        if self._capture_cell:
            self._cell_buf.append(data)

    def _finalize_section(self):
        title = (self._section_title or self._section_id or "").strip()
        section = {"id": self._section_id, "title": title}
        if self._table_rows:
            columns = self._table_rows[0]
            rows = self._table_rows[1:]
            section["type"] = "table"
            section["columns"] = columns
            section["rows"] = rows
            for idx, col in enumerate(columns):
                if col.strip().upper() in ("VERDICT", "STATUS", "STATUT"):
                    section["verdict_column"] = idx
                    break
        else:
            section["type"] = "preformatted"
            # contenu : <pre> en priorité, sinon <p>
            content = "".join(self._pre_buf).strip()
            if not content:
                content = unescape("".join(self._p_buf)).strip()
            section["content"] = content

        if self._group_sid:
            self.databases.setdefault(self._group_sid, []).append(section)
        else:
            # Section système : on garde TOUTES les sections telles quelles,
            # dans l'ordre, sans mapping rigide. Le hostname est aussi extrait
            # à part pour nommer le serveur.
            t = title.lower()
            content = section.get("content", "")
            if "hostname" in t and content.strip():
                self.hostname = content.strip().split("\n")[0] or self.hostname
            self.system_sections.append(section)


def convert(html_path: str, client: str, title: str, subtitle: str = "Oracle 19c / OEL"):
    with open(html_path, encoding="utf-8") as f:
        html = f.read()

    parser = DbReportHTMLParser()
    parser.feed(html)

    # Construire le JSON
    data = {
        "schema_version": "1.0",
        "report": {
            "client_name": client,
            "title": title,
            "subtitle": subtitle,
            "generated_at": "",
            "version": "1.0",
            "author": "",
        },
        "hosts": [
            {
                "hostname": parser.hostname or "serveur",
                "system_sections": parser.system_sections,
                "databases": [
                    {"sid": sid, "sections": sections}
                    for sid, sections in parser.databases.items()
                ],
            }
        ],
    }
    return data


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("html")
    ap.add_argument("json_out")
    ap.add_argument("--client", default="CLIENT")
    ap.add_argument("--title", default="Rapport Mensuel des Bases de Données")
    ap.add_argument("--subtitle", default="Oracle 19c / OEL")
    args = ap.parse_args(argv)

    data = convert(args.html, args.client, args.title, args.subtitle)
    with open(args.json_out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    n_db = len(data["hosts"][0]["databases"])
    print(f"JSON écrit : {args.json_out} ({n_db} base(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
