const fs = require('fs');
const path = require('path');

const jsonPath = path.join(__dirname, '../assets/data/quran/quran_arabic.json');
const raw = fs.readFileSync(jsonPath, 'utf8');
const data = JSON.parse(raw);
const surahs = data.data?.surahs || [];

// Build list of all ayahs with (juz, surahNumber, surahEnglishName, numberInSurah)
const ayahList = [];
for (const s of surahs) {
  const sn = s.number;
  const name = s.englishName || '';
  for (const a of s.ayahs || []) {
    ayahList.push({
      juz: a.juz,
      surahNumber: sn,
      surahEnglishName: name,
      numberInSurah: a.numberInSurah,
    });
  }
}

// For each juz 1-30, find first and last ayah
const juzBounds = {};
for (let j = 1; j <= 30; j++) {
  const inJuz = ayahList.filter((a) => a.juz === j);
  if (inJuz.length === 0) continue;
  const first = inJuz[0];
  const last = inJuz[inJuz.length - 1];
  juzBounds[j] = {
    start: { surah: first.surahNumber, ayah: first.numberInSurah, name: first.surahEnglishName },
    end: { surah: last.surahNumber, ayah: last.numberInSurah, name: last.surahEnglishName },
  };
}

console.log('Juz | Start | End');
console.log('--- | ----- | ---');
for (let j = 1; j <= 30; j++) {
  const b = juzBounds[j];
  if (!b) {
    console.log(`${j} | (no data) | (no data)`);
    continue;
  }
  const startStr = `${b.start.name} **${b.start.surah}:${b.start.ayah}**`;
  const endStr = `${b.end.name} **${b.end.surah}:${b.end.ayah}**`;
  console.log(`**${j}** | ${startStr} | ${endStr}`);
}
