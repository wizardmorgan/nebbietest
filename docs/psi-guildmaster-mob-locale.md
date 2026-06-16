# myst.mob locale (fuori da git)

## File personale

Copia di lavoro **non versionata**:

`C:\Users\dimolaa\OneDrive - Sky\Documents\Documenti personali\Giochi\git e collegati\myst.mob`

Questo file **non va committato** nel repository Nebbie. Le modifiche ai mob guildmaster PSI
vivono qui (o in un percorso equivalente sul tuo PC) e vengono copiate manualmente nel MUD
al posto di `mudroot/lib/myst.mob` dopo `./getworldlocal`.

Il repo mantiene comunque `myst.mob` allineato per chi usa solo il flusso standard; la tua
copia OneDrive va aggiornata in parallelo con lo stesso contenuto mob.

## Cosa integrare (solo mob)

| Vnum | Ruolo |
|------|--------|
| **#641** Silverleaf | Descrizione aggiornata: immortali possono praticare tutte le skill PSI |
| **#21366** | GM base Myst — skill **L1–39** (`PsiGuildmaster` in `myst.spe`) |
| **#21368** Kaelith | **Nuovo** mob — skill **L40–50** (`MetapsionicGuildmaster`) |
| **#7808** Alrani | Invariato (solo GM base Accademia) |

`myst.spe` / `myst.zon` restano nel repo git (non sono il file OneDrive).

## Applicare il patch sul file locale

Da PowerShell, nella cartella che contiene `myst.mob`:

```powershell
cd "C:\Users\dimolaa\OneDrive - Sky\Documents\Documenti personali\Giochi\git e collegati"
patch -p0 < "PERCORSO_REPO\docs\patches\myst.mob-psi-guildmasters.patch"
```

Se `patch` non è disponibile, applica a mano le tre sezioni del file
`docs/patches/myst.mob-psi-guildmasters.patch` (Silverleaf, #21366, nuovo blocco #21368).

## Verifica proc su Kaelith

Dopo `./getworldlocal`, in `mudroot/lib/myst.spe` devono esserci:

```
M 21366 PsiGuildmaster
M 21368 MetapsionicGuildmaster
```

Senza `M 21368 MetapsionicGuildmaster`, Kaelith non ha special proc e `practice` non funziona.

## Deploy locale MUD

```bash
./getworldlocal
cp "/mnt/c/Users/dimolaa/OneDrive - Sky/Documents/Documenti personali/Giochi/git e collegati/myst.mob" mudroot/lib/myst.mob
# rebuild + reboot
```

Su Vagrant/Windows adatta il path `cp` alla tua macchina.

## Verifica

Dopo zreset zona 30 (Myst), in stanza **3090** devono comparire:

1. `the psionist guildmaster` (#21366) — practice fino a livello 39  
2. `Kaelith, maestro metapsionico` (#21368) — practice dal livello 40
