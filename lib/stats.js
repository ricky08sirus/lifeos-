// Simple in-memory hit counter. For a single-server setup this is fine;
// if you ever scale to multiple server instances, move this to Redis instead.
const hitCounts = new Map();

function incrementHitCount(method, path) {
  const key = `${method} ${path}`;
  hitCounts.set(key, (hitCounts.get(key) || 0) + 1);
}

function getStats() {
  return Object.fromEntries(
    [...hitCounts.entries()].sort((a, b) => b[1] - a[1]) // busiest endpoints first
  );
}

module.exports = { incrementHitCount, getStats };