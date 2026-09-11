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


function trainingVolume(sets) {
  // excludes warmup sets, per your spec doc
  return sets
    .filter((s) => s.kind !== 'warmup' && s.completed)
    .reduce((total, s) => total + (s.weightKg || 0) * (s.reps || 0), 0);
}

function estimatedOneRepMax(weightKg, reps) {
  if (!weightKg || !reps) return null;
  // Epley formula
  return +(weightKg * (1 + reps / 30)).toFixed(1);
}

function trainingAdherence(planned, completed) {
  if (!planned) return null;
  return +((completed / planned) * 100).toFixed(1);
}

module.exports = { bmi, weightTrend, trainingVolume, estimatedOneRepMax, trainingAdherence };




