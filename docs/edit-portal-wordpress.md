# Portale Edit dietro WordPress (`/edit/`) + SSO

## Decisione prodotto (day‑1)

| Punto | Scelta |
|-------|--------|
| Path pubblico | `https://…/edit/` (reverse proxy → Node `:3080`) |
| Login | **SSO WordPress obbligatorio** in produzione |
| Matching account | **stessa email** WP `user_email` ↔ Mud `user.email` |
| Chi può usare il portale | ogni utente WP **già loggato**; vede i toon di quell'account (`toon.owner_id = user.id`) con i ruoli già definiti (limited &lt;51 / player / staff ≥57) |

Password login sul portale resta solo per **dev locale** (senza `EDIT_WP_SSO_SECRET`, o con `EDIT_ALLOW_PASSWORD_LOGIN=1`).

## Flusso

1. Utente loggato su WordPress apre shortcode `[nebbie_edit_portal]`, voce admin‑bar, o `/?nebbie_edit_sso=1`.
2. Il mu‑plugin firma un token HMAC‑SHA256 (TTL ~120s): `base64url(json).base64url(hmac)`.
3. Redirect a `/edit/api/sso/wordpress?token=…`.
4. `edit-portal` verifica la firma, cerca `user` per email, crea sessione cookie, redirect a `/edit/`.
5. L’utente sceglie un toon posseduto e lavora con i limiti di livello già in vigore.

Payload JSON:

```json
{ "email": "player@example.com", "iat": 1710000000, "exp": 1710000120 }
```

## Nginx (esempio)

```nginx
location /edit/ {
    proxy_pass http://127.0.0.1:3080/edit/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Cookie $http_cookie;
}
```

Il Node deve avere `EDIT_BASE_PATH=/edit` (path cookie e asset allineati).

## Env produzione (container `edit-portal`)

```bash
EDIT_BASE_PATH=/edit
EDIT_WP_SSO_SECRET=<stesso valore di NEBBIE_EDIT_SSO_SECRET in wp-config>
EDIT_WP_SITE_URL=https://www.nebbiearcane.it
EDIT_WP_LOGIN_URL=https://www.nebbiearcane.it/wp-login.php
EDIT_COOKIE_SECURE=1
EDIT_SSO_REQUIRED=1
# non impostare EDIT_ALLOW_PASSWORD_LOGIN in prod
EDIT_SESSION_SECRET=<random lungo>
```

Locale nucbuntu (password OK):

```bash
# niente EDIT_WP_SSO_SECRET → SSO off, form email/password attivo
EDIT_BASE_PATH=          # vuoto: http://nucbuntu:3080/
# oppure test path:
# EDIT_BASE_PATH=/edit EDIT_ALLOW_PASSWORD_LOGIN=1 EDIT_WP_SSO_SECRET=dev-secret EDIT_DEV_MINT_SSO=1
```

## WordPress mu‑plugin

File nel repo: [`wordpress/mu-plugins/nebbie-edit-sso.php`](../wordpress/mu-plugins/nebbie-edit-sso.php)

Copia su WP:

```bash
cp wordpress/mu-plugins/nebbie-edit-sso.php /path/to/wp-content/mu-plugins/
```

In `wp-config.php`:

```php
define('NEBBIE_EDIT_SSO_SECRET', '…'); // = EDIT_WP_SSO_SECRET
define('NEBBIE_EDIT_PORTAL_URL', 'https://www.nebbiearcane.it/edit');
```

## Test SSO senza WP (solo dev)

Con `EDIT_DEV_MINT_SSO=1`, secret impostato e SSO **non** required (o password login forzato):

```bash
curl -s -X POST http://localhost:3080/api/dev/mint-sso \
  -H 'Content-Type: application/json' \
  -d '{"email":"tua@email.it"}'
# apri il campo "redirect" nel browser
```

Con `EDIT_BASE_PATH=/edit` gli URL diventano `/edit/api/...`.

## Checklist deploy

1. Segreti allineati WP ↔ edit-portal.
2. Email WP = email Mud per ogni giocatore che deve entrare.
3. Nginx `/edit/` + `EDIT_BASE_PATH=/edit` + `EDIT_COOKIE_SECURE=1`.
4. Hard refresh UI (`EDIT_PORTAL_UI_BUILD` in `app.js`).
5. Non esporre myst `:8090` in pubblico.
