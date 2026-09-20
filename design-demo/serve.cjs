const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png' };
http.createServer((req, res) => {
  let name;
  try { name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
  catch { res.writeHead(400).end(); return; }
  if (name === '/') { res.writeHead(302, { Location: '/design-demo/' }).end(); return; }
  if (name.endsWith('/')) name += 'index.html';
  const file = path.resolve(root, '.' + name);
  if (!(file.startsWith(path.join(root, 'design-demo') + path.sep) || file === path.join(root, 'assets', 'icon.png'))) {
    res.writeHead(403).end(); return;
  }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404).end(); return; }
    res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(data);
  });
}).listen(4178, '127.0.0.1', () => console.log('Demo: http://127.0.0.1:4178/design-demo/'));
