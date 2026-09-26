import * as THREE from "three";
import { SKILLS, createSkillState, levelForXp } from "./data/skills.js";
import { EQUIPMENT_SLOTS, ITEMS, ITEM_BY_ID, cloneItem, itemStatsText } from "./data/items.js";

const TICK_MS = 600;
const WORLD_SIZE = 74;
const BAG_SLOTS = 28;
const BANK_SLOTS = 240;
const SAVE_KEY = "elderSoulsSaveV2";

export class ElderSoulsGame {
  constructor(root) {
    this.root = root;
    this.clock = new THREE.Clock();
    this.tickAccumulator = 0;
    this.keys = new Set();
    this.resources = [];
    this.npcs = [];
    this.clickables = [];
    this.selected = null;
    this.pendingAction = null;
    this.playerTarget = new THREE.Vector3(0, 0, 0);
    this.inventory = Array(BAG_SLOTS).fill(null);
    this.bank = Array(BANK_SLOTS).fill(null);
    this.equipment = Object.fromEntries(EQUIPMENT_SLOTS.map((slot) => [slot, null]));
    this.skills = createSkillState();
    this.maxHp = 100;
    this.hp = 100;
    this.state = { coins: 0, tick: 0 };
    this.bankOpen = false;
    this.selectedItem = null;
    this.loadedPosition = null;

    if (!this.loadGame()) {
      const starter = [
        ITEMS.ASH_BRONZE_KHOPESH,
        ITEMS.VEILED_HOOD,
        ITEMS.WAYFARER_COAT,
        ITEMS.WAYFARER_TROUSERS,
        ITEMS.DUSK_BOOTS,
        ITEMS.SIGIL_CHARM,
        ITEMS.REED_BUCKLER
      ];
      starter.forEach((item, index) => {
        this.inventory[index] = cloneItem(item, 1);
      });
      this.bank[0] = cloneItem(ITEMS.RIVERFIN, 8);
      this.bank[1] = cloneItem(ITEMS.ASHWOOD_LOG, 4);
      this.bank[2] = cloneItem(ITEMS.DUSK_ORE, 4);
      this.state.coins = 25;
    }
  }

  start() {
    this.buildUI();
    this.buildScene();
    this.bindEvents();

    if (this.loadedPosition) {
      this.player.position.set(this.loadedPosition.x || 0, 0, this.loadedPosition.z || 0);
      this.playerTarget.copy(this.player.position);
    }

    this.log("Welcome to Elder Souls.", "good");
    this.log("Your field bag, equipment, combat stats, bank vault, and persistent save are active.", "good");
    this.log("Click the bronze Veiled Vault near the starting ring to open your bank.");
    requestAnimationFrame(() => this.frame());
  }

  buildUI() {
    this.root.innerHTML = `
      <div class="game-shell">
        <canvas class="viewport"></canvas>
        <div class="topbar">
          <div class="brand">ELDER SOULS</div>
          <div class="subbrand">clean-room old-school fantasy prototype · v0.1</div>
        </div>
        <div class="help">LMB: move/interact · wheel: zoom · Q/E: rotate · WASD: pan camera</div>
        <section class="panel left-panel">
          <h2>Character</h2>
          <div id="character"></div>
          <h2>Skills</h2>
          <div id="skills"></div>
        </section>
        <section class="panel right-panel">
          <h2>Target</h2>
          <div id="target"></div>
          <h2>Inventory</h2>
          <div id="inventory"></div>
          <h2>Equipment</h2>
          <div id="equipment"></div>
        </section>
        <div id="log" class="log"></div>
      </div>
    `;
    this.canvas = this.root.querySelector(".viewport");
    this.ui = {
      character: this.root.querySelector("#character"),
      skills: this.root.querySelector("#skills"),
      target: this.root.querySelector("#target"),
      inventory: this.root.querySelector("#inventory"),
      equipment: this.root.querySelector("#equipment"),
      log: this.root.querySelector("#log")
    };
    this.renderUI();
  }

  buildScene() {
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x171b16);
    this.scene.fog = new THREE.Fog(0x171b16, 42, 105);

