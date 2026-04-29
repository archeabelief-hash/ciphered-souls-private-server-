const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

let player = { x: 100, y: 100 };

function draw() {
  ctx.clearRect(0,0,canvas.width,canvas.height);
  ctx.fillStyle = 'lime';
  ctx.fillRect(player.x, player.y, 20, 20);
}
setInterval(draw, 30);

const joy = document.getElementById('joystick');
let dragging = false;
joy.addEventListener('touchstart', ()=>dragging=true);
joy.addEventListener('touchend', ()=>dragging=false);
joy.addEventListener('touchmove', e=>{
  if(!dragging) return;
  const rect = joy.getBoundingClientRect();
  const t = e.touches[0];
  player.x += (t.clientX-rect.left-50)*0.02;
  player.y += (t.clientY-rect.top-50)*0.02;
});

const ownerPanel = document.getElementById('ownerPanel');
document.getElementById('ownerToggle').onclick = ()=>ownerPanel.classList.add('open');
document.getElementById('closeOwner').onclick = ()=>ownerPanel.classList.remove('open');

async function refreshItems() {
  const res = await fetch('/api/items');
  const items = await res.json();
  document.getElementById('itemList').innerHTML = items.map(i=>i.name+' - '+i.price).join('<br>');
}

async function createItem() {
  const key = document.getElementById('ownerKey').value;
  const body = {
    name: document.getElementById('itemName').value,
    rarity: document.getElementById('itemRarity').value,
    attrs: {
      attack: Number(document.getElementById('itemAttack').value),
      defense: Number(document.getElementById('itemDefense').value),
      utility: Number(document.getElementById('itemUtility').value),
      requirement: Number(document.getElementById('itemRequirement').value)
    }
  };
  await fetch('/api/items', { method:'POST', headers:{'Content-Type':'application/json','x-owner-key':key}, body:JSON.stringify(body)});
  refreshItems();
}

document.getElementById('createItemBtn').onclick = createItem;
refreshItems();

fetch('/api/health').then(()=>{
  document.getElementById('status').innerText='Online';
});
