export const WORLD_TICK_MS = 600;
export const TILE_SIZE = 1;
export const WALK_TILES_PER_TICK = 1;
export const RUN_TILES_PER_TICK = 2;

export const CAMERA = {
  pitch: 0.93,
  yaw: Math.PI * 0.25,
  distance: 26,
  height: 19,
  minDistance: 13,
  maxDistance: 44
};

export const MOVEMENT = {
  allowDiagonal: true,
  snapTolerance: 0.04
};

export function tileKey(x, y) {
  return `${x},${y}`;
}

export function worldToTile(x, z) {
  return {
    x: Math.round(x / TILE_SIZE),
    y: Math.round(z / TILE_SIZE)
  };
}

export function tileToWorld(x, y) {
  return {
    x: x * TILE_SIZE,
    z: y * TILE_SIZE
  };
}
