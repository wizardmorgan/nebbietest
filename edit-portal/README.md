# Nebbie Edit Portal

Web UI per editing oggetti/PG con listino (`obj_value` / `edit_pool`).

**Massimali e prezzi oggetto:** fonte ufficiale
[https://www.nebbiearcane.it/listino-edits/](https://www.nebbiearcane.it/listino-edits/)
(costanti in `src/obj_value.hpp` / tabella `kObjEditListino`).
Non usare EditMaster/`pedit.cpp` come riferimento.

**Artifact (`ITEM_IMMUNE`):** in maschera oggetto; una volta impostato
non si toglie. Ogni edit sul pezzo paga **+50%** sul costo finale listino
(anche se il prototipo era già artifact).

Vedi **docs/edit-portal-nucbuntu.md** per deploy Docker completo.

```bash
cd edit-portal && npm install && npm start
```

Variabili: `MYSQL_*`, `MYST_EDIT_API_URL`, `EDIT_API_SECRET`, `EDIT_WEB_PORT`.

## Login web vs password MUD

Il portale autentica sulla tabella **`user`** (email + `user.password`), come il login account nel MUD.

La tabella **`toon.password`** è usata solo nel flusso legacy (login digitando il nome del PG).

Se hai modificato la password con SQL o istruzioni errate:

1. **Meglio:** entra nel MUD con l'account, menu personaggio → opzione **4** (cambia password account) e imposta una nuova password valida (6–10 caratteri).
2. **Adminer:** tabella `user`, riga della tua email — non inserire testo in chiaro; serve un hash `crypt()` come genera myst.
3. Se il MUD funziona ancora con la vecchia password ma il portale no, probabilmente hai cambiato solo `toon.password` o hai corrotto `user.password` con testo in chiaro (es. `LA_MIA_PASSWORD`).

