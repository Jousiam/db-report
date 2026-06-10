// --- Verdict detection (shared by on-screen coloring AND copy-to-Word) ---
// Mappe le préfixe textuel d'un verdict vers une classe CSS.
function verdictClass(text) {
  if (text == null) return null;
  const v = text.trim();
  if (!v) return null;
  // Préfixe avant ':' (ex "CRITICAL: FRA pleine" -> "CRITICAL")
  const prefix = v.split(':')[0].trim().toUpperCase();
  const map = {
    'CRITICAL': 'v-critical', 'FAILED': 'v-critical', 'ERROR': 'v-critical',
    'WARNING': 'v-warning', 'LICENSE': 'v-license',
    'NOTICE': 'v-notice',
    'OK': 'v-ok', 'INFO': 'v-ok',
  };
  if (map[prefix]) return map[prefix];
  // Mots-clés "status" des sections réplication
  if (['ACTIVE','INSTALLED','NO_GAP','NOT_APPLICABLE','NOT_CONFIGURED'].includes(prefix))
    return 'v-ok';
  if (prefix === 'DEGRADED') return 'v-warning';
  return null;
}

// Au chargement : repère la colonne VERDICT/STATUS de chaque tableau et
// colorise les cellules + la ligne. C'est ce qui rend les verdicts visibles
// À L'ÉCRAN (le SQL ne sort que du texte brut, sans style).
function initVerdicts() {
  document.querySelectorAll('.section-body table').forEach(table => {
    // Trouver l'index de la colonne verdict via l'en-tête
    const headers = [...table.querySelectorAll('tr')].find(tr => tr.querySelector('th'));
    if (!headers) return;
    const ths = [...headers.querySelectorAll('th')];
    let vIdx = ths.findIndex(th => {
      const t = th.innerText.trim().toUpperCase();
      return t === 'VERDICT' || t === 'STATUS' || t === 'STATUT';
    });
    if (vIdx < 0) return;
    // Colorier chaque ligne de données
    table.querySelectorAll('tr').forEach(tr => {
      if (tr.querySelector('th')) return;
      const cells = tr.querySelectorAll('td');
      if (cells.length <= vIdx) return;
      const cell = cells[vIdx];
      const cls = verdictClass(cell.innerText);
      if (!cls) return;
      cell.classList.add('verdict-cell', cls);
      if (cls === 'v-critical') tr.classList.add('row-critical');
      else if (cls === 'v-warning' || cls === 'v-license') tr.classList.add('row-warning');
    });
  });
}

