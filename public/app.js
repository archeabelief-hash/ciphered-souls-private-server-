async function load() {
  const res = await fetch('/api/items');
  const items = await res.json();
  const root = document.getElementById('app');

  root.innerHTML = `
    <button onclick="createItem()">Create Item</button>
    <div>${items.map(i => `<div class='card'><b>${i.name}</b><br/>${i.price} C$</div>`).join('')}</div>
  `;
}

async function createItem() {
  const name = prompt('Item name');
  const attrs = { attack: Number(prompt('Attack', '10')), defense: Number(prompt('Defense', '5')) };
  await fetch('/api/items', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-owner-key': localStorage.getItem('ownerKey') || 'ciphered-souls-dev-owner' },
    body: JSON.stringify({ name, attrs, rarity: 'COMMON' })
  });
  load();
}

load();
