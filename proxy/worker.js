// Proxy minimal pour la reconnaissance photo de Caillou (Cloudflare Worker, sans dépendance).
//
// Rôle : garder la clé du fournisseur de vision CÔTÉ SERVEUR. L'app appelle
//   POST https://<votre-worker>/v1/chat/completions
// avec un jeton d'app facultatif ; le proxy impose le modèle et les limites, puis relaie.
//
// Variables (wrangler secret put ... / wrangler.toml [vars]) :
//   UPSTREAM_API_KEY  (secret, obligatoire)  clé du fournisseur
//   UPSTREAM_BASE_URL (défaut https://api.mistral.ai/v1)
//   MODEL             (défaut mistral-small-latest)
//   APP_TOKEN         (secret, facultatif)   jeton attendu dans "Authorization: Bearer ..."

const MAX_BODY_BYTES = 3_000_000; // ~ photo 1280 px en base64
const MAX_TOKENS = 800;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== '/v1/chat/completions') {
      return json({ error: { message: 'Not found' } }, 404);
    }
    if (env.APP_TOKEN && request.headers.get('Authorization') !== `Bearer ${env.APP_TOKEN}`) {
      return json({ error: { message: 'Jeton invalide' } }, 401);
    }
    if (!env.UPSTREAM_API_KEY) {
      return json({ error: { message: 'Proxy non configuré (UPSTREAM_API_KEY manquant)' } }, 500);
    }

    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) return json({ error: { message: 'Image trop lourde' } }, 413);

    let body;
    try {
      body = JSON.parse(raw);
    } catch {
      return json({ error: { message: 'JSON invalide' } }, 400);
    }
    if (!Array.isArray(body.messages)) return json({ error: { message: 'messages manquant' } }, 400);

    // Le client ne choisit ni le modèle ni la taille de la réponse.
    const upstreamBody = {
      model: env.MODEL || 'mistral-small-latest',
      messages: body.messages,
      temperature: 0,
      max_tokens: Math.min(Number(body.max_tokens) || MAX_TOKENS, MAX_TOKENS),
      ...(body.response_format ? { response_format: body.response_format } : {}),
    };

    const base = (env.UPSTREAM_BASE_URL || 'https://api.mistral.ai/v1').replace(/\/+$/, '');
    const upstream = await fetch(`${base}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.UPSTREAM_API_KEY}`,
      },
      body: JSON.stringify(upstreamBody),
    });

    return new Response(upstream.body, {
      status: upstream.status,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
    });
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