// --- Copy section to clipboard (rich HTML, paste into Word/Outlook) -----
async function copySection(sectionId, btn) {
  const sec = document.getElementById(sectionId);
  if (!sec) return;

  const clone = sec.cloneNode(true);
  // strip action buttons from the copy
  clone.querySelectorAll('.section-actions, .copy-shortcut').forEach(n => n.remove());
  // ensure section is "open" in the copy
  clone.classList.remove('collapsed');

  // Couleurs verdict optimisées pour Word (fond + texte lisibles à l'impression)
  const VERD = {
    'v-critical': { bg: '#F7D5C6', color: '#973018', weight: 'bold' },
    'v-warning':  { bg: '#FBEBD3', color: '#8A6516', weight: 'bold' },
    'v-license':  { bg: '#FBEBD3', color: '#8A6516', weight: 'bold' },
    'v-notice':   { bg: '#E3ECF6', color: '#2D517E', weight: '600' },
    'v-ok':       { bg: '#E7F0E0', color: '#3B5A2E', weight: '600' },
  };
  const TH_STYLE = 'background:#F0EBE0;color:#1C1916;font-weight:bold'
                 + ';padding:4pt 9pt;border:1pt solid #C9C0AE;font-size:9pt;text-align:left';
  // Style d'une cellule de données. isNum => police mono alignée à droite.
  // On N'UTILISE PAS white-space:nowrap : c'est lui qui force Word à élargir
  // puis casser les mots. Les nombres n'ont pas d'espace, ils ne wrappent pas.
  function cellStyle(bg, color, weight, isNum, isVerdict) {
    const font = (isNum && !isVerdict)
      ? "font-family:'Consolas','Courier New',monospace;font-size:9pt"
      : 'font-family:Calibri,Arial,sans-serif;font-size:9.5pt';
    return font
      + ';padding:3pt 9pt;border:1pt solid #E5DFD3;vertical-align:top'
      + ';text-align:' + (isNum && !isVerdict ? 'right' : 'left')
      + ';color:' + color + ';font-weight:' + weight + ';background:' + bg;
  }

  // Transpose un tableau "large mais court" (beaucoup de colonnes, peu de lignes)
  // en un tableau attribut/valeur lisible sur une page Word portrait.
  function buildTransposed(headers, dataRows, vIdx) {
    const wrap = document.createElement('div');
    dataRows.forEach((cells, ri) => {
      // Légende = 1re cellule (souvent un nom/SID) si plusieurs lignes
      if (dataRows.length > 1) {
        const cap = document.createElement('p');
        cap.setAttribute('style', 'font-family:Calibri,Arial,sans-serif;font-weight:bold'
          + ';font-size:10pt;color:#1C1916;margin:8pt 0 3pt');
        cap.textContent = (cells[0] || ('Ligne ' + (ri + 1)));
        wrap.appendChild(cap);
      }
      const tbl = document.createElement('table');
      tbl.setAttribute('border', '1');
      tbl.setAttribute('cellspacing', '0');
      tbl.setAttribute('cellpadding', '4');
      tbl.setAttribute('style', 'border-collapse:collapse;border:1pt solid #C9C0AE'
        + ';font-family:Calibri,Arial,sans-serif;font-size:10pt;width:100%'
        + ';mso-table-lspace:0pt;mso-table-rspace:0pt');
      headers.forEach((h, ci) => {
        const tr = document.createElement('tr');
        const th = document.createElement('td');
        th.setAttribute('style', TH_STYLE + ';width:32%;white-space:normal');
        th.textContent = h;
        const td = document.createElement('td');
        const val = cells[ci] != null ? cells[ci] : '';
        let bg = (ci % 2 === 1) ? '#FBF8F3' : '#FFFFFF', color = '#1C1916', weight = 'normal';
        const isVerdict = ci === vIdx;
        if (isVerdict) {
          const vc = verdictClass(val);
          if (vc && VERD[vc]) { bg = VERD[vc].bg; color = VERD[vc].color; weight = VERD[vc].weight; }
        }
        td.setAttribute('style', cellStyle(bg, color, weight, false, isVerdict) + ';width:68%;white-space:normal');
        td.textContent = val;
        tr.appendChild(th); tr.appendChild(td);
        tbl.appendChild(tr);
      });
      wrap.appendChild(tbl);
    });
    return wrap;
  }

  // Word ignore souvent les <style> embarqués pour le calcul des largeurs de
  // tableau, donc on inline les attributs critiques. Les tableaux LARGES et
  // COURTS sont transposés (colonnes -> lignes) pour rester lisibles dans Word.
  clone.querySelectorAll('table').forEach(t => {
    const allRows = [...t.querySelectorAll('tr')];
    const headerRow = allRows.find(tr => tr.querySelector('th'));
    const dataTrs = allRows.filter(tr => !tr.querySelector('th'));
    let headers = [], vIdx = -1;
    if (headerRow) {
      headers = [...headerRow.querySelectorAll('th')].map(th => th.innerText.trim());
      vIdx = headers.findIndex(h => ['VERDICT', 'STATUS', 'STATUT'].includes(h.toUpperCase()));
    }

    // --- Cas 1 : tableau large (>=7 col) et court (<=3 lignes) => transposer ---
    if (headers.length >= 7 && dataTrs.length >= 1 && dataTrs.length <= 3) {
      const dataRows = dataTrs.map(tr => [...tr.querySelectorAll('td')].map(td => td.innerText.trim()));
      const transposed = buildTransposed(headers, dataRows, vIdx);
      t.parentNode.replaceChild(transposed, t);
      return;
    }

    // --- Cas 2 : tableau normal => mise en forme en place (sans nowrap) -------
    t.setAttribute('border', '1');
    t.setAttribute('cellspacing', '0');
    t.setAttribute('cellpadding', '4');
    const cur = t.getAttribute('style') || '';
    t.setAttribute('style', cur + ';border-collapse:collapse;border:1pt solid #C9C0AE'
      + ';font-family:Calibri,Arial,sans-serif;font-size:10pt'
      + ';mso-table-lspace:0pt;mso-table-rspace:0pt');

    let dataRowIdx = 0;
    allRows.forEach(tr => {
      if (tr.querySelector('th')) {
        tr.querySelectorAll('th').forEach(cell => {
          const align = cell.getAttribute('align') || 'left';
          cell.setAttribute('style', TH_STYLE.replace('text-align:left', 'text-align:' + align));
        });
        return;
      }
      const zebraBg = (dataRowIdx % 2 === 1) ? '#FBF8F3' : '#FFFFFF';
      const tds = [...tr.querySelectorAll('td')];
      let rowVerdict = null;
      if (vIdx >= 0 && tds[vIdx]) rowVerdict = verdictClass(tds[vIdx].innerText);
      const rowTint = rowVerdict === 'v-critical' ? '#FCEDE6'
                    : (rowVerdict === 'v-warning' || rowVerdict === 'v-license') ? '#FCF4E4'
                    : null;
      tds.forEach((cell, idx) => {
        const align = cell.getAttribute('align') || 'left';
        const cls = cell.getAttribute('class') || '';
        const isNum = align === 'right';
        const isVerdict = idx === vIdx;
        let bg = rowTint || zebraBg, color = '#1C1916', weight = 'normal';
        if (isVerdict) {
          const vc = verdictClass(cell.innerText);
          if (vc && VERD[vc]) { bg = VERD[vc].bg; color = VERD[vc].color; weight = VERD[vc].weight; }
        } else if (/highlight|pct_error/.test(cls)) {
          bg = '#F8DCD3'; color = '#A8412E'; weight = '600';
        } else if (/pct_warning/.test(cls)) {
          bg = '#F4EAD0'; color = '#A07B1F'; weight = '500';
        }
        cell.setAttribute('style', cellStyle(bg, color, weight, isNum, isVerdict));
      });
      dataRowIdx++;
    });
  });

  // Blocs <pre> : police mono + filet gauche terracotta + pas de wrap
  clone.querySelectorAll('pre').forEach(pre => {
    pre.setAttribute('style',
      "font-family:'Consolas','Courier New',monospace" +
      ';font-size:9pt' +
      ';background:#F1ECE4' +
      ';color:#1C1916' +
      ';padding:8pt 12pt' +
      ';border-left:3pt solid #B85C2A' +
      ';white-space:pre' +
      ';margin:6pt 0'
    );
  });

  // Le titre h3.section-title devient un vrai h2 pour que Word le voie comme un titre.
  const titleEl = clone.querySelector('.section-title');
  const titleText = titleEl ? titleEl.innerText : '';
  const titleHtml = titleText
    ? `<h2 style="font-family:Calibri,Arial,sans-serif;color:#1C1916;font-size:14pt;margin:14pt 0 8pt;border-bottom:1.5pt solid #B85C2A;padding-bottom:4pt;font-weight:600">${titleText}</h2>`
    : '';
  const body = clone.querySelector('.section-body');
  const bodyHtml = body ? body.innerHTML : clone.innerHTML;

  const html = '<!doctype html><html><head><meta charset="utf-8"></head><body>'
    + titleHtml + bodyHtml + '</body></html>';
  const text = (titleText ? titleText + '\n\n' : '') + (body ? body.innerText : clone.innerText);

  try {
    if (navigator.clipboard && window.ClipboardItem) {
      await navigator.clipboard.write([
        new ClipboardItem({
          'text/html': new Blob([html], { type: 'text/html' }),
          'text/plain': new Blob([text], { type: 'text/plain' }),
        })
      ]);
      showToast('Section copiée — collez dans Word');
      flashCopied(sec, btn);
    } else {
      copyFallback(html, text, sec, btn);
    }
  } catch (err) {
    copyFallback(html, text, sec, btn);
  }
}

