const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', '..', 'data', 'game-db.json');

function read() {
  if (!fs.existsSync(DB_PATH)) return { items: [], templates: [], skins: [], recipes: [], meta: { version: 1 } };
  const raw = fs.readFileSync(DB_PATH, 'utf-8');
  return JSON.parse(raw || '{}');
}

function write(data) {
  fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2));
}

function update(mutator) {
  const db = read();
  const next = mutator(db) || db;
  write(next);
  return next;
}

module.exports = { read, write, update, DB_PATH };
