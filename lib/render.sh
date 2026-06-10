#!/bin/bash
# Helpers pour assembler le HTML moderne section par section.
# Utilise un TOC accumulateur dans un fichier temporaire pour pouvoir
# l'injecter au début après avoir parcouru tous les fichiers SQL.

# Variables remplies par le caller :
#   $HTML_FILE       : le fichier HTML final (en cours de construction)
#   $TOC_FILE        : fichier temporaire qui accumule les liens du sommaire
#   $CURRENT_GROUP   : titre du groupe H1 en cours
#   $TEMPLATES_DIR   : chemin vers templates/ (style.css, script.js)

# --- TOC -------------------------------------------------------------------
# toc_start_group <title> [sid]
# Si sid est fourni, le groupe est marqué pour filtrage onglet (toc-db-group).
toc_start_group() {
    local title="$1"
    local sid="${2:-}"
    local class_attr="toc-group"
    local sid_attr=""
    if [ -n "$sid" ]; then
        class_attr="toc-group toc-db-group"
        sid_attr=" data-sid=\"${sid}\""
    fi
    {
        printf '          <div class="%s"%s>\n' "$class_attr" "$sid_attr"
        echo "            <div class=\"toc-group-title\">$(printf '%s' "$title" | html_escape)</div>"
        echo '            <ul class="toc-list">'
    } >> "$TOC_FILE"
}

toc_add_link() {
    local title="$1" slug="$2"
    echo "              <li><a class=\"toc-link\" href=\"#${slug}\">$(printf '%s' "$title" | html_escape)</a></li>" >> "$TOC_FILE"
}

toc_end_group() {
    {
        echo '            </ul>'
        echo '          </div>'
    } >> "$TOC_FILE"
}

# --- Section open/close ---------------------------------------------------
# write_group_header <title> <count> [sid]
write_group_header() {
    local title="$1" count="$2"
    local sid="${3:-}"
    local slug
    slug=$(slugify "$title")
    local esc
    esc=$(printf '%s' "$title" | html_escape)
    local class_attr="group reveal"
    local sid_attr=""
    if [ -n "$sid" ]; then
        class_attr="group db-group reveal"
        sid_attr=" data-sid=\"${sid}\""
    fi
    cat >> "$HTML_FILE" <<EOF
        <div class="${class_attr}" id="${slug}"${sid_attr}>
          <h2 class="group-title">${esc}<span class="group-count">${count} sections</span></h2>
EOF
}

# write_db_tabs <sid1> <sid2> ...
# Émet une barre d'onglets pour la sélection inter-bases.
write_db_tabs() {
    cat >> "$HTML_FILE" <<EOF
        <div class="db-tabs reveal" role="tablist" aria-label="Sélection de base de données">
          <span class="db-tabs-label">Base sélectionnée</span>
EOF
    for sid in "$@"; do
        local esc
        esc=$(printf '%s' "$sid" | html_escape)
        printf '          <button type="button" class="db-tab" data-sid="%s">%s</button>\n' "$esc" "$esc" >> "$HTML_FILE"
    done
    echo '        </div>' >> "$HTML_FILE"
}

write_group_footer() {
    echo '        </div>' >> "$HTML_FILE"
}

write_section_open() {
    local title="$1" slug="$2"
    local esc
    esc=$(printf '%s' "$title" | html_escape)
    cat >> "$HTML_FILE" <<EOF
          <section class="section reveal" id="${slug}">
            <header class="section-header" onclick="toggleSection('${slug}')">
              <h3 class="section-title">${esc}</h3>
              <div class="section-actions" onclick="event.stopPropagation()">
                <button class="btn" onclick="copySection('${slug}', this)" title="Copier pour collage Word">
                  <svg class="ico" viewBox="0 0 24 24"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                  Copier
                </button>
                <button class="btn" onclick="toggleSection('${slug}')" title="Replier/déplier">
                  <svg class="ico" viewBox="0 0 24 24"><polyline points="6 9 12 15 18 9"/></svg>
                </button>
              </div>
            </header>
            <div class="section-body">
EOF
}

write_section_close() {
    cat >> "$HTML_FILE" <<'EOF'
            </div>
          </section>
EOF
}