function copyFallback(html, text, sec, btn) {
  // Fallback : utilise une <iframe> + execCommand pour préserver le HTML
  const tmp = document.createElement('div');
  tmp.contentEditable = 'true';
  tmp.innerHTML = html;
  tmp.style.position = 'fixed';
  tmp.style.left = '-9999px';
  document.body.appendChild(tmp);
  const r = document.createRange();
  r.selectNodeContents(tmp);
  const s = window.getSelection();
  s.removeAllRanges();
  s.addRange(r);
  let ok = false;
  try { ok = document.execCommand('copy'); } catch (_) {}
  s.removeAllRanges();
  tmp.remove();
  if (ok) {
    showToast('Section copiée — collez dans Word');
    flashCopied(sec, btn);
  } else {
    showToast('Échec de la copie — vérifiez les permissions', true);
  }
}

function flashCopied(sec, btn) {
  sec.classList.add('copied');
  if (btn) {
    const orig = btn.innerHTML;
    btn.classList.add('copied');
    btn.innerHTML = '<svg class="ico" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg> Copié';
    setTimeout(() => {
      btn.classList.remove('copied');
      btn.innerHTML = orig;
      sec.classList.remove('copied');
    }, 1500);
  } else {
    setTimeout(() => sec.classList.remove('copied'), 1500);
  }
}

