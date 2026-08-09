#!/usr/bin/env python3
"""Build script for the "nebbie-complete-dashboard-package" Mudlet package.

Genera un .mpackage minimo (config.lua + XML root, formato documentato in
docs/mudlet/analysis/MUDLET-WIKI-NOTES.md §7) a partire da:
  - docs/mudlet/nebbie-complete-dashboard-package-core.lua (logica principale)

A differenza di build-nebbie-package.py (legacy, ~2000 righe, generazione da
sorgente C++), questo script e' intenzionalmente piccolo: il package nuovo non
genera centinaia di alias/trigger dal sorgente MUD, solo un piccolo set di
comandi statici (vedi ALIASES sotto).

Uso:
    python3 docs/mudlet/build-nebbie-complete-dashboard-package.py
"""
import os
import zipfile
import xml.sax.saxutils as sax

HERE = os.path.dirname(os.path.abspath(__file__))
PKG_NAME = "nebbie-complete-dashboard-package"
PKG_VER = "1.3.0"
PKG_AUTHOR = "Nebbie Arcane"
PKG_ICON_FILE = "nebbie-dash-icon.png"
PKG_ICON_SRC = os.path.join(HERE, "assets", PKG_ICON_FILE)
PKG_TITLE = "Nebbie Dashboard — equip, spell attivi e speedwalk per Nebbie Arcane"
# IMPORTANTE: aggiornare questa descrizione ad ogni release (vedi CHANGELOG.md
# per il changelog completo) — e' quello che l'utente legge nella schermata
# "Gestione pacchetti" di Mudlet PRIMA di installare/aggiornare, quindi deve
# riassumere cosa fa il package alla versione corrente, non solo all'ultima
# feature aggiunta.
PKG_DESCRIPTION = f"""# Nebbie Dashboard ({PKG_VER})

Pannello laterale per **Nebbie Arcane**, con supporto multi-personaggio (un
profilo Mudlet, più personaggi, cambio automatico rilevato dal prompt).

- **Equip** (bordo sinistro): tutti gli slot indossati, con posizione ed
  oggetto letti da `eq`; segna anche gli slot liberi noti.
- **Spell attivi** (bordo destro, in alto): spell/buff letti da `attrib`,
  cliccabili per rilanciarli sul personaggio corrente (`cast`/`recall`/`mind`
  a seconda della classe, vedi `nclass`).
- **Speedwalk** (bordo destro, in basso): percorsi rapidi definiti a mano in
  un file di testo, cliccabili per eseguirli in sequenza.
- Layout ridimensionabile (larghezza automatica o manuale, altezza
  spell/speedwalk regolabile) e persistente tra sessioni.

Nessun comando viene inviato al MUD in automatico: usa `nresync` dopo il
login per sincronizzare equip e spell. Vedi `nfix` se qualcosa sembra
bloccato dopo un aggiornamento.

Documentazione completa (tutti i comandi, formato file speedwalk, changelog):
`docs/mudlet/analysis/USAGE.md` e `docs/mudlet/analysis/CHANGELOG.md` nel
repository del progetto.
"""
CORE_LUA = os.path.join(HERE, "nebbie-complete-dashboard-package-core.lua")
BUILD_DIR = os.path.join(HERE, "nebbie-complete-dashboard-package-build")
XML_PATH = os.path.join(BUILD_DIR, f"{PKG_NAME}.xml")
CONFIG_PATH = os.path.join(BUILD_DIR, "config.lua")
MPACKAGE_PATH = os.path.join(HERE, f"{PKG_NAME}.mpackage")

# Comandi manuali (Q&A.md Round 2/finale: nomi proposti, nessuna preferenza
# diversa espressa dall'utente). Nessuno di questi invia comandi al MUD in
# automatico al boot (vedi RECOMMENDATION.md / divieti confermati nel LOG.md).
ALIASES = [
    ("nebbie-dash-fix", "^nfix$", "NebbieDash.runFix()"),
    ("nebbie-dash-eq", "^neq$", "NebbieDash.cmdShowEq()"),
    ("nebbie-dash-attrib", "^nattrib$", "NebbieDash.cmdShowAttrib()"),
    ("nebbie-dash-resync", "^nresync$", "NebbieDash.cmdResyncAll()"),
    ("nebbie-dash-gui", "^ngui$", "NebbieDash.toggleGUI()"),
    ("nebbie-dash-layout", "^nlayout$", "NebbieDash.resetLayout()"),
    ("nebbie-dash-char", "^nchar (.+)$", "NebbieDash.cmdSetCharacter(matches[2])"),
    ("nebbie-dash-font", "^nfont (.+)$", "NebbieDash.cmdSetFont(matches[2])"),
    ("nebbie-dash-width", "^nwidth (.+)$", "NebbieDash.cmdSetWidth(matches[2])"),
    ("nebbie-dash-itemlen", "^nitemlen (.+)$", "NebbieDash.cmdSetItemLen(matches[2])"),
    ("nebbie-dash-quickcast", "^([crm]) (.+)$", "NebbieDash.cmdQuickCast(matches[2], matches[3])"),
    ("nebbie-dash-class", "^nclass (.+)$", "NebbieDash.cmdSetClass(matches[2])"),
    ("nebbie-dash-spellwarn", "^nspellwarn (.+)$", "NebbieDash.cmdSetSpellWarn(matches[2])"),
    ("nebbie-dash-speedwalks", "^nspeedwalks$", "NebbieDash.cmdReloadSpeedwalks()"),
    ("nebbie-dash-speeddelay", "^nspeeddelay (.+)$", "NebbieDash.cmdSetSpeedDelay(matches[2])"),
    ("nebbie-dash-heights", "^nheights (.+)$", "NebbieDash.cmdSetHeights(matches[2])"),
    ("nebbie-dash-clanslot", "^nclanslot (.+)$", "NebbieDash.cmdSetClanSlot(matches[2])"),
]


