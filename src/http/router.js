const url = require('url');
const { read, update } = require('../core/db');
const { suggestedPrice } = require('../domain/valuation');

function parseBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => data += c);
    req.on('end', () => {
      try { resolve(JSON.parse(data || '{}')); } catch { resolve({}); }
    });
  });
}

function send(res, code, body, type='application/json') {
  res.writeHead(code, { 'Content-Type': type });
  res.end(type==='application/json' ? JSON.stringify(body) : body);
}

function auth(req) {
  const key = req.headers['x-owner-key'];
  return key === (process.env.OWNER_KEY || 'ciphered-souls-dev-owner');
}

async function route(req, res) {
  const { pathname } = url.parse(req.url, true);

  if (pathname === '/api/health') return send(res, 200, { ok: true });

  if (pathname === '/api/items' && req.method === 'GET') {
    const db = read();
    return send(res, 200, db.items || []);
  }

  if (pathname === '/api/items' && req.method === 'POST') {
    if (!auth(req)) return send(res, 401, { error: 'unauthorized' });
    const body = await parseBody(req);
    const item = {
      id: Date.now().toString(36),
      name: body.name || 'New Item',
      attrs: body.attrs || {},
      rarity: body.rarity || 'COMMON',
      price: suggestedPrice(body.attrs || {}, body.rarity || 'COMMON', 1),
      createdAt: Date.now()
    };
    const db = update((d) => { d.items.push(item); return d; });
    return send(res, 201, item);
  }

  if (pathname.startsWith('/api/items/') && req.method === 'PATCH') {
    if (!auth(req)) return send(res, 401, { error: 'unauthorized' });
    const id = pathname.split('/').pop();
    const body = await parseBody(req);
    const db = update((d) => {
      const it = d.items.find(i => i.id === id);
      if (!it) return d;
      Object.assign(it, body);
      it.price = suggestedPrice(it.attrs || {}, it.rarity || 'COMMON', 1);
      return d;
    });
    const item = db.items.find(i => i.id === id);
    return send(res, 200, item || { error: 'not_found' });
  }

  return false;
}

module.exports = { route };
