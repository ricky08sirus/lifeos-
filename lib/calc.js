function bmi(weightKg, heightCm) {
  if (!weightKg || !heightCm) return null;
  const heightM = heightCm / 100;
  return +(weightKg / (heightM * heightM)).toFixed(1);
}

function weightTrend(entries, windowSize = 7) {
  // entries: array of { date, kg }, sorted newest-first
  if (entries.length === 0) return null;
  const recent = entries.slice(0, windowSize);
  const avg = recent.reduce((sum, e) => sum + e.kg, 0) / recent.length;
  return +avg.toFixed(1);
}

module.exports = { bmi, weightTrend };