const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

const world = {
  tile: 48,
  cols: 28,
  rows: 18,
  cameraX: 0,
  cameraY: 0,
  time: 0,
  objects: [
    { x: 260, y: 180, type: 'forge' },
    { x: 620, y: 260, type: 'tree' },
    { x: 780, y: 430, type: 'ore' },
    { x: 420, y: 500, type: 'portal' },
    { x: 980, y: 210, type: 'ruin' }
  ]
};

let player = { x: 220, y: 220, vx: 0, vy: 0, hp: 100, cash: 0, facing: 1 };
let keys = {};

function resizeCanvas() {
  const box = canvas.getBoundingClientRect();
  canvas.width = Math.max(320, Math.floor(box.width * devicePixelRatio));
  canvas.height = Math.max(240, Math.floor(box.height * devicePixelRatio));
  ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
}
window.addEventListener('resize', resizeCanvas);
resizeCanvas();

function drawTile(x, y, colorA, colorB) {
  const sx = x - world.cameraX;
  const sy = y - world.cameraY;
  ctx.fillStyle = colorA;
  ctx.fillRect(sx, sy, world.tile, world.tile);
  ctx.strokeStyle = colorB;
  ctx.globalAlpha = 0.22;
  ctx.strokeRect(sx, sy, world.tile, world.tile);
  ctx.globalAlpha = 1;
}

function drawWorld() {
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  world.cameraX = player.x - w / 2;
  world.cameraY = player.y - h / 2;

  const startCol = Math.floor(world.cameraX / world.tile) - 1;
  const endCol = startCol + Math.ceil(w / world.tile) + 3;
  const startRow = Math.floor(world.cameraY / world.tile) - 1;
  const endRow = startRow + Math.ceil(h / world.tile) + 3;

  const grad = ctx.createLinearGradient(0, 0, 0, h);
  grad.addColorStop(0, '#13101a');
  grad.addColorStop(0.55, '#19150f');
  grad.addColorStop(1, '#09080b');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, w, h);

  for (let r = startRow; r <= endRow; r++) {
    for (let c = startCol; c <= endCol; c++) {
      const hash = Math.abs((c * 31 + r * 17) % 8);
      const base = hash < 2 ? '#1c1a1d' : hash < 5 ? '#211b16' : '#15191a';
      drawTile(c * world.tile, r * world.tile, base, '#36303a');
    }
  }

  ctx.fillStyle = 'rgba(120,80,40,.22)';
  for (let i = 0; i < 16; i++) {
    const x = ((i * 173) % 1300) - world.cameraX;
    const y = ((i * 97) % 850) - world.cameraY;
    ctx.beginPath(); ctx.ellipse(x, y, 60, 22, .2, 0, Math.PI * 2); ctx.fill();
  }
}

function drawObject(o) {
  const x = o.x - world.cameraX;
  const y = o.y - world.cameraY;
  if (o.type === 'forge') {
    ctx.fillStyle = '#3b3128'; ctx.fillRect(x-26, y-12, 52, 34);
    ctx.fillStyle = '#ff5d2a'; ctx.fillRect(x-18, y-5, 36, 14);
    ctx.fillStyle = '#ffd166'; ctx.fillRect(x-8, y-2, 16, 8);
  }
  if (o.type === 'tree') {
    ctx.fillStyle = '#5c3623'; ctx.fillRect(x-5, y-16, 10, 38);
    ctx.fillStyle = '#2f5f3d'; ctx.beginPath(); ctx.arc(x, y-24, 24, 0, Math.PI*2); ctx.fill();
  }
  if (o.type === 'ore') {
    ctx.fillStyle = '#3d434c'; ctx.beginPath(); ctx.moveTo(x-24,y+18); ctx.lineTo(x-6,y-22); ctx.lineTo(x+24,y+14); ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#8be9fd'; ctx.fillRect(x-5,y-4,10,8);
  }
  if (o.type === 'portal') {
    const pulse = Math.sin(world.time / 12) * 5;
    ctx.strokeStyle = '#8b5cf6'; ctx.lineWidth = 5;
    ctx.beginPath(); ctx.ellipse(x, y, 24 + pulse, 38 + pulse, 0, 0, Math.PI*2); ctx.stroke();
  }
  if (o.type === 'ruin') {
    ctx.fillStyle = '#5b5360'; ctx.fillRect(x-28,y-36,16,54); ctx.fillRect(x+14,y-30,16,48); ctx.fillRect(x-28,y-36,58,12);
  }
}