# --- Document skeleton ----------------------------------------------------
# write_html_header <title> <meta_html>
write_html_header() {
    local report_title="$1" meta_html="$2"
    local esc_title
    esc_title=$(printf '%s' "$report_title" | html_escape)
    {
        echo '<!doctype html>'
        echo '<html lang="fr">'
        echo '<head>'
        echo '<meta charset="utf-8">'
        echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
        echo "<title>${esc_title}</title>"
        echo '<style>'
        cat "${TEMPLATES_DIR}/style.css"
        echo '</style>'
        echo '</head>'
        echo '<body>'
        echo '<div class="layout">'
        echo '  <aside class="toc">'
        echo '    <div class="toc-brand">Audit <span class="accent">Oracle</span></div>'
        echo '    <div class="toc-sub">DB Report v2.9</div>'
        echo '    <input type="text" id="toc-search" class="toc-search" placeholder="Rechercher (Ctrl+K)…" autocomplete="off">'
        echo '    <div class="theme-picker" role="group" aria-label="Couleur d'\''accent">'
        echo '      <span class="theme-label">Couleur d'\''accent</span>'
        echo '      <button type="button" class="theme-swatch" data-color="#B85C2A" style="background:#B85C2A" title="Terracotta"></button>'
        echo '      <button type="button" class="theme-swatch" data-color="#0F4C81" style="background:#0F4C81" title="Bleu encre"></button>'
        echo '      <button type="button" class="theme-swatch" data-color="#3F6E3F" style="background:#3F6E3F" title="Sauge"></button>'
        echo '      <button type="button" class="theme-swatch" data-color="#7E1F47" style="background:#7E1F47" title="Bordeaux"></button>'
        echo '      <button type="button" class="theme-swatch" data-color="#5C4F35" style="background:#5C4F35" title="Bronze"></button>'
        echo '      <label class="theme-custom" title="Couleur personnalisée">'
        echo '        <input type="color" id="theme-custom-input" value="#B85C2A">'
        echo '      </label>'
        echo '    </div>'
        # TOC placeholder marker — replaced after all sections are written
        echo '<!-- TOC_PLACEHOLDER -->'
        echo '  </aside>'
        echo '  <main>'
        echo '    <header class="report-header">'
        echo '      <div class="report-eyebrow">Audit de base de données</div>'
        echo "      <h1 class=\"report-title\">${esc_title}</h1>"
        echo "      <div class=\"report-meta\">${meta_html}</div>"
        echo '      <div class="top-actions" style="margin-top:1.5rem;">'
        echo '        <button class="btn" onclick="expandAll()">Tout déplier</button>'
        echo '        <button class="btn" onclick="collapseAll()">Tout replier</button>'
        echo '      </div>'
        echo '    </header>'
    } >> "$HTML_FILE"
}

# write_html_footer
write_html_footer() {
    {
        echo '  </main>'
        echo '</div>'
        echo '<div class="toast" id="toast"></div>'
        echo '<button class="back-to-top" id="back-to-top" type="button" onclick="window.scrollTo({top:0, behavior:'\''smooth'\''})" title="Retour en haut" aria-label="Retour en haut">'
        echo '  <svg viewBox="0 0 24 24"><polyline points="18 15 12 9 6 15"/></svg>'
        echo '</button>'
        echo '<script>'
        cat "${TEMPLATES_DIR}/script.js"
        echo '</script>'
        echo '</body>'
        echo '</html>'
    } >> "$HTML_FILE"
}

# Injecte le TOC accumulé à la place du placeholder.
# Utilise sed sur place (in-place édition).
finalize_toc() {
    if [ ! -f "$TOC_FILE" ]; then return; fi
    # Échappement : / et & dans le contenu TOC posent problème à sed.
    # Solution : utiliser python pour un remplacement string-safe si dispo,
    # sinon awk avec un séparateur exotique.
    local tmp="${HTML_FILE}.tmp"
    awk -v tocfile="$TOC_FILE" '
        /<!-- TOC_PLACEHOLDER -->/ {
            while ((getline line < tocfile) > 0) print line
            close(tocfile)
            next
        }
        { print }
    ' "$HTML_FILE" > "$tmp" && mv "$tmp" "$HTML_FILE"
}
