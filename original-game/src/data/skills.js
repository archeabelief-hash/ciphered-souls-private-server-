export const SKILLS = [
  { id: "bladework", name: "Bladework", group: "combat" },
  { id: "force", name: "Force", group: "combat" },
  { id: "ward", name: "Ward", group: "combat" },
  { id: "vitality", name: "Vitality", group: "combat" },
  { id: "marksmanship", name: "Marksmanship", group: "combat" },
  { id: "heka", name: "Heka", group: "combat" },
  { id: "reverence", name: "Reverence", group: "combat" },
  { id: "quarrying", name: "Quarrying", group: "gathering" },
  { id: "forging", name: "Forging", group: "artisan" },
  { id: "angling", name: "Angling", group: "gathering" },
  { id: "hearthcraft", name: "Hearthcraft", group: "artisan" },
  { id: "timbering", name: "Timbering", group: "gathering" },
  { id: "flamekeeping", name: "Flamekeeping", group: "artisan" },
  { id: "artifice", name: "Artifice", group: "artisan" },
  { id: "bowcraft", name: "Bowcraft", group: "artisan" },
  { id: "remedycraft", name: "Remedycraft", group: "artisan" },
  { id: "sigilcraft", name: "Sigilcraft", group: "mystic" },
  { id: "wayfaring", name: "Wayfaring", group: "world" },
  { id: "shadowcraft", name: "Shadowcraft", group: "world" },
  { id: "huntcraft", name: "Huntcraft", group: "gathering" },
  { id: "husbandry", name: "Husbandry", group: "gathering" },
  { id: "masonry", name: "Masonry", group: "artisan" },
  { id: "bountycraft", name: "Bountycraft", group: "combat" },
  { id: "seafaring", name: "Seafaring", group: "world" }
];

export function xpForLevel(level) {
  if (level <= 1) return 0;
  return Math.floor(72 * Math.pow(level - 1, 2.42));
}

export function levelForXp(xp) {
  let level = 1;
  while (level < 99 && xp >= xpForLevel(level + 1)) level++;
  return level;
}

export function createSkillState() {
  return Object.fromEntries(
    SKILLS.map((skill) => [skill.id, { xp: 0, level: 1 }])
  );
}