function drawPlayer() {
  const x = player.x - world.cameraX;
  const y = player.y - world.cameraY;
  ctx.shadowColor = '#b794f4'; ctx.shadowBlur = 20;
  ctx.fillStyle = '#101018'; ctx.fillRect(x-13, y-24, 26, 42);
  ctx.fillStyle = '#c7b8ff'; ctx.fillRect(x-9, y-20, 18, 14);
  ctx.fillStyle = '#6d28d9'; ctx.fillRect(x-16, y-8, 32, 26);
  ctx.fillStyle = '#e9d5ff'; ctx.fillRect(x + player.facing * 10, y-5, 6, 22);
  ctx.shadowBlur = 0;
}

function update() {
  world.time++;
  player.x += player.vx;
  player.y += player.vy;
  player.vx *= 0.82;
  player.vy *= 0.82;
  if (keys.ArrowUp || keys.w) player.vy -= 0.7;
  if (keys.ArrowDown || keys.s) player.vy += 0.7;
  if (keys.ArrowLeft || keys.a) { player.vx -= 0.7; player.facing = -1; }
  if (keys.ArrowRight || keys.d) { player.vx += 0.7; player.facing = 1; }
}

function draw() {
  update();
  drawWorld();
  world.objects.forEach(drawObject);
  drawPlayer();
  document.getElementById('hp').innerText = player.hp;
  document.getElementById('cash').innerText = player.cash;
  requestAnimationFrame(draw);
}
requestAnimationFrame(draw);

window.addEventListener('keydown', e => keys[e.key] = true);
window.addEventListener('keyup', e => keys[e.key] = false);

const joy = document.getElementById('joystick');
const stick = document.getElementById('stick');
let dragging = false;
joy.addEventListener('touchstart', e => { dragging = true; e.preventDefault(); }, { passive: false });
joy.addEventListener('touchend', e => { dragging = false; stick.style.transform = 'translate(0,0)'; e.preventDefault(); }, { passive: false });
joy.addEventListener('touchmove', e => {
  if(!dragging) return;
  const rect = joy.getBoundingClientRect();
  const t = e.touches[0];
  const dx = Math.max(-34, Math.min(34, t.clientX - rect.left - rect.width / 2));
  const dy = Math.max(-34, Math.min(34, t.clientY - rect.top - rect.height / 2));
  stick.style.transform = `translate(${dx}px,${dy}px)`;
  player.vx += dx * 0.018;
  player.vy += dy * 0.018;
  if (dx < -4) player.facing = -1;
  if (dx > 4) player.facing = 1;
  e.preventDefault();
}, { passive: false });

const ownerPanel = document.getElementById('ownerPanel');
document.getElementById('ownerToggle').onclick = ()=>ownerPanel.classList.add('open');
document.getElementById('closeOwner').onclick = ()=>ownerPanel.classList.remove('open');

async function refreshItems() {
  const res = await fetch('/api/items');
  const items = await res.json();
  document.getElementById('itemList').innerHTML = items.map(i=>`<div class="ownerItem"><b>${i.name}</b><span>${i.rarity}</span><em>${i.price} C$</em></div>`).join('') || '<p>No items created yet.</p>';
}

async function createItem() {
  const key = document.getElementById('ownerKey').value;
  const body = {
    name: document.getElementById('itemName').value || 'Unnamed Relic',
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
fetch('/api/health').then(()=>{ document.getElementById('status').innerText='Online'; });
