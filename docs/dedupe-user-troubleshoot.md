# dedupe-user-by-email — troubleshooting

## Errore `Table 'nebbie_mas.user' doesn't exist`

Il database del mud in dev è **`nebbie`**, ma su `nebbie.user` c’è spesso un **trigger** (importato da produzione) che scrive su **`nebbie_mas.user`**. Su VM di test `nebbie_mas` non esiste → l’`UPDATE` fallisce.

### 1) Vedi quali trigger ci sono

```bash
mysql -h 127.0.0.1 -uroot -psecret -e "
SHOW TRIGGERS FROM nebbie WHERE \`Table\` = 'user'\G
"
```

### 2) Fix consigliato in dev — rimuovi il trigger rotto

```bash
# sostituisci NOME_TRIGGER con quello visto sopra
mysql -h 127.0.0.1 -uroot -psecret -e "
DROP TRIGGER IF EXISTS nebbie.NOME_TRIGGER;
"
```

Poi rilancia:

```bash
mysql -h 127.0.0.1 -uroot -psecret nebbie < docs/dedupe-user-by-email.sql
```

### 3) Alternativa — merge manuale (stessi passi, stesso rischio trigger)

Se non puoi toccare i trigger, copia i valori a mano dopo un `SELECT`:

```bash
mysql -h 127.0.0.1 -uroot -psecret nebbie
```

```sql
SELECT id, nickname, level, password FROM user WHERE email = 'wizmorgan@gmail.com';

-- Esempio: keep 4, merge da 165 (adatta i valori dal SELECT)
UPDATE user SET nickname='Sirio', level=60,
  password=(SELECT p FROM (SELECT password AS p FROM user WHERE id=165) x)
WHERE id=4;

UPDATE toon SET owner_id=4 WHERE owner_id=165;
DELETE FROM user WHERE id=165;
```

(L’`UPDATE` su `user` può comunque scatenare il trigger → in dev conviene **droppare il trigger**.)

### 4) Alternativa rapida — stub `nebbie_mas`

Solo per sbloccare senza analizzare il trigger:

```sql
CREATE DATABASE IF NOT EXISTS nebbie_mas;
CREATE TABLE IF NOT EXISTS nebbie_mas.user LIKE nebbie.user;
```

Poi rilancia lo script di dedupe.

---

## Verifica finale

```bash
mysql -h 127.0.0.1 -uroot -psecret nebbie -e "
SELECT id, email, nickname, level FROM user WHERE email='wizmorgan@gmail.com';
SELECT name, owner_id FROM toon WHERE LOWER(name)='sirio';
"
```

Atteso: **una riga** `user` id=**4**, nickname **Sirio**, level **60**; Sirio con `owner_id=4`.
