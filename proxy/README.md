# Proxy de reconnaissance (facultatif)

À utiliser dès que l'app est installée par d'autres personnes : la clé du fournisseur
de vision reste sur le serveur, jamais dans l'APK.

## Déployer (Cloudflare Workers, offre gratuite)

```bash
cd proxy
npx wrangler login
npx wrangler secret put UPSTREAM_API_KEY   # votre clé Mistral (ou autre fournisseur compatible)
npx wrangler secret put APP_TOKEN          # facultatif : jeton que l'app devra envoyer
npx wrangler deploy
```

Dans l'app : **Réglages → Proxy Caillou**, adresse `https://caillou-proxy.<compte>.workers.dev/v1`,
modèle `auto` (ignoré, c'est le proxy qui décide), clé = `APP_TOKEN` si vous l'avez défini.

## Ce que fait le proxy

- n'accepte que `POST /v1/chat/completions` ;
- vérifie le jeton d'app si `APP_TOKEN` est défini ;
- impose le modèle (`MODEL`), `temperature = 0` et `max_tokens ≤ 800` ;
- refuse les requêtes de plus de ~3 Mo ;
- ne stocke rien (ni photo, ni journal applicatif).

Pour une diffusion large, ajoutez une limite de débit (règle « Rate limiting » Cloudflare)
afin de plafonner le coût.

Changer de fournisseur : modifier `UPSTREAM_BASE_URL` et `MODEL` dans `wrangler.toml`
(toute API compatible « Chat Completions » avec images).