def lua_long_string(text):
    """Racchiude 'text' in una stringa Lua a parentesi lunghe ([[...]]),
    scegliendo un livello di '=' abbastanza alto da non collidere mai con
    eventuali sequenze di chiusura gia' presenti nel testo."""
    level = 0
    marker = "]]"
    while marker in text:
        level += 1
        marker = "]" + ("=" * level) + "]"
    eq = "=" * level
    return f"[{eq}[{text}]{eq}]"


def cdata(text):
    # CDATA non puo' contenere la sequenza "]]>" letteralmente.
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def build_xml(core_code):
    boot_wrapper = f'''local ver = "{PKG_VER}"
if NebbieDash and NebbieDash.version == ver and NebbieDash._mainLoaded then return end
local ok, err = pcall(function() NebbieDash.boot() end)
if not ok then
  cecho("<red>[NebbieDash] errore boot: " .. tostring(err) .. "\\n")
end'''

    parts = []
    parts.append('<?xml version="1.0" encoding="UTF-8"?>')
    parts.append('<!DOCTYPE MudletPackage>')
    parts.append('<MudletPackage version="1.001">')
    parts.append(' <ScriptPackage>')

    parts.append('  <Script isActive="yes" isFolder="no">')
    parts.append(f'   <name>{PKG_NAME} - core</name>')
    parts.append(f'   <script>{cdata(core_code)}</script>')
    parts.append(f'   <packageName>{PKG_NAME}</packageName>')
    parts.append('  </Script>')

    parts.append('  <Script isActive="yes" isFolder="no">')
    parts.append(f'   <name>{PKG_NAME} - boot</name>')
    parts.append(f'   <script>{cdata(boot_wrapper)}</script>')
    parts.append('   <eventHandlerList>')
    parts.append('    <string>sysLoadEvent</string>')
    parts.append('   </eventHandlerList>')
    parts.append(f'   <packageName>{PKG_NAME}</packageName>')
    parts.append('  </Script>')

    parts.append(' </ScriptPackage>')
    parts.append(' <AliasPackage>')
    for name, regex, call in ALIASES:
        parts.append('  <Alias isActive="yes" isFolder="no">')
        parts.append(f'   <name>{sax.escape(name)}</name>')
        parts.append(f'   <script>{cdata(call)}</script>')
        parts.append('   <command></command>')
        parts.append(f'   <packageName>{PKG_NAME}</packageName>')
        parts.append(f'   <regex>{sax.escape(regex)}</regex>')
        parts.append('  </Alias>')
    parts.append(' </AliasPackage>')
    parts.append('</MudletPackage>')
    return "\n".join(parts) + "\n"


def main():
    with open(CORE_LUA, "r", encoding="utf-8") as f:
        core_code = f.read()

    os.makedirs(BUILD_DIR, exist_ok=True)

    xml_content = build_xml(core_code)
    with open(XML_PATH, "w", encoding="utf-8") as f:
        f.write(xml_content)

    if not os.path.exists(PKG_ICON_SRC):
        raise SystemExit(f"Icona mancante: {PKG_ICON_SRC}")

    config_lines = [
        f"mpackage = {lua_long_string(PKG_NAME)}",
        f"author = {lua_long_string(PKG_AUTHOR)}",
        f"icon = {lua_long_string(PKG_ICON_FILE)}",
        f"title = {lua_long_string(PKG_TITLE)}",
        f"description = {lua_long_string(PKG_DESCRIPTION)}",
        f"version = {lua_long_string(PKG_VER)}",
    ]
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(config_lines) + "\n")

    if os.path.exists(MPACKAGE_PATH):
        os.remove(MPACKAGE_PATH)
    with zipfile.ZipFile(MPACKAGE_PATH, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(CONFIG_PATH, "config.lua")
        z.write(XML_PATH, f"{PKG_NAME}.xml")
        # Percorso richiesto da Mudlet per l'icona nella schermata "Gestione
        # pacchetti" (verificato in src/dlgPackageManager.cpp del repo Mudlet:
        # cerca <nomePackage>/.mudlet/Icon/<icon> dentro la cartella in cui il
        # pacchetto viene scompattato, cioe' la radice dello zip stesso).
        z.write(PKG_ICON_SRC, f".mudlet/Icon/{PKG_ICON_FILE}")

    size = os.path.getsize(MPACKAGE_PATH)
    print(f"Scritto {MPACKAGE_PATH} ({size} bytes)")
    print(f"Scritto {XML_PATH}")
    print(f"Scritto {CONFIG_PATH}")
    print(f"Icona inclusa: {PKG_ICON_SRC} -> .mudlet/Icon/{PKG_ICON_FILE}")


if __name__ == "__main__":
    main()
