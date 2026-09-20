// Simple Pearson correlation, adapted from your frontend's ACALC.pearson
function pearsonCorrelation(pairs) {
  const n = pairs.length;
  if (n < 5) return null; // too few points to mean anything
  const xs = pairs.map((p) => p[0]);
  const ys = pairs.map((p) => p[1]);
  const mx = xs.reduce((a, b) => a + b, 0) / n;
  const my = ys.reduce((a, b) => a + b, 0) / n;
  let num = 0, sxx = 0, syy = 0;
  for (let i = 0; i < n; i++) {
    const dx = xs[i] - mx, dy = ys[i] - my;
    num += dx * dy; sxx += dx * dx; syy += dy * dy;
  }
  if (sxx === 0 || syy === 0) return null;
  return +(num / Math.sqrt(sxx * syy)).toFixed(3);
}

function alignByDate(seriesA, seriesB) {
  const mapB = new Map(seriesB.map((p) => [p.date, p.value]));
  const pairs = [];
  for (const p of seriesA) {
    const match = mapB.get(p.date);
    if (match !== undefined) pairs.push([p.value, match]);
  }
  return pairs;
}

module.exports = { pearsonCorrelation, alignByDate };