    this.camera = new THREE.PerspectiveCamera(42, 1, 0.1, 260);
    this.cameraAngle = Math.PI * 0.25;
    this.cameraDistance = 30;
    this.cameraHeight = 22;
    this.cameraFocus = new THREE.Vector3(0, 0, 0);

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: true
    });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    const hemi = new THREE.HemisphereLight(0xb9c0ad, 0x332819, 1.5);
    this.scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xffe1a1, 2.2);
    sun.position.set(-18, 34, 12);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.left = -44;
    sun.shadow.camera.right = 44;
    sun.shadow.camera.top = 44;
    sun.shadow.camera.bottom = -44;
    this.scene.add(sun);

    this.buildGround();
    this.player = this.createHumanoid(0x312820, 0xb69266, 0x17120f);
    this.player.position.set(0, 0, 0);
    this.scene.add(this.player);
    this.playerTarget.copy(this.player.position);

    this.spawnTree(-7, -2);
    this.spawnTree(-10, 5);
    this.spawnTree(8, 9);
    this.spawnTree(12, -5);
    this.spawnOre(6, -7);
    this.spawnOre(10, -10);
    this.spawnOre(-12, -9);
    this.spawnNpc("Dune Hound", 4, 6, 55, 3);
    this.spawnNpc("Marsh Wight", -4, 10, 75, 7);
    this.spawnNpc("Dust Jackal", 14, 4, 65, 5);
    this.spawnShrine(0, 14);

    this.raycaster = new THREE.Raycaster();
    this.pointer = new THREE.Vector2();
    this.updateCamera(true);
    this.resize();
  }

  buildGround() {
    const geometry = new THREE.PlaneGeometry(WORLD_SIZE, WORLD_SIZE, 38, 38);
    geometry.rotateX(-Math.PI / 2);
    const pos = geometry.attributes.position;
    const colors = [];
    const c1 = new THREE.Color(0x31402c);
    const c2 = new THREE.Color(0x4a4830);
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getZ(i);
      const h =
        Math.sin(x * 0.17) * 0.18 +
        Math.cos(z * 0.14) * 0.14 +
        Math.sin((x + z) * 0.09) * 0.10;
      pos.setY(i, h);
      const mix = Math.max(0, Math.min(1, (h + 0.35) / 0.7));
      const c = c1.clone().lerp(c2, mix);
      colors.push(c.r, c.g, c.b);
    }
    geometry.setAttribute("color", new THREE.Float32BufferAttribute(colors, 3));
    geometry.computeVertexNormals();
    const mat = new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true });
    this.ground = new THREE.Mesh(geometry, mat);
    this.ground.receiveShadow = true;
    this.ground.userData.ground = true;
    this.scene.add(this.ground);

    const ring = new THREE.Mesh(
      new THREE.RingGeometry(4.6, 4.95, 32),
      new THREE.MeshBasicMaterial({ color: 0x8d7447, side: THREE.DoubleSide })
    );
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.06;
    this.scene.add(ring);
  }

  createHumanoid(clothColor, skinColor, trimColor) {
    const root = new THREE.Group();
    const bodyMat = new THREE.MeshLambertMaterial({ color: clothColor, flatShading: true });
    const skinMat = new THREE.MeshLambertMaterial({ color: skinColor, flatShading: true });
    const trimMat = new THREE.MeshLambertMaterial({ color: trimColor, flatShading: true });

    const torso = new THREE.Mesh(new THREE.CylinderGeometry(0.55, 0.72, 1.35, 6), bodyMat);
    torso.position.y = 1.45;
    torso.castShadow = true;
    root.add(torso);

    const belt = new THREE.Mesh(new THREE.CylinderGeometry(0.68, 0.68, 0.18, 8), trimMat);
    belt.position.y = 0.83;
    root.add(belt);

    const head = new THREE.Mesh(new THREE.DodecahedronGeometry(0.43, 0), skinMat);
    head.position.y = 2.42;
    head.castShadow = true;
    root.add(head);

    for (const side of [-1, 1]) {
      const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.18, 1.05, 6), bodyMat);
      arm.position.set(side * 0.72, 1.42, 0);
      arm.rotation.z = side * 0.13;
      arm.castShadow = true;
      root.add(arm);

      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.19, 0.24, 1.1, 6), trimMat);
      leg.position.set(side * 0.28, 0.15, 0);
      leg.castShadow = true;
      root.add(leg);
    }

    root.userData.kind = "player";
    return root;
  }

  spawnTree(x, z) {
    const group = new THREE.Group();
    const trunk = new THREE.Mesh(
      new THREE.CylinderGeometry(0.38, 0.55, 3.2, 7),
      new THREE.MeshLambertMaterial({ color: 0x5a3c24, flatShading: true })
    );
    trunk.position.y = 1.6;
    trunk.castShadow = true;
    group.add(trunk);
    const crownMat = new THREE.MeshLambertMaterial({ color: 0x42502f, flatShading: true });
    for (let i = 0; i < 3; i++) {
      const crown = new THREE.Mesh(new THREE.IcosahedronGeometry(1.35 - i * 0.13, 0), crownMat);
      crown.position.set((i - 1) * 0.45, 3.4 + (i % 2) * 0.42, (i % 2 ? 0.35 : -0.25));
      crown.castShadow = true;
      group.add(crown);
    }
    group.position.set(x, 0, z);
    group.userData.entity = {
      kind: "resource",
      resourceType: "tree",
      name: "Ashwood Tree",
      skill: "timbering",
      xp: 18,
      item: ITEMS.ASHWOOD_LOG,
      hp: 3,
      maxHp: 3,
      respawnTicks: 12,
      active: true,
      group
    };
    this.resources.push(group.userData.entity);
    this.clickables.push(group);
    this.scene.add(group);
  }

  spawnOre(x, z) {
    const mesh = new THREE.Mesh(
      new THREE.DodecahedronGeometry(1.0, 0),
      new THREE.MeshLambertMaterial({ color: 0x50545d, flatShading: true })
    );
    mesh.scale.set(1.25, 0.8, 1.0);
    mesh.position.set(x, 0.65, z);
    mesh.castShadow = true;
    mesh.userData.entity = {
      kind: "resource",
      resourceType: "ore",
      name: "Dusk Ore Vein",
      skill: "quarrying",
      xp: 22,
      item: ITEMS.DUSK_ORE,
      hp: 4,
      maxHp: 4,
      respawnTicks: 16,
      active: true,
      group: mesh
    };
    this.resources.push(mesh.userData.entity);
    this.clickables.push(mesh);
    this.scene.add(mesh);
  }

  spawnShrine(x, z) {
    const group = new THREE.Group();
    const base = new THREE.Mesh(
      new THREE.CylinderGeometry(1.2, 1.5, 0.45, 8),
      new THREE.MeshLambertMaterial({ color: 0x3e3934, flatShading: true })
    );
    base.position.y = 0.22;
    group.add(base);
    const obelisk = new THREE.Mesh(
      new THREE.CylinderGeometry(0.35, 0.6, 3.6, 5),
      new THREE.MeshLambertMaterial({ color: 0x161517, emissive: 0x24184a, flatShading: true })
    );
    obelisk.position.y = 2.0;
    group.add(obelisk);
    const glow = new THREE.PointLight(0x8566cc, 2.5, 8);
    glow.position.y = 2.8;
    group.add(glow);
    group.position.set(x, 0, z);
    group.userData.entity = { kind: "shrine", name: "Veiled Shrine", group };
    this.clickables.push(group);
    this.scene.add(group);
  }

  spawnNpc(name, x, z, hp, combatLevel) {
    const group = this.createHumanoid(0x4a3a33, 0x7f6859, 0x251f1c);
    group.scale.setScalar(0.9);
    group.position.set(x, 0, z);
    group.userData.entity = {
      kind: "npc",
      name,
      hp,
      maxHp: hp,
      combatLevel,
      alive: true,
      group,
      attackCooldown: 0,
      respawnTicks: 0,
      home: new THREE.Vector3(x, 0, z)
    };
    this.npcs.push(group.userData.entity);
    this.clickables.push(group);
    this.scene.add(group);
  }

  bindEvents() {
    window.addEventListener("resize", () => this.resize());
    window.addEventListener("keydown", (e) => this.keys.add(e.key.toLowerCase()));
    window.addEventListener("keyup", (e) => this.keys.delete(e.key.toLowerCase()));
    this.canvas.addEventListener("wheel", (e) => {
      e.preventDefault();
      this.cameraDistance = THREE.MathUtils.clamp(this.cameraDistance + e.deltaY * 0.015, 14, 48);
    }, { passive: false });
    this.canvas.addEventListener("pointerdown", (e) => this.onPointer(e));
    this.ui.inventory.addEventListener("click", (e) => {
      const row = e.target.closest("[data-inventory-index]");
      if (!row) return;
      const index = Number(row.dataset.inventoryIndex);
      const item = this.inventory[index];
      if (!item) return;
      if (item.type === "weapon") {
        this.equipment.weapon = item;
        this.inventory.splice(index, 1);
        this.log(`You wield the ${item.name}.`, "good");
        this.renderUI();
      }
    });
  }

  onPointer(event) {
    const rect = this.canvas.getBoundingClientRect();
    this.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    this.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    this.raycaster.setFromCamera(this.pointer, this.camera);

    const hits = this.raycaster.intersectObjects(this.clickables, true);
    if (hits.length) {
      let obj = hits[0].object;
      while (obj && !obj.userData.entity) obj = obj.parent;
      if (obj?.userData.entity) {
        this.chooseEntity(obj.userData.entity);
        return;
      }
    }

    const groundHit = this.raycaster.intersectObject(this.ground, false)[0];
    if (groundHit) {
      this.pendingAction = null;
      this.selected = null;
      this.playerTarget.copy(groundHit.point);
      this.playerTarget.y = 0;
      this.log(`Walking to ${this.playerTarget.x.toFixed(1)}, ${this.playerTarget.z.toFixed(1)}.`);
      this.renderUI();
    }
  }

  chooseEntity(entity) {
    this.selected = entity;
    const target = entity.group.position;
    const dist = this.distance2D(this.player.position, target);
    if (dist > 2.4) {
      this.playerTarget.copy(target);
      this.playerTarget.y = 0;
      this.pendingAction = entity;
      this.log(`Approaching ${entity.name}.`);
    } else {
      this.beginInteraction(entity);
    }
    this.renderUI();
  }

  beginInteraction(entity) {
    if (entity.kind === "resource") {
      if (!entity.active) {
        this.log(`${entity.name} is depleted.`, "bad");
        return;
      }
      this.pendingAction = entity;
      this.log(`You begin working the ${entity.name}.`);
    } else if (entity.kind === "npc") {
      if (!entity.alive) {
        this.log(`${entity.name} is already down.`);
        return;
      }
      this.pendingAction = entity;
      this.log(`You engage ${entity.name}.`);
    } else if (entity.kind === "shrine") {
      this.pendingAction = null;
      this.hp = this.maxHp;
      this.addXp("reverence", 10);
      this.log("The Veiled Shrine restores your vitality.", "good");
    }
  }

  frame(now) {
    const dt = Math.min(0.05, this.clock.getDelta());
    this.updatePlayer(dt);
    this.updateCamera(false, dt);

    this.tickAccumulator += dt * 1000;
    while (this.tickAccumulator >= TICK_MS) {
      this.tickAccumulator -= TICK_MS;
      this.tick();
    }

    this.renderer.render(this.scene, this.camera);
    requestAnimationFrame((t) => this.frame(t));
  }

  tick() {
    this.state.tick++;
    this.processActionTick();
    this.processNpcTick();
    this.processRespawns();
    this.renderUI();
  }

  updatePlayer(dt) {
    const delta = this.playerTarget.clone().sub(this.player.position);
    delta.y = 0;
    const dist = delta.length();
    if (dist > 0.08) {
      const step = Math.min(dist, 4.0 * dt);
      delta.normalize();
      this.player.position.addScaledVector(delta, step);
      this.player.rotation.y = Math.atan2(delta.x, delta.z);
    } else if (this.pendingAction) {
      const target = this.pendingAction.group.position;
      if (this.distance2D(this.player.position, target) <= 2.5) {
        this.beginInteraction(this.pendingAction);
      }
    }
  }

  updateCamera(force = false, dt = 0.016) {
    if (this.keys.has("q")) this.cameraAngle -= 1.2 * dt;
    if (this.keys.has("e")) this.cameraAngle += 1.2 * dt;

    const pan = new THREE.Vector3();
    if (this.keys.has("w")) pan.z -= 1;
    if (this.keys.has("s")) pan.z += 1;
    if (this.keys.has("a")) pan.x -= 1;
    if (this.keys.has("d")) pan.x += 1;
    if (pan.lengthSq() > 0) {
      pan.normalize().multiplyScalar(8 * dt);
      this.cameraFocus.add(pan);
    } else {
      this.cameraFocus.lerp(this.player.position, force ? 1 : 0.045);
    }

    this.camera.position.set(
      this.cameraFocus.x + Math.sin(this.cameraAngle) * this.cameraDistance,
      this.cameraHeight + this.cameraDistance * 0.18,
      this.cameraFocus.z + Math.cos(this.cameraAngle) * this.cameraDistance
    );
    this.camera.lookAt(this.cameraFocus.x, 1.0, this.cameraFocus.z);
  }

  processActionTick() {
    const action = this.pendingAction;
    if (!action) return;
    if (this.distance2D(this.player.position, action.group.position) > 2.6) return;

    if (action.kind === "resource") {
      if (!action.active) {
        this.pendingAction = null;
        return;
      }
      action.hp--;
      this.log(`You work the ${action.name}.`);
      if (action.hp <= 0) {
        action.active = false;
        action.group.visible = false;
        action.respawnTicksLeft = action.respawnTicks;
        this.addItem(action.item, 1);
        this.addXp(action.skill, action.xp);
        this.log(`You gather 1 × ${action.item.name}.`, "good");
        this.pendingAction = null;
      }
      return;
    }

    if (action.kind === "npc") {
      if (!action.alive) {
        this.pendingAction = null;
        return;
      }
      const weaponBonus = this.equipment.weapon ? 4 : 0;
      const attack = this.skills.bladework.level + weaponBonus;
      const force = this.skills.force.level + weaponBonus;
      const damage = Math.max(1, Math.floor(Math.random() * (3 + force * 0.8 + attack * 0.25)));
      action.hp = Math.max(0, action.hp - damage);
      this.addXp("bladework", damage * 1.2);
      this.addXp("force", damage * 1.1);
      this.addXp("vitality", damage * 0.45);
      this.log(`You strike ${action.name} for ${damage}.`, "xp");

      if (action.hp <= 0) {
        action.alive = false;
        action.group.visible = false;
        action.respawnTicks = 16;
        this.addXp("bountycraft", Math.max(5, action.combatLevel * 2));
        this.state.coins += 3 + action.combatLevel;
        this.log(`${action.name} falls. You recover ${3 + action.combatLevel} dusk marks.`, "good");
        this.pendingAction = null;
      }
    }
  }

  processNpcTick() {
    for (const npc of this.npcs) {
      if (!npc.alive) continue;
      if (this.pendingAction !== npc) continue;
      if (this.distance2D(this.player.position, npc.group.position) > 2.8) continue;
      const ward = this.skills.ward.level;
      const max = Math.max(1, Math.floor(2 + npc.combatLevel * 0.65 - ward * 0.15));
      const damage = Math.floor(Math.random() * (max + 1));
      if (damage > 0) {
        this.hp = Math.max(0, this.hp - damage);
        this.log(`${npc.name} hits you for ${damage}.`, "bad");
      }
      if (this.hp <= 0) {
        this.log("You collapse. The shrine recalls your soul.", "bad");
        this.hp = this.maxHp;
        this.player.position.set(0, 0, 0);
        this.playerTarget.set(0, 0, 0);
        this.pendingAction = null;
        this.selected = null;
      }
    }
  }

  processRespawns() {
    for (const resource of this.resources) {
      if (resource.active) continue;
      resource.respawnTicksLeft--;
      if (resource.respawnTicksLeft <= 0) {
        resource.active = true;
        resource.hp = resource.maxHp;
        resource.group.visible = true;
      }
    }
    for (const npc of this.npcs) {
      if (npc.alive) continue;
      npc.respawnTicks--;
      if (npc.respawnTicks <= 0) {
        npc.alive = true;
        npc.hp = npc.maxHp;
        npc.group.position.copy(npc.home);
        npc.group.visible = true;
      }
    }
  }

  addItem(base, amount) {
    const existing = this.inventory.find((i) => i.id === base.id);
    if (existing) existing.amount += amount;
    else this.inventory.push({ ...base, amount });
  }

  addXp(skillId, amount) {
    const skill = this.skills[skillId];
    if (!skill) return;
    const oldLevel = skill.level;
    skill.xp += amount;
    skill.level = levelForXp(skill.xp);
    if (skill.level > oldLevel) {
      const name = SKILLS.find((s) => s.id === skillId)?.name ?? skillId;
      this.log(`${name} rises to level ${skill.level}.`, "xp");
    }
  }

  distance2D(a, b) {
    const dx = a.x - b.x;
    const dz = a.z - b.z;
    return Math.hypot(dx, dz);
  }

  renderUI() {
    if (!this.ui) return;

    const hpPct = Math.max(0, Math.min(100, (this.hp / this.maxHp) * 100));
    this.ui.character.innerHTML = `
      <div class="stat-row"><b>Vitality</b> ${this.hp}/${this.maxHp}
        <div class="hpbar"><div style="width:${hpPct}%"></div></div>
      </div>
      <div class="stat-row"><b>Dusk marks</b> ${this.state.coins}</div>
      <div class="stat-row"><b>Position</b> ${this.player ? this.player.position.x.toFixed(1) : "0.0"}, ${this.player ? this.player.position.z.toFixed(1) : "0.0"}</div>
    `;

    this.ui.skills.innerHTML = SKILLS.map((s) => {
      const state = this.skills[s.id];
      return `<div class="skill-row"><span>${s.name}<div class="small">${Math.floor(state.xp)} xp</div></span><b>${state.level}</b></div>`;
    }).join("");

    if (!this.selected) {
      this.ui.target.innerHTML = '<div class="target-card small">Nothing selected.</div>';
    } else if (this.selected.kind === "npc") {
      this.ui.target.innerHTML = `
        <div class="target-card"><b>${this.selected.name}</b>
          <div>Combat ${this.selected.combatLevel}</div>
          <div>HP ${this.selected.hp}/${this.selected.maxHp}</div>
        </div>
      `;
    } else {
      this.ui.target.innerHTML = `<div class="target-card"><b>${this.selected.name}</b><div class="small">${this.selected.kind}</div></div>`;
    }

    this.ui.inventory.innerHTML = this.inventory.length
      ? this.inventory.map((item, index) => `<div class="inventory-row" data-inventory-index="${index}"><b>${item.name}</b> × ${item.amount}<div class="small">${item.type === "weapon" ? "click to wield" : item.type}</div></div>`).join("")
      : '<div class="small">Empty.</div>';

    this.ui.equipment.innerHTML = this.equipment.weapon
      ? `<div class="inventory-row"><b>Weapon:</b> ${this.equipment.weapon.name}</div>`
      : '<div class="small">No weapon equipped.</div>';
  }

  log(message, tone = "") {
    if (!this.ui?.log) return;
    const row = document.createElement("div");
    row.className = `log-entry ${tone}`;
    row.textContent = `[${String(this.state.tick).padStart(4, "0")}] ${message}`;
    this.ui.log.appendChild(row);
    while (this.ui.log.children.length > 60) this.ui.log.firstChild.remove();
    this.ui.log.scrollTop = this.ui.log.scrollHeight;
  }

  resize() {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / Math.max(1, h);
    this.camera.updateProjectionMatrix();
  }
}
