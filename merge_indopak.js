const fs = require('fs');
const path = require('path');

const projectRoot = __dirname;
const currentArabicPath = path.join(projectRoot, 'assets/data/quran/quran_arabic.json');
const indopakPath = path.join(process.env.HOME || '', 'Downloads/indopak-nastaleeq 2.json');
const outPath = path.join(projectRoot, 'assets/data/quran/quran_arabic.json');

const current = JSON.parse(fs.readFileSync(currentArabicPath, 'utf8'));
const indopak = JSON.parse(fs.readFileSync(indopakPath, 'utf8'));

const surahs = current.data?.surahs || [];
let replaced = 0;
for (const surah of surahs) {
  const sn = surah.number;
  for (const ayah of surah.ayahs || []) {
    const key = `${sn}:${ayah.numberInSurah}`;
    if (indopak[key]?.text) {
      ayah.text = indopak[key].text;
      replaced++;
    }
  }
}

fs.writeFileSync(outPath, JSON.stringify(current, null, 2), 'utf8');
console.log('Merged:', replaced, 'ayah texts from Indopak. Written to', outPath);
