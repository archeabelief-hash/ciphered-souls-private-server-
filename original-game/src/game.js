import * as THREE from "three";
import { SKILLS, createSkillState, levelForXp } from "./data/skills.js";
import { EQUIPMENT_SLOTS, ITEMS, ITEM_BY_ID, cloneItem, itemStatsText } from "./data/items.js";

const TICK_MS = 600;
const WORLD_SIZE = 74;
const BAG_SLOTS = 36;
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
    this.log("Your 36-slot field bag, equipment, combat stats, bank vault, and persistent save are active.", "good");
    this.log("Click the bronze Veiled Vault near the starting ring to open your bank.");
    requestAnimationFrame(() => this.frame());
  }

  buildUI() {
    this.root.innerHTML = [
      '<div class="game-shell">',
      '<canvas class="viewport"></canvas>',
      '<div class="topbar"><div class="brand">ELDER SOULS</div><div class="subbrand">original old-school fantasy RPG</div></div>',
      '<div class="help">LMB: move/interact · wheel: zoom · Q/E: rotate · WASD: pan camera</div>',
      '<section class="panel left-panel">',
      '<h2>Character</h2><div id="character"></div>',
      '<h2>Combat Stats</h2><div id="combat-stats"></div>',
      '<h2>Skills</h2><div id="skills"></div>',
      '</section>',
      '<section class="panel right-panel">',
      '<h2>Target</h2><div id="target"></div>',
      '<h2>Field Bag <span class="small" id="bag-count"></span></h2>',
      '<div id="inventory" class="slot-grid bag-grid"></div>',
      '<h2>Item</h2><div id="item-detail" class="item-detail small">Select an item to inspect it.</div>',
      '<h2>Equipment</h2><div id="equipment" class="equipment-grid"></div>',
      '</section>',
      '<div id="log" class="log"></div>',
      '<div id="bank-modal" class="bank-modal hidden">',
      '<div class="bank-window">',
      '<div class="bank-header"><div><div class="bank-title">VEILED VAULT</div><div class="small">Personal bank · ' + BANK_SLOTS + ' slots</div></div><button id="bank-close" class="es-button">Close</button></div>',
      '<div class="bank-toolbar"><button id="bank-deposit-all" class="es-button">Deposit Bag</button><button id="bank-deposit-equipment" class="es-button">Deposit Equipment</button><div class="small bank-hint">Click = 1 · Shift-click = all</div></div>',
      '<div class="bank-layout">',
      '<div><h3>Vault</h3><div id="bank-grid" class="slot-grid bank-grid"></div></div>',
      '<div><h3>Field Bag</h3><div id="bank-bag-grid" class="slot-grid bag-grid"></div></div>',
      '</div></div></div></div>'
    ].join("");

    this.canvas = this.root.querySelector(".viewport");
    this.ui = {
      character: this.root.querySelector("#character"),
      combatStats: this.root.querySelector("#combat-stats"),
      skills: this.root.querySelector("#skills"),
      target: this.root.querySelector("#target"),
      inventory: this.root.querySelector("#inventory"),
      bagCount: this.root.querySelector("#bag-count"),
      itemDetail: this.root.querySelector("#item-detail"),
      equipment: this.root.querySelector("#equipment"),
      log: this.root.querySelector("#log"),
      bankModal: this.root.querySelector("#bank-modal"),
      bankGrid: this.root.querySelector("#bank-grid"),
      bankBagGrid: this.root.querySelector("#bank-bag-grid"),
      bankClose: this.root.querySelector("#bank-close"),
      bankDepositAll: this.root.querySelector("#bank-deposit-all"),
      bankDepositEquipment: this.root.querySelector("#bank-deposit-equipment")
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
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.08;

    const hemi = new THREE.HemisphereLight(0xc9d4c5, 0x2b2118, 1.7);
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
    this.refreshPlayerEquipmentVisuals();

    this.spawnBankVault(-4, -4);
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

    const clothMat = new THREE.MeshStandardMaterial({
      color: clothColor,
      roughness: 0.78,
      metalness: 0.02
    });
    const skinMat = new THREE.MeshStandardMaterial({
      color: skinColor,
      roughness: 0.72,
      metalness: 0
    });
    const trimMat = new THREE.MeshStandardMaterial({
      color: trimColor,
      roughness: 0.72,
      metalness: 0.05
    });
    const darkMat = new THREE.MeshStandardMaterial({
      color: 0x17130f,
      roughness: 0.66,
      metalness: 0.08
    });
    const eyeMat = new THREE.MeshStandardMaterial({
      color: 0x201810,
      roughness: 0.35
    });

    const body = new THREE.Group();
    root.add(body);

    const torso = new THREE.Mesh(
      new THREE.CylinderGeometry(0.52, 0.66, 1.18, 12),
      clothMat
    );
    torso.position.y = 1.55;
    torso.castShadow = true;
    body.add(torso);

    const shoulders = new THREE.Mesh(
      new THREE.CapsuleGeometry(0.24, 1.05, 5, 10),
      clothMat
    );
    shoulders.rotation.z = Math.PI / 2;
    shoulders.position.y = 1.92;
    shoulders.scale.z = 0.9;
    shoulders.castShadow = true;
    body.add(shoulders);

    const belt = new THREE.Mesh(
      new THREE.CylinderGeometry(0.65, 0.65, 0.16, 12),
      trimMat
    );
    belt.position.y = 0.98;
    belt.castShadow = true;
    body.add(belt);

    const neck = new THREE.Mesh(
      new THREE.CylinderGeometry(0.18, 0.20, 0.24, 10),
      skinMat
    );
    neck.position.y = 2.18;
    neck.castShadow = true;
    body.add(neck);

    const head = new THREE.Mesh(
      new THREE.SphereGeometry(0.43, 16, 12),
      skinMat
    );
    head.scale.set(0.92, 1.10, 0.90);
    head.position.y = 2.56;
    head.castShadow = true;
    body.add(head);

    const nose = new THREE.Mesh(
      new THREE.ConeGeometry(0.08, 0.18, 7),
      skinMat
    );
    nose.rotation.x = Math.PI / 2;
    nose.position.set(0, 2.56, 0.40);
    nose.castShadow = true;
    body.add(nose);

    for (const side of [-1, 1]) {
      const eye = new THREE.Mesh(
        new THREE.SphereGeometry(0.038, 8, 6),
        eyeMat
      );
      eye.position.set(side * 0.145, 2.66, 0.36);
      body.add(eye);
    }

    const leftArmPivot = new THREE.Group();
    const rightArmPivot = new THREE.Group();
    leftArmPivot.position.set(-0.66, 1.88, 0);
    rightArmPivot.position.set(0.66, 1.88, 0);
    body.add(leftArmPivot, rightArmPivot);

    for (const [pivot, side] of [[leftArmPivot, -1], [rightArmPivot, 1]]) {
      const upper = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.13, 0.48, 4, 8),
        clothMat
      );
      upper.position.y = -0.33;
      upper.rotation.z = side * 0.08;
      upper.castShadow = true;
      pivot.add(upper);

      const forearm = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.115, 0.43, 4, 8),
        skinMat
      );
      forearm.position.y = -0.92;
      forearm.castShadow = true;
      pivot.add(forearm);

      const hand = new THREE.Mesh(
        new THREE.SphereGeometry(0.14, 10, 8),
        skinMat
      );
      hand.scale.set(0.88, 1.05, 0.82);
      hand.position.y = -1.28;
      hand.castShadow = true;
      pivot.add(hand);
    }

    const leftLegPivot = new THREE.Group();
    const rightLegPivot = new THREE.Group();
    leftLegPivot.position.set(-0.28, 0.94, 0);
    rightLegPivot.position.set(0.28, 0.94, 0);
    body.add(leftLegPivot, rightLegPivot);

    for (const pivot of [leftLegPivot, rightLegPivot]) {
      const thigh = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.16, 0.46, 4, 8),
        trimMat
      );
      thigh.position.y = -0.36;
      thigh.castShadow = true;
      pivot.add(thigh);

      const shin = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.14, 0.44, 4, 8),
        trimMat
      );
      shin.position.y = -0.92;
      shin.castShadow = true;
      pivot.add(shin);

      const foot = new THREE.Mesh(
        new THREE.BoxGeometry(0.34, 0.22, 0.58),
        darkMat
      );
      foot.position.set(0, -1.30, 0.11);
      foot.castShadow = true;
      pivot.add(foot);
    }

    const attachments = {};
    const attachmentNames = [
      "head",
      "cape",
      "neck",
      "weapon",
      "body",
      "offhand",
      "legs",
      "hands",
      "feet",
      "ring"
    ];

    for (const name of attachmentNames) {
      const group = new THREE.Group();
      attachments[name] = group;
      body.add(group);
    }

    attachments.weapon.position.set(0.76, 0.67, 0.04);
    attachments.offhand.position.set(-0.78, 0.72, 0.02);
    attachments.head.position.set(0, 2.56, 0);
    attachments.body.position.set(0, 1.52, 0);
    attachments.legs.position.set(0, 0.55, 0);
    attachments.feet.position.set(0, -0.25, 0.10);
    attachments.neck.position.set(0, 2.14, 0.34);
    attachments.cape.position.set(0, 1.58, -0.40);
    attachments.hands.position.set(0, 0.62, 0);
    attachments.ring.position.set(0.83, 0.63, 0.08);

    root.userData.kind = "humanoid";
    root.userData.visuals = {
      body,
      torso,
      head,
      leftArmPivot,
      rightArmPivot,
      leftLegPivot,
      rightLegPivot,
      attachments
    };

    return root;
  }

  clearVisualGroup(group) {
    if (!group) return;
    while (group.children.length) {
      const child = group.children.pop();
      child.traverse((node) => {
        if (node.geometry) node.geometry.dispose();
        if (node.material) {
          if (Array.isArray(node.material)) {
            node.material.forEach((material) => material.dispose());
          } else {
            node.material.dispose();
          }
        }
      });
    }
  }

  gearMaterial(color, metalness = 0.25, roughness = 0.48) {
    return new THREE.MeshStandardMaterial({
      color,
      metalness,
      roughness
    });
  }

  refreshPlayerEquipmentVisuals() {
    const visuals = this.player && this.player.userData && this.player.userData.visuals;
    if (!visuals || !visuals.attachments) return;

    for (const group of Object.values(visuals.attachments)) {
      this.clearVisualGroup(group);
    }

    for (const [slot, item] of Object.entries(this.equipment)) {
      if (!item) continue;
      this.addEquipmentVisual(slot, item, visuals.attachments[slot]);
    }
  }

  addEquipmentVisual(slot, item, group) {
    if (!group) return;

    const bronze = this.gearMaterial(0xa66a32, 0.62, 0.34);
    const darkBronze = this.gearMaterial(0x68421f, 0.58, 0.40);
    const leather = this.gearMaterial(0x30241b, 0.06, 0.82);
    const cloth = this.gearMaterial(0x25212d, 0.03, 0.86);
    const dusk = this.gearMaterial(0x1a1820, 0.12, 0.64);
    const pale = this.gearMaterial(0xb9a27c, 0.18, 0.55);
    const violet = this.gearMaterial(0x493d69, 0.18, 0.48);

    const cast = (mesh) => {
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      return mesh;
    };

    if (slot === "weapon") {
      const weapon = new THREE.Group();

      const grip = cast(new THREE.Mesh(
        new THREE.CylinderGeometry(0.055, 0.065, 0.48, 10),
        leather
      ));
      grip.position.y = 0.16;
      weapon.add(grip);

      const pommel = cast(new THREE.Mesh(
        new THREE.SphereGeometry(0.09, 10, 8),
        darkBronze
      ));
      pommel.position.y = -0.11;
      weapon.add(pommel);

      const guard = cast(new THREE.Mesh(
        new THREE.BoxGeometry(0.34, 0.07, 0.09),
        bronze
      ));
      guard.position.y = 0.43;
      weapon.add(guard);

      const blade = cast(new THREE.Mesh(
        new THREE.BoxGeometry(0.12, 1.20, 0.055),
        bronze
      ));
      blade.position.set(0, 1.02, 0);
      blade.rotation.z = -0.07;
      weapon.add(blade);

      const curve = cast(new THREE.Mesh(
        new THREE.TorusGeometry(0.28, 0.06, 8, 16, Math.PI * 0.72),
        bronze
      ));
      curve.position.set(0.16, 1.62, 0);
      curve.rotation.z = Math.PI * 0.08;
      weapon.add(curve);

      const edge = cast(new THREE.Mesh(
        new THREE.BoxGeometry(0.045, 0.86, 0.065),
        pale
      ));
      edge.position.set(0.065, 1.07, 0.035);
      edge.rotation.z = -0.07;
      weapon.add(edge);

      weapon.rotation.z = -0.12;
      weapon.rotation.x = 0.06;
      group.add(weapon);
      return;
    }

    if (slot === "offhand") {
      const shield = new THREE.Group();

      const disc = cast(new THREE.Mesh(
        new THREE.CylinderGeometry(0.43, 0.43, 0.12, 18),
        leather
      ));
      disc.rotation.x = Math.PI / 2;
      shield.add(disc);

      const rim = cast(new THREE.Mesh(
        new THREE.TorusGeometry(0.43, 0.055, 8, 20),
        bronze
      ));
      shield.add(rim);

      const boss = cast(new THREE.Mesh(
        new THREE.SphereGeometry(0.15, 12, 8),
        darkBronze
      ));
      boss.scale.z = 0.55;
      boss.position.z = 0.07;
      shield.add(boss);

      shield.rotation.y = -0.14;
      group.add(shield);
      return;
    }

    if (slot === "head") {
      const hood = cast(new THREE.Mesh(
        new THREE.SphereGeometry(0.50, 18, 14, 0, Math.PI * 2, 0, Math.PI * 0.78),
        cloth
      ));
      hood.scale.set(0.96, 1.06, 0.95);
      hood.position.y = 0.03;
      group.add(hood);

      const brow = cast(new THREE.Mesh(
        new THREE.TorusGeometry(0.39, 0.035, 7, 18, Math.PI),
        violet
      ));
      brow.rotation.z = Math.PI;
      brow.rotation.x = Math.PI / 2;
      brow.position.set(0, 0.02, 0.32);
      group.add(brow);
      return;
    }

    if (slot === "body") {
      const chest = cast(new THREE.Mesh(
        new THREE.CylinderGeometry(0.57, 0.72, 1.12, 14),
        cloth
      ));
      chest.position.y = 0.02;
      group.add(chest);

      const collar = cast(new THREE.Mesh(
        new THREE.TorusGeometry(0.38, 0.055, 8, 18),
        darkBronze
      ));
      collar.rotation.x = Math.PI / 2;
      collar.position.set(0, 0.52, 0.02);
      group.add(collar);

      for (const side of [-1, 1]) {
        const plate = cast(new THREE.Mesh(
          new THREE.SphereGeometry(0.20, 12, 8),
          darkBronze
        ));
        plate.scale.set(1.25, 0.55, 0.75);
        plate.position.set(side * 0.62, 0.43, 0);
        group.add(plate);
      }
      return;
    }

    if (slot === "legs") {
      for (const side of [-1, 1]) {
        const leg = cast(new THREE.Mesh(
          new THREE.CapsuleGeometry(0.19, 0.76, 4, 10),
          cloth
        ));
        leg.position.set(side * 0.28, 0.03, 0.01);
        group.add(leg);

        const knee = cast(new THREE.Mesh(
          new THREE.SphereGeometry(0.19, 10, 8),
          darkBronze
        ));
        knee.scale.set(0.95, 0.62, 0.66);
        knee.position.set(side * 0.28, -0.20, 0.15);
        group.add(knee);
      }
      return;
    }

    if (slot === "feet") {
      for (const side of [-1, 1]) {
        const boot = cast(new THREE.Mesh(
          new THREE.BoxGeometry(0.38, 0.30, 0.68),
          leather
        ));
        boot.position.set(side * 0.28, 0, 0.08);
        group.add(boot);

        const toe = cast(new THREE.Mesh(
          new THREE.BoxGeometry(0.34, 0.11, 0.24),
          darkBronze
        ));
        toe.position.set(side * 0.28, 0.02, 0.39);
        group.add(toe);
      }
      return;
    }

    if (slot === "neck") {
      const chain = cast(new THREE.Mesh(
        new THREE.TorusGeometry(0.16, 0.018, 7, 18),
        bronze
      ));
      chain.scale.y = 1.25;
      group.add(chain);

      const charm = cast(new THREE.Mesh(
        new THREE.OctahedronGeometry(0.09, 0),
        violet
      ));
      charm.position.y = -0.18;
      group.add(charm);
      return;
    }

    if (slot === "cape") {
      const cape = cast(new THREE.Mesh(
        new THREE.PlaneGeometry(1.15, 1.85, 4, 6),
        new THREE.MeshStandardMaterial({
          color: 0x302742,
          roughness: 0.88,
          metalness: 0,
          side: THREE.DoubleSide
        })
      ));
      cape.position.y = -0.08;
      cape.rotation.x = -0.08;
      group.add(cape);
      return;
    }

    if (slot === "hands") {
      for (const side of [-1, 1]) {
        const glove = cast(new THREE.Mesh(
          new THREE.SphereGeometry(0.17, 10, 8),
          leather
        ));
        glove.scale.set(0.9, 1.0, 0.82);
        glove.position.set(side * 0.76, 0, 0);
        group.add(glove);
      }
      return;
    }

    if (slot === "ring") {
      const ring = cast(new THREE.Mesh(
        new THREE.TorusGeometry(0.07, 0.018, 6, 14),
        bronze
      ));
      ring.rotation.x = Math.PI / 2;
      group.add(ring);
    }
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

  spawnBankVault(x, z) {
    const group = new THREE.Group();

    const base = new THREE.Mesh(
      new THREE.BoxGeometry(2.7, 1.15, 1.9),
      new THREE.MeshLambertMaterial({ color: 0x3a2b1d, flatShading: true })
    );
    base.position.y = 0.58;
    base.castShadow = true;
    group.add(base);

    const lid = new THREE.Mesh(
      new THREE.BoxGeometry(2.85, 0.35, 2.05),
      new THREE.MeshLambertMaterial({ color: 0x5d4326, flatShading: true })
    );
    lid.position.y = 1.28;
    lid.castShadow = true;
    group.add(lid);

    const lock = new THREE.Mesh(
      new THREE.BoxGeometry(0.45, 0.52, 0.18),
      new THREE.MeshLambertMaterial({ color: 0xb38b47, emissive: 0x211200, flatShading: true })
    );
    lock.position.set(0, 0.93, 1.04);
    group.add(lock);

    group.position.set(x, 0, z);
    group.userData.entity = {
      kind: "bank",
      name: "Veiled Vault",
      group
    };

    this.clickables.push(group);
    this.scene.add(group);
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
    window.addEventListener("keydown", (event) => {
      this.keys.add(event.key.toLowerCase());
      if (event.key === "Escape" && this.bankOpen) this.closeBank();
    });
    window.addEventListener("keyup", (event) => this.keys.delete(event.key.toLowerCase()));
    window.addEventListener("beforeunload", () => this.saveGame());

    this.canvas.addEventListener("wheel", (event) => {
      event.preventDefault();
      this.cameraDistance = THREE.MathUtils.clamp(this.cameraDistance + event.deltaY * 0.015, 14, 48);
    }, { passive: false });

    this.canvas.addEventListener("pointerdown", (event) => this.onPointer(event));

    this.ui.inventory.addEventListener("click", (event) => {
      const slot = event.target.closest("[data-bag-slot]");
      if (!slot) return;
      this.selectBagItem(Number(slot.dataset.bagSlot));
    });

    this.ui.inventory.addEventListener("dblclick", (event) => {
      const slot = event.target.closest("[data-bag-slot]");
      if (!slot) return;
      this.quickUseBagItem(Number(slot.dataset.bagSlot));
    });

    this.ui.equipment.addEventListener("click", (event) => {
      const slot = event.target.closest("[data-equipment-slot]");
      if (!slot) return;
      this.selectEquipmentItem(slot.dataset.equipmentSlot);
    });

    this.ui.itemDetail.addEventListener("click", (event) => {
      const action = event.target.closest("[data-item-action]");
      if (!action) return;
      this.handleItemAction(action.dataset.itemAction);
    });

    this.ui.bankClose.addEventListener("click", () => this.closeBank());
    this.ui.bankDepositAll.addEventListener("click", () => this.depositBag());
    this.ui.bankDepositEquipment.addEventListener("click", () => this.depositEquipment());

    this.ui.bankGrid.addEventListener("click", (event) => {
      const slot = event.target.closest("[data-bank-slot]");
      if (!slot) return;
      this.withdrawBankItem(Number(slot.dataset.bankSlot), event.shiftKey);
    });

    this.ui.bankBagGrid.addEventListener("click", (event) => {
      const slot = event.target.closest("[data-bank-bag-slot]");
      if (!slot) return;
      this.depositBagSlot(Number(slot.dataset.bankBagSlot), event.shiftKey);
    });
  }

  onPointer(event) {
    if (this.bankOpen) return;
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
      this.saveGame();
    } else if (entity.kind === "bank") {
      this.pendingAction = null;
      this.openBank();
    }
  }

  frame() {
    const dt = Math.min(0.05, this.clock.getDelta());

    if (!this.bankOpen) {
      this.updatePlayer(dt);
      this.updateCamera(false, dt);
    }

    this.tickAccumulator += dt * 1000;
    while (this.tickAccumulator >= TICK_MS) {
      this.tickAccumulator -= TICK_MS;
      this.tick();
    }

    this.renderer.render(this.scene, this.camera);
    requestAnimationFrame(() => this.frame());
  }

  tick() {
    this.state.tick++;

    if (!this.bankOpen) {
      this.processActionTick();
      this.processNpcTick();
      this.processRespawns();
    }

    if (this.state.tick % 10 === 0) this.saveGame();
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
        const stored = this.addItem(action.item, 1);
        if (stored) {
          this.addXp(action.skill, action.xp);
          this.log("You gather 1 × " + action.item.name + ".", "good");
        } else {
          this.log("Your field bag is full.", "bad");
        }
        this.pendingAction = null;
      }
      return;
    }

    if (action.kind === "npc") {
      if (!action.alive) {
        this.pendingAction = null;
        return;
      }
      const totals = this.getEquipmentStats();
      const attack = this.skills.bladework.level + totals.accuracy;
      const force = this.skills.force.level + totals.power;
      const maxHit = Math.max(2, Math.floor(2 + force * 0.72 + attack * 0.2));
      const damage = Math.max(1, Math.floor(Math.random() * (maxHit + 1)));
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
      const totals = this.getEquipmentStats();
      const ward = this.skills.ward.level;
      const mitigation = Math.floor((totals.armor + totals.ward + ward) / 8);
      const rawMax = Math.max(1, Math.floor(2 + npc.combatLevel * 0.65));
      const max = Math.max(1, rawMax - mitigation);
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

  selectBagItem(index) {
    const item = this.inventory[index];
    this.selectedItem = item ? { source: "bag", index, item } : null;
    this.renderItemDetail();
  }

  selectEquipmentItem(slot) {
    const item = this.equipment[slot];
    this.selectedItem = item ? { source: "equipment", slot, item } : null;
    this.renderItemDetail();
  }

  quickUseBagItem(index) {
    const item = this.inventory[index];
    if (!item) return;
    if (item.equipSlot) {
      this.equipFromInventory(index);
      return;
    }
    if (item.type === "food") this.consumeFood(index);
  }

  handleItemAction(action) {
    if (!this.selectedItem) return;
    const selected = this.selectedItem;

    if (action === "equip" && selected.source === "bag") {
      this.equipFromInventory(selected.index);
      return;
    }
    if (action === "consume" && selected.source === "bag") {
      this.consumeFood(selected.index);
      return;
    }
    if (action === "unequip" && selected.source === "equipment") {
      this.unequip(selected.slot);
      return;
    }
    if (action === "examine") {
      this.log(selected.item.examine || "You find nothing unusual.");
    }
  }

  equipFromInventory(index) {
    const item = this.inventory[index];
    if (!item || !item.equipSlot) return;

    const slot = item.equipSlot;
    const previous = this.equipment[slot];

    this.equipment[slot] = item;
    this.inventory[index] = previous || null;
    this.selectedItem = { source: "equipment", slot, item };

    this.log("You equip the " + item.name + ".", "good");
    this.saveGame();
    this.renderUI();
  }

  unequip(slot) {
    const item = this.equipment[slot];
    if (!item) return;

    const free = this.findFreeInventorySlot();
    if (free < 0) {
      this.log("Your field bag is full.", "bad");
      return;
    }

    this.inventory[free] = item;
    this.equipment[slot] = null;
    this.selectedItem = { source: "bag", index: free, item };

    this.log("You remove the " + item.name + ".");
    this.saveGame();
    this.renderUI();
  }

  consumeFood(index) {
    const item = this.inventory[index];
    if (!item || item.type !== "food") return;

    const before = this.hp;
    this.hp = Math.min(this.getDisplayedMaxHp(), this.hp + Number(item.heal || 0));
    this.removeInventoryAmount(index, 1);

    this.log("You consume the " + item.name + " and restore " + (this.hp - before) + " vitality.", "good");
    this.selectedItem = null;
    this.saveGame();
    this.renderUI();
  }

  getEquipmentStats() {
    const totals = {
      accuracy: 0,
      power: 0,
      armor: 0,
      heka: 0,
      marksmanship: 0,
      reverence: 0,
      vitality: 0,
      ward: 0
    };

    for (const item of Object.values(this.equipment)) {
      if (!item || !item.stats) continue;
      for (const [key, value] of Object.entries(item.stats)) {
        totals[key] = (totals[key] || 0) + Number(value || 0);
      }
    }
    return totals;
  }

  getDisplayedMaxHp() {
    return this.maxHp + Number(this.getEquipmentStats().vitality || 0);
  }

  getCombatRating() {
    const totals = this.getEquipmentStats();
    const levelTotal =
      this.skills.bladework.level +
      this.skills.force.level +
      this.skills.ward.level +
      this.skills.vitality.level +
      this.skills.marksmanship.level +
      this.skills.heka.level;

    const gear =
      totals.accuracy +
      totals.power +
      totals.armor +
      totals.heka +
      totals.marksmanship +
      totals.ward;

    return Math.max(1, Math.floor(levelTotal / 6 + gear / 12));
  }

  openBank() {
    this.bankOpen = true;
    this.ui.bankModal.classList.remove("hidden");
    this.log("You open your Veiled Vault.", "good");
    this.renderBank();
  }

  closeBank() {
    this.bankOpen = false;
    this.ui.bankModal.classList.add("hidden");
    this.saveGame();
  }

  depositBagSlot(index, all = false) {
    const item = this.inventory[index];
    if (!item) return;

    const amount = all ? item.amount : 1;
    if (!this.addBankItem(item, amount)) {
      this.log("Your vault is full.", "bad");
      return;
    }

    this.removeInventoryAmount(index, amount);
    this.selectedItem = null;
    this.saveGame();
    this.renderUI();
    this.renderBank();
  }

  withdrawBankItem(index, all = false) {
    const item = this.bank[index];
    if (!item) return;

    const amount = all ? item.amount : 1;
    let moved = 0;

    if (item.stackable) {
      if (this.addItem(item, amount)) moved = amount;
    } else {
      for (let i = 0; i < amount; i++) {
        if (!this.addItem(item, 1)) break;
        moved++;
      }
    }

    if (moved <= 0) {
      this.log("Your field bag is full.", "bad");
      return;
    }

    this.removeBankAmount(index, moved);
    this.saveGame();
    this.renderUI();
    this.renderBank();
  }

  depositBag() {
    for (let index = 0; index < this.inventory.length; index++) {
      const item = this.inventory[index];
      if (!item) continue;
      const amount = item.amount;
      if (this.addBankItem(item, amount)) this.inventory[index] = null;
    }

    this.selectedItem = null;
    this.log("You deposit your field bag.", "good");
    this.saveGame();
    this.renderUI();
    this.renderBank();
  }

  depositEquipment() {
    for (const slot of EQUIPMENT_SLOTS) {
      const item = this.equipment[slot];
      if (!item) continue;
      if (this.addBankItem(item, item.amount || 1)) this.equipment[slot] = null;
    }

    this.selectedItem = null;
    this.log("You deposit your equipped items.", "good");
    this.saveGame();
    this.renderUI();
    this.renderBank();
  }

  addBankItem(base, amount) {
    const template = ITEM_BY_ID[base.id] || base;

    if (template.stackable) {
      const existing = this.bank.find((item) => item && item.id === template.id);
      if (existing) {
        existing.amount += amount;
        return true;
      }

      const free = this.findFreeBankSlot();
      if (free < 0) return false;
      this.bank[free] = cloneItem(template, amount);
      return true;
    }

    const freeSlots = [];
    for (let i = 0; i < this.bank.length && freeSlots.length < amount; i++) {
      if (!this.bank[i]) freeSlots.push(i);
    }
    if (freeSlots.length < amount) return false;

    freeSlots.forEach((slot) => {
      this.bank[slot] = cloneItem(template, 1);
    });
    return true;
  }

  addItem(base, amount) {
    const template = ITEM_BY_ID[base.id] || base;

    if (template.stackable) {
      const existing = this.inventory.find((item) => item && item.id === template.id);
      if (existing) {
        existing.amount += amount;
        return true;
      }

      const free = this.findFreeInventorySlot();
      if (free < 0) return false;
      this.inventory[free] = cloneItem(template, amount);
      return true;
    }

    const freeSlots = [];
    for (let i = 0; i < this.inventory.length && freeSlots.length < amount; i++) {
      if (!this.inventory[i]) freeSlots.push(i);
    }
    if (freeSlots.length < amount) return false;

    freeSlots.forEach((slot) => {
      this.inventory[slot] = cloneItem(template, 1);
    });
    return true;
  }

  removeInventoryAmount(index, amount) {
    const item = this.inventory[index];
    if (!item) return;
    if (item.amount > amount) item.amount -= amount;
    else this.inventory[index] = null;
  }

  removeBankAmount(index, amount) {
    const item = this.bank[index];
    if (!item) return;
    if (item.amount > amount) item.amount -= amount;
    else this.bank[index] = null;
  }

  findFreeInventorySlot() {
    return this.inventory.findIndex((item) => !item);
  }

  findFreeBankSlot() {
    return this.bank.findIndex((item) => !item);
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

  saveGame() {
    try {
      const data = {
        version: 2,
        hp: this.hp,
        maxHp: this.maxHp,
        state: {
          coins: this.state.coins,
          tick: this.state.tick
        },
        skills: this.skills,
        inventory: this.inventory.map((item) => item ? { id: item.id, amount: item.amount } : null),
        bank: this.bank.map((item) => item ? { id: item.id, amount: item.amount } : null),
        equipment: Object.fromEntries(
          EQUIPMENT_SLOTS.map((slot) => [
            slot,
            this.equipment[slot] ? { id: this.equipment[slot].id, amount: this.equipment[slot].amount } : null
          ])
        ),
        position: this.player
          ? { x: this.player.position.x, z: this.player.position.z }
          : (this.loadedPosition || { x: 0, z: 0 })
      };

      localStorage.setItem(SAVE_KEY, JSON.stringify(data));
      return true;
    } catch (error) {
      console.error("Save failed", error);
      return false;
    }
  }

  loadGame() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return false;

      const data = JSON.parse(raw);
      if (!data || data.version !== 2) return false;

      this.hp = Number(data.hp || 100);
      this.maxHp = Number(data.maxHp || 100);
      this.state = {
        coins: Number(data.state && data.state.coins || 0),
        tick: Number(data.state && data.state.tick || 0)
      };

      const freshSkills = createSkillState();
      for (const skill of SKILLS) {
        const saved = data.skills && data.skills[skill.id];
        if (!saved) continue;
        freshSkills[skill.id] = {
          xp: Number(saved.xp || 0),
          level: Number(saved.level || 1)
        };
      }
      this.skills = freshSkills;

      this.inventory = Array(BAG_SLOTS).fill(null).map((_, index) =>
        this.hydrateItem(data.inventory && data.inventory[index])
      );

      this.bank = Array(BANK_SLOTS).fill(null).map((_, index) =>
        this.hydrateItem(data.bank && data.bank[index])
      );

      this.equipment = Object.fromEntries(
        EQUIPMENT_SLOTS.map((slot) => [
          slot,
          this.hydrateItem(data.equipment && data.equipment[slot])
        ])
      );

      this.loadedPosition = data.position || { x: 0, z: 0 };
      return true;
    } catch (error) {
      console.error("Load failed", error);
      return false;
    }
  }

  hydrateItem(saved) {
    if (!saved) return null;
    const template = ITEM_BY_ID[Number(saved.id)];
    if (!template) return null;
    return cloneItem(template, Math.max(1, Number(saved.amount || 1)));
  }

  escapeHtml(value) {
    return String(value == null ? "" : value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  itemGlyph(item) {
    const words = item.name.split(/\s+/).filter(Boolean);
    if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
    return words.slice(0, 2).map((word) => word[0]).join("").toUpperCase();
  }

  combatStat(label, value) {
    const number = Number(value || 0);
    return '<div class="combat-stat"><span>' + this.escapeHtml(label) + '</span><b>' +
      (number >= 0 ? "+" : "") + number + '</b></div>';
  }

  renderSlotGrid(items, dataName) {
    return items.map((item, index) => {
      const title = item
        ? item.name + (itemStatsText(item) ? " · " + itemStatsText(item) : "")
        : "Empty slot";

      let body = "";
      if (item) {
        body += '<span class="item-glyph">' + this.escapeHtml(this.itemGlyph(item)) + '</span>';
        if (item.amount > 1) {
          body += '<span class="item-amount">' + item.amount + '</span>';
        }
      }

      return '<button class="item-slot ' + (item ? "filled" : "") +
        '" data-' + dataName + '="' + index +
        '" title="' + this.escapeHtml(title) + '">' + body + '</button>';
    }).join("");
  }

  renderItemDetail() {
    if (!this.ui || !this.ui.itemDetail) return;

    const selected = this.selectedItem;
    if (!selected || !selected.item) {
      this.ui.itemDetail.innerHTML = "Select an item to inspect it.";
      return;
    }

    const item = selected.item;
    const stats = itemStatsText(item);
    const actions = [];

    if (selected.source === "bag" && item.equipSlot) {
      actions.push('<button class="es-button" data-item-action="equip">Equip</button>');
    }
    if (selected.source === "bag" && item.type === "food") {
      actions.push('<button class="es-button" data-item-action="consume">Consume</button>');
    }
    if (selected.source === "equipment") {
      actions.push('<button class="es-button" data-item-action="unequip">Remove</button>');
    }
    actions.push('<button class="es-button" data-item-action="examine">Examine</button>');

    this.ui.itemDetail.innerHTML =
      '<div class="item-name">' + this.escapeHtml(item.name) + '</div>' +
      '<div>' + this.escapeHtml(item.examine || "") + '</div>' +
      (item.equipSlot ? '<div class="item-line"><b>Slot:</b> ' + this.escapeHtml(item.equipSlot) + '</div>' : "") +
      (stats ? '<div class="item-stats">' + this.escapeHtml(stats) + '</div>' : "") +
      '<div class="item-actions">' + actions.join("") + '</div>';
  }

  renderBank() {
    if (!this.ui || !this.bankOpen) return;
    this.ui.bankGrid.innerHTML = this.renderSlotGrid(this.bank, "bank-slot");
    this.ui.bankBagGrid.innerHTML = this.renderSlotGrid(this.inventory, "bank-bag-slot");
  }

  renderUI() {
    if (!this.ui) return;

    const totals = this.getEquipmentStats();
    const displayedMaxHp = this.getDisplayedMaxHp();
    if (this.hp > displayedMaxHp) this.hp = displayedMaxHp;
    const hpPct = Math.max(0, Math.min(100, (this.hp / displayedMaxHp) * 100));

    this.ui.character.innerHTML =
      '<div class="stat-row"><b>Vitality</b> ' + this.hp + '/' + displayedMaxHp +
      '<div class="hpbar"><div style="width:' + hpPct + '%"></div></div></div>' +
      '<div class="stat-row"><b>Combat rating</b> ' + this.getCombatRating() + '</div>' +
      '<div class="stat-row"><b>Dusk marks</b> ' + this.state.coins + '</div>' +
      '<div class="stat-row"><b>Position</b> ' +
      (this.player ? this.player.position.x.toFixed(1) : "0.0") + ', ' +
      (this.player ? this.player.position.z.toFixed(1) : "0.0") + '</div>';

    this.ui.combatStats.innerHTML =
      '<div class="combat-stat-grid">' +
      this.combatStat("Accuracy", totals.accuracy) +
      this.combatStat("Power", totals.power) +
      this.combatStat("Armor", totals.armor) +
      this.combatStat("Ward", totals.ward) +
      this.combatStat("Heka", totals.heka) +
      this.combatStat("Marksman", totals.marksmanship) +
      this.combatStat("Reverence", totals.reverence) +
      this.combatStat("Vitality", totals.vitality) +
      '</div>';

    this.ui.skills.innerHTML = SKILLS.map((skill) => {
      const state = this.skills[skill.id];
      return '<div class="skill-row"><span>' + this.escapeHtml(skill.name) +
        '<div class="small">' + Math.floor(state.xp) + ' xp</div></span><b>' +
        state.level + '</b></div>';
    }).join("");

    if (!this.selected) {
      this.ui.target.innerHTML = '<div class="target-card small">Nothing selected.</div>';
    } else if (this.selected.kind === "npc") {
      this.ui.target.innerHTML =
        '<div class="target-card"><b>' + this.escapeHtml(this.selected.name) + '</b>' +
        '<div>Combat ' + this.selected.combatLevel + '</div>' +
        '<div>HP ' + this.selected.hp + '/' + this.selected.maxHp + '</div></div>';
    } else {
      this.ui.target.innerHTML =
        '<div class="target-card"><b>' + this.escapeHtml(this.selected.name) + '</b>' +
        '<div class="small">' + this.escapeHtml(this.selected.kind) + '</div></div>';
    }

    const used = this.inventory.filter(Boolean).length;
    this.ui.bagCount.textContent = used + "/" + BAG_SLOTS;
    this.ui.inventory.innerHTML = this.renderSlotGrid(this.inventory, "bag-slot");

    this.ui.equipment.innerHTML = EQUIPMENT_SLOTS.map((slot) => {
      const item = this.equipment[slot];
      return '<button class="equipment-slot ' + (item ? "filled" : "") +
        '" data-equipment-slot="' + slot +
        '" title="' + this.escapeHtml(item ? item.name : slot) + '">' +
        '<span class="slot-label">' + this.escapeHtml(slot) + '</span>' +
        (item ? '<strong>' + this.escapeHtml(this.itemGlyph(item)) + '</strong>' : "") +
        '</button>';
    }).join("");

    this.renderItemDetail();
    if (this.bankOpen) this.renderBank();
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
