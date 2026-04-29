function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }

function powerScore(attrs) {
  const atk = (attrs.attack || 0) * (attrs.speed || 1);
  const def = (attrs.defense || 0);
  const util = (attrs.utility || 0);
  const req = (attrs.requirement || 1);
  const dura = (attrs.durability || 1);
  const repairPenalty = (attrs.repairCost || 0) * -0.5;
  const score = atk * 1.2 + def * 1.0 + util * 0.6 + dura * 0.4 + repairPenalty + req * 0.3;
  return Math.max(0, score);
}

function suggestedPrice(attrs, rarity, scarcity) {
  rarity = rarity || 'COMMON';
  scarcity = scarcity || 1;
  const ips = powerScore(attrs);
  const alpha = 1.25;
  const K = 10;
  const base = K * Math.pow(ips + 1, alpha);
  const rarityMul = ({COMMON:1, UNCOMMON:1.2, RARE:1.6, EPIC:2.2, LEGENDARY:3.5})[rarity] || 1;
  const scarcityMul = clamp(scarcity, 0.5, 5);
  return Math.round(base * rarityMul * scarcityMul);
}

module.exports = { powerScore, suggestedPrice };
