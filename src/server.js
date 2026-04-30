const http = require('http');
const fs = require('fs');
const path = require('path');
const { route } = require('./http/router');

const DEFAULT_PORT = Number(process.env.PORT || 8787);
const PUBLIC = path.join(__dirname, '..', 'public');

function serveStatic(req, res) {
  const cleanUrl = new URL(req.url, 'http://localhost');
  const file = cleanUrl.pathname === '/' ? '/index.html' : cleanUrl.pathname;
  const p = path.join(PUBLIC, file);
  if (fs.existsSync(p) && fs.statSync(p).isFile()) {
    const ext = path.extname(p);
    const map = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'application/javascript; charset=utf-8' };
    res.writeHead(200, {
      'Content-Type': map[ext] || 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    });
    fs.createReadStream(p).pipe(res);
    return true;
  }
  return false;
}

function createServer() {
  return http.createServer(async (req, res) => {
    const handled = await route(req, res);
    if (handled !== false) return;
    if (serveStatic(req, res)) return;
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not Found');
  });
}

function startServer(port = DEFAULT_PORT, host = '127.0.0.1') {
  const server = createServer();
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, host, () => {
      console.log(`Ciphered Souls server running on http://${host}:${port}`);
      resolve(server);
    });
  });
}

if (require.main === module) {
  startServer(DEFAULT_PORT, '0.0.0.0').catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = { createServer, startServer };
