const http = require('http');
const fs = require('fs');
const path = require('path');
const { route } = require('./http/router');

const PORT = process.env.PORT || 8787;
const PUBLIC = path.join(__dirname, '..', 'public');

function serveStatic(req, res) {
  let file = req.url === '/' ? '/index.html' : req.url;
  const p = path.join(PUBLIC, file);
  if (fs.existsSync(p) && fs.statSync(p).isFile()) {
    const ext = path.extname(p);
    const map = { '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript' };
    res.writeHead(200, { 'Content-Type': map[ext] || 'text/plain' });
    fs.createReadStream(p).pipe(res);
    return true;
  }
  return false;
}

const server = http.createServer(async (req, res) => {
  const handled = await route(req, res);
  if (handled !== false) return;
  if (serveStatic(req, res)) return;
  res.writeHead(404); res.end('Not Found');
});

server.listen(PORT, () => {
  console.log(`Ciphered Souls server running on http://localhost:${PORT}`);
});