// --- Toast ---------------------------------------------------------------
function showToast(msg, isError) {
  const t = document.getElementById('toast');
  if (!t) return;
  t.textContent = msg;
  t.classList.toggle('error', !!isError);
  t.classList.add('show');
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => t.classList.remove('show'), 2400);
}

// --- Collapse / expand --------------------------------------------------
function toggleSection(sectionId) {
  const sec = document.getElementById(sectionId);
  if (sec) sec.classList.toggle('collapsed');
}

function expandAll() {
  document.querySelectorAll('.section.collapsed').forEach(s => s.classList.remove('collapsed'));
}
function collapseAll() {
  document.querySelectorAll('.section:not(.collapsed)').forEach(s => s.classList.add('collapsed'));
}

// --- Search filter ------------------------------------------------------
function filterSections(query) {
  query = (query || '').toLowerCase().trim();
  document.querySelectorAll('.section').forEach(sec => {
    const title = (sec.querySelector('.section-title')?.innerText || '').toLowerCase();
    const body = (sec.querySelector('.section-body')?.innerText || '').toLowerCase();
    const match = !query || title.includes(query) || body.includes(query);
    sec.classList.toggle('hidden', !match);
  });
  document.querySelectorAll('.toc-link').forEach(link => {
    const t = link.innerText.toLowerCase();
    link.classList.toggle('hidden', query && !t.includes(query));
  });
}

// --- Scrollspy: highlight TOC link of current section --------------------
function initScrollspy() {
  const links = new Map();
  document.querySelectorAll('.toc-link').forEach(l => {
    const id = l.getAttribute('href')?.replace('#', '');
    if (id) links.set(id, l);
  });
  const observer = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        const id = e.target.id;
        document.querySelectorAll('.toc-link.active').forEach(l => l.classList.remove('active'));
        links.get(id)?.classList.add('active');
      }
    });
  }, { rootMargin: '-30% 0px -60% 0px' });
  document.querySelectorAll('.section').forEach(s => observer.observe(s));
}

// --- Theme picker --------------------------------------------------------
function hexToRgb(hex) {
  const h = hex.replace('#', '');
  const v = h.length === 3
    ? h.split('').map(c => c + c).join('')
    : h;
  return {
    r: parseInt(v.substr(0, 2), 16),
    g: parseInt(v.substr(2, 2), 16),
    b: parseInt(v.substr(4, 2), 16),
  };
}
function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h, s, l = (max + min) / 2;
  if (max === min) { h = s = 0; }
  else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h /= 6;
  }
  return { h, s, l };
}
function hslToHex(h, s, l) {
  let r, g, b;
  if (s === 0) { r = g = b = l; }
  else {
    const hue2rgb = (p, q, t) => {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1/6) return p + (q - p) * 6 * t;
      if (t < 1/2) return q;
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
      return p;
    };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1/3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1/3);
  }
  const toHex = x => Math.round(x * 255).toString(16).padStart(2, '0');
  return '#' + toHex(r) + toHex(g) + toHex(b);
}

const THEME_KEY = 'db-report-accent';
const DEFAULT_ACCENT = '#B85C2A';

