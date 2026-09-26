export const EQUIPMENT_SLOTS = [
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

export const ITEMS = {
  ASH_BRONZE_KHOPESH: {
    id: 1001,
    name: "Ash-Bronze Khopesh",
    type: "weapon",
    equipSlot: "weapon",
    stackable: false,
    examine: "A forward-curved blade cast from ash-bronze.",
    attackSpeedTicks: 4,
    stats: { accuracy: 7, power: 8 }
  },
  VEILED_HOOD: {
    id: 1101,
    name: "Veiled Hood",
    type: "armor",
    equipSlot: "head",
    stackable: false,
    examine: "A simple hood worn by novice wayfarers.",
    stats: { armor: 4, heka: 2 }
  },
  WAYFARER_COAT: {
    id: 1102,
    name: "Wayfarer Coat",
    type: "armor",
    equipSlot: "body",
    stackable: false,
    examine: "Layered cloth reinforced for the road.",
    stats: { armor: 8, vitality: 4 }
  },
  WAYFARER_TROUSERS: {
    id: 1103,
    name: "Wayfarer Trousers",
    type: "armor",
    equipSlot: "legs",
    stackable: false,
    examine: "Hard-wearing travel clothes.",
    stats: { armor: 6, vitality: 2 }
  },
  DUSK_BOOTS: {
    id: 1104,
    name: "Dusk Boots",
    type: "armor",
    equipSlot: "feet",
    stackable: false,
    examine: "Soft leather boots darkened with ash.",
    stats: { armor: 3, accuracy: 1 }
  },
  SIGIL_CHARM: {
    id: 1105,
    name: "Sigil Charm",
    type: "armor",
    equipSlot: "neck",
    stackable: false,
    examine: "A carved charm used to focus Heka.",
    stats: { heka: 6, reverence: 2 }
  },
  REED_BUCKLER: {
    id: 1106,
    name: "Reed Buckler",
    type: "armor",
    equipSlot: "offhand",
    stackable: false,
    examine: "Layered reeds bound around a bronze boss.",
    stats: { armor: 5, ward: 4 }
  },
  ASHWOOD_LOG: {
    id: 2001,
    name: "Ashwood Log",
    type: "resource",
    stackable: false,
    examine: "Dense wood from an ashwood tree."
  },
  DUSK_ORE: {
    id: 2002,
    name: "Dusk Ore",
    type: "resource",
    stackable: false,
    examine: "Heavy ore with a violet-grey sheen."
  },
  RIVERFIN: {
    id: 2003,
    name: "Riverfin",
    type: "food",
    stackable: false,
    examine: "A small river fish. Restores vitality when prepared.",
    heal: 12
  },
  DUSK_MARK: {
    id: 3001,
    name: "Dusk Mark",
    type: "currency",
    stackable: true,
    examine: "A stamped trade token accepted across the Veiled March."
  }
};

export const ITEM_BY_ID = Object.fromEntries(
  Object.values(ITEMS).map((item) => [item.id, item])
);

export function cloneItem(item, amount = 1) {
  return { ...item, stats: item.stats ? { ...item.stats } : undefined, amount };
}

export function itemStatsText(item) {
  if (!item?.stats) return "";
  const labels = {
    accuracy: "Accuracy",
    power: "Power",
    armor: "Armor",
    heka: "Heka",
    marksmanship: "Marksmanship",
    reverence: "Reverence",
    vitality: "Vitality",
    ward: "Ward"
  };
  return Object.entries(item.stats)
    .filter(([, value]) => Number(value) !== 0)
    .map(([key, value]) => `${labels[key] || key} ${value > 0 ? "+" : ""}${value}`)
    .join(" · ");
}
