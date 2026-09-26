import { TILE_SIZE, MOVEMENT, tileKey, worldToTile, tileToWorld } from "../data/worldConstants.js";

const CARDINALS = [
  { x: 1, y: 0, cost: 10 },
  { x: -1, y: 0, cost: 10 },
  { x: 0, y: 1, cost: 10 },
  { x: 0, y: -1, cost: 10 }
];

const DIAGONALS = [
  { x: 1, y: 1, cost: 14 },
  { x: 1, y: -1, cost: 14 },
  { x: -1, y: 1, cost: 14 },
  { x: -1, y: -1, cost: 14 }
];

export class GridWorld {
  constructor(radius = 36) {
    this.radius = radius;
    this.blocked = new Set();
  }

  inBounds(x, y) {
    return x >= -this.radius && x <= this.radius && y >= -this.radius && y <= this.radius;
  }

  isBlocked(x, y) {
    return this.blocked.has(tileKey(x, y));
  }

  setBlocked(x, y, blocked = true) {
    const key = tileKey(x, y);
    if (blocked) this.blocked.add(key);
    else this.blocked.delete(key);
  }

  blockWorldPosition(x, z, radius = 0) {
    const tile = worldToTile(x, z);
    for (let ox = -radius; ox <= radius; ox++) {
      for (let oy = -radius; oy <= radius; oy++) {
        this.setBlocked(tile.x + ox, tile.y + oy, true);
      }
    }
  }

  neighbors(node) {
    const result = [];
    const dirs = MOVEMENT.allowDiagonal ? CARDINALS.concat(DIAGONALS) : CARDINALS;

    for (const dir of dirs) {
      const x = node.x + dir.x;
      const y = node.y + dir.y;
      if (!this.inBounds(x, y) || this.isBlocked(x, y)) continue;

      if (dir.x !== 0 && dir.y !== 0) {
        if (this.isBlocked(node.x + dir.x, node.y) || this.isBlocked(node.x, node.y + dir.y)) {
          continue;
        }
      }

      result.push({ x, y, cost: dir.cost });
    }

    return result;
  }

  heuristic(a, b) {
    const dx = Math.abs(a.x - b.x);
    const dy = Math.abs(a.y - b.y);
    const diagonal = Math.min(dx, dy);
    const straight = Math.max(dx, dy) - diagonal;
    return diagonal * 14 + straight * 10;
  }

  findPath(start, goal, maxVisited = 5000) {
    if (!this.inBounds(goal.x, goal.y)) return [];
    if (this.isBlocked(goal.x, goal.y)) return [];

    const startKey = tileKey(start.x, start.y);
    const goalKey = tileKey(goal.x, goal.y);
    if (startKey === goalKey) return [];

    const open = new Map();
    const closed = new Set();
    const parent = new Map();
    const gScore = new Map();

    open.set(startKey, {
      x: start.x,
      y: start.y,
      f: this.heuristic(start, goal)
    });
    gScore.set(startKey, 0);

    let visited = 0;

    while (open.size && visited++ < maxVisited) {
      let currentKey = null;
      let current = null;

      for (const [key, node] of open) {
        if (!current || node.f < current.f) {
          current = node;
          currentKey = key;
        }
      }

      if (!current) break;
      open.delete(currentKey);

      if (currentKey === goalKey) {
        return this.reconstruct(parent, currentKey)
          .slice(1)
          .map((tile) => ({
            ...tile,
            ...tileToWorld(tile.x, tile.y)
          }));
      }

      closed.add(currentKey);

      for (const next of this.neighbors(current)) {
        const nextKey = tileKey(next.x, next.y);
        if (closed.has(nextKey)) continue;

        const tentative = (gScore.get(currentKey) ?? Infinity) + next.cost;
        if (tentative >= (gScore.get(nextKey) ?? Infinity)) continue;

        parent.set(nextKey, currentKey);
        gScore.set(nextKey, tentative);
        open.set(nextKey, {
          x: next.x,
          y: next.y,
          f: tentative + this.heuristic(next, goal)
        });
      }
    }

    return [];
  }

  reconstruct(parent, endKey) {
    const path = [];
    let key = endKey;

    while (key) {
      const [x, y] = key.split(",").map(Number);
      path.push({ x, y });
      key = parent.get(key);
    }

    return path.reverse();
  }

  findAdjacentPath(start, target, range = 1) {
    if (range <= 0) {
      return this.findPath(start, target);
    }

    const candidates = [];

    for (let ox = -range; ox <= range; ox++) {
      for (let oy = -range; oy <= range; oy++) {
        if (ox === 0 && oy === 0) continue;
        const x = target.x + ox;
        const y = target.y + oy;
        if (!this.inBounds(x, y) || this.isBlocked(x, y)) continue;

        const path = this.findPath(start, { x, y });
        if (path.length || (start.x === x && start.y === y)) {
          candidates.push({ x, y, path });
        }
      }
    }

    candidates.sort((a, b) => a.path.length - b.path.length);
    return candidates.length ? candidates[0].path : [];
  }
}

export function tileDistance(a, b) {
  return Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
}

export { TILE_SIZE, worldToTile, tileToWorld };