function applyTheme(hex) {
  if (!/^#[0-9a-fA-F]{3,6}$/.test(hex)) hex = DEFAULT_ACCENT;
  const { h, s, l } = rgbToHsl(...Object.values(hexToRgb(hex)));
  // accent-deep : -15% en luminosité (plancher 12%)
  const deep = hslToHex(h, s, Math.max(0.12, l - 0.15));
  // accent-soft : tonalité conservée, désaturée à 50%, luminosité poussée à 92%
  const soft = hslToHex(h, Math.max(0.12, s * 0.5), 0.92);

  // Fonds dérivés de la teinte avec une saturation contenue (jusqu'à 15-30%
  // selon la composante) pour teinter sans saturer. Cap dur sur les couleurs
  // très saturées (rouge pur, magenta) qui sinon donneraient un fond agressif.
  const sBg     = Math.min(s * 0.22, 0.16);
  const sRow    = Math.min(s * 0.26, 0.19);
  const sCode   = Math.min(s * 0.32, 0.22);
  const sRule   = Math.min(s * 0.38, 0.26);
  const sRuleS  = Math.min(s * 0.48, 0.32);
  const bg         = hslToHex(h, sBg,    0.965);
  const bgElev     = hslToHex(h, sBg * 0.35, 0.998); // cartes quasi blanches pour ressortir
  const bgRowAlt   = hslToHex(h, sRow,   0.955);
  const bgCode     = hslToHex(h, sCode,  0.92);
  const rule       = hslToHex(h, sRule,  0.87);
  const ruleStrong = hslToHex(h, sRuleS, 0.77);

  const root = document.documentElement;
  root.style.setProperty('--accent', hex);
  root.style.setProperty('--accent-deep', deep);
  root.style.setProperty('--accent-soft', soft);
  root.style.setProperty('--bg', bg);
  root.style.setProperty('--bg-elev', bgElev);
  root.style.setProperty('--bg-row-alt', bgRowAlt);
  root.style.setProperty('--bg-code', bgCode);
  root.style.setProperty('--rule', rule);
  root.style.setProperty('--rule-strong', ruleStrong);

  try { localStorage.setItem(THEME_KEY, hex); } catch (e) { /* mode privé / file:// */ }

  // Met à jour l'état actif sur les swatches
  document.querySelectorAll('.theme-swatch').forEach(s => {
    s.classList.toggle('active', s.dataset.color?.toLowerCase() === hex.toLowerCase());
  });
  // Synchronise le color input avec la valeur courante
  const customInput = document.getElementById('theme-custom-input');
  if (customInput) customInput.value = hex;
}

function initThemePicker() {
  let initial = DEFAULT_ACCENT;
  try { initial = localStorage.getItem(THEME_KEY) || DEFAULT_ACCENT; } catch (e) {}
  applyTheme(initial);

  document.querySelectorAll('.theme-swatch').forEach(sw => {
    sw.addEventListener('click', () => applyTheme(sw.dataset.color));
  });
  const customInput = document.getElementById('theme-custom-input');
  if (customInput) {
    customInput.addEventListener('input', e => applyTheme(e.target.value));
  }
}

// --- Scroll reveal -------------------------------------------------------
function initScrollReveal() {
  // Respect prefers-reduced-motion
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    document.querySelectorAll('.reveal').forEach(el => el.classList.add('in-view'));
    return;
  }
  if (!('IntersectionObserver' in window)) {
    document.querySelectorAll('.reveal').forEach(el => el.classList.add('in-view'));
    return;
  }
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('in-view');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.04,
    rootMargin: '0px 0px -40px 0px',
  });
  document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
}

// --- DB tab switching ----------------------------------------------------
function switchDb(sid) {
  if (!sid) return;
  document.querySelectorAll('.db-tab').forEach(b => {
    b.classList.toggle('active', b.dataset.sid === sid);
  });
  document.querySelectorAll('.db-group').forEach(g => {
    g.classList.toggle('hidden', g.dataset.sid !== sid);
  });
  document.querySelectorAll('.toc-db-group').forEach(g => {
    g.classList.toggle('hidden', g.dataset.sid !== sid);
  });
  // Re-trigger reveal on newly-shown sections (they may already be in viewport)
  document.querySelectorAll('.db-group:not(.hidden) .reveal:not(.in-view)').forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.top < window.innerHeight) el.classList.add('in-view');
  });
  // Persist in URL hash
  try {
    const u = new URL(window.location.href);
    u.hash = 'sid=' + encodeURIComponent(sid);
    history.replaceState(null, '', u);
  } catch (e) { /* file:// has limited URL support */ }
}

function initDbTabs() {
  const tabs = document.querySelectorAll('.db-tab');
  if (tabs.length === 0) return;
  tabs.forEach(t => t.addEventListener('click', () => switchDb(t.dataset.sid)));
  // Restore from hash if present, else activate first tab
  const hashMatch = (window.location.hash || '').match(/sid=([^&]+)/);
  if (hashMatch) {
    switchDb(decodeURIComponent(hashMatch[1]));
  } else {
    const first = tabs[0]?.dataset.sid;
    if (first) switchDb(first);
  }
}

// --- Init ----------------------------------------------------------------
document.addEventListener('DOMContentLoaded', () => {
  initThemePicker();
  initVerdicts();
  initScrollspy();
  initDbTabs();
  initScrollReveal();
  const search = document.getElementById('toc-search');
  if (search) {
    search.addEventListener('input', e => filterSections(e.target.value));
    // Ctrl/Cmd + K pour focus la recherche
    document.addEventListener('keydown', e => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        search.focus();
        search.select();
      }
    });
  }

  // Bouton "retour en haut" : visible quand on a scrollé au-delà de 400px
  const top = document.getElementById('back-to-top');
  if (top) {
    const onScroll = () => top.classList.toggle('visible', window.scrollY > 400);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }
});
