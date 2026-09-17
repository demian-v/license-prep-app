/**
 * LOCAL TOOLING — put placeholder images into the Storage emulator.
 *
 * The content export (export-content.js) copies Firestore documents only. The
 * actual picture files live in production Cloud Storage, and this machine has no
 * credential to read them (ADC is revoked on purpose), so every theory section
 * and quiz question that references an image renders "Image unavailable"
 * locally. That is an empty local bucket, not an app bug — production is fine.
 *
 * This generates one hazard-striped PNG per referenced path so the screens can
 * be exercised: layout, sizing, and "is the right image requested for the right
 * question" are all testable. The base colour is derived from the path, so two
 * different images are visibly different and a wrong-image bug would still show.
 * The stripes are the point: nothing in the real content looks like this, so a
 * placeholder is never mistaken for a diagram.
 *
 * Refuses to run outside the emulator.
 *
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
 *   node scripts/local/seed-emulator-images.js
 */
const zlib = require('zlib');
const admin = require('../../functions/node_modules/firebase-admin');

const LOCAL = /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/;
if (!LOCAL.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIRESTORE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}
if (!LOCAL.test(process.env.FIREBASE_STORAGE_EMULATOR_HOST || '')) {
  console.error('REFUSING: FIREBASE_STORAGE_EMULATOR_HOST is not a local address.');
  process.exit(1);
}

const BUCKET = process.env.STORAGE_BUCKET || 'licenseprepapp.firebasestorage.app';
const WIDTH = 800;
const HEIGHT = 450;

// --- minimal PNG writer (no image library needed) -------------------------
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

// A flat rectangle was the first attempt and it was a mistake: a plain coloured
// block reads as a diagram and the owner reasonably asked what it meant. These
// are now hazard-striped, which no real content in this app looks like, so
// nobody has to wonder whether the picture is meaningful.
function placeholderPng(width, height, [r, g, b]) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // colour type: truecolour
  // 10..12 stay 0: deflate, adaptive filtering, no interlace

  const dark = [Math.max(0, r - 55), Math.max(0, g - 55), Math.max(0, b - 55)];
  const STRIPE = 28; // px, measured diagonally
  const BORDER = 10;

  const rows = [];
  for (let y = 0; y < height; y++) {
    const row = Buffer.alloc(1 + width * 3); // leading filter byte 0
    for (let x = 0; x < width; x++) {
      const onBorder =
        y < BORDER || y >= height - BORDER || x < BORDER || x >= width - BORDER;
      const onStripe = Math.floor((x + y) / STRIPE) % 2 === 0;
      const [pr, pg, pb] = onBorder || onStripe ? dark : [r, g, b];
      row[1 + x * 3] = pr;
      row[2 + x * 3] = pg;
      row[3 + x * 3] = pb;
    }
    rows.push(row);
  }

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(Buffer.concat(rows))),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function colourFor(path) {
  let h = 0;
  for (let i = 0; i < path.length; i++) h = (h * 31 + path.charCodeAt(i)) >>> 0;
  // pale, so the dark stripes carry the contrast
  return [180 + (h % 60), 180 + ((h >> 8) % 60), 180 + ((h >> 16) % 60)];
}
// -------------------------------------------------------------------------

admin.initializeApp({
  projectId: process.env.GCLOUD_PROJECT || 'licenseprepapp',
  storageBucket: BUCKET,
});
const db = admin.firestore();
const bucket = admin.storage().bucket();

async function collectPaths() {
  const theory = new Set();
  const quiz = new Set();

  for (const name of ['trafficRuleTopics', 'theoryModules']) {
    const snap = await db.collection(name).get();
    snap.forEach((doc) => {
      for (const section of doc.data().sections || []) {
        if (section && section.imagePath) theory.add(section.imagePath);
      }
    });
  }

  const questions = await db.collection('quizQuestions').get();
  questions.forEach((doc) => {
    const data = doc.data();
    for (const key of ['imagePath', 'image', 'imageUrl']) {
      if (data[key]) quiz.add(data[key]);
    }
  });

  return [
    ...[...theory].map((p) => `theory_images/${p}`),
    ...[...quiz].map((p) => `quiz_images/${p}`),
  ];
}

(async () => {
  const paths = await collectPaths();
  console.log(`Seeding ${paths.length} placeholder images into ${BUCKET}`);

  let written = 0;
  for (const path of paths) {
    await bucket.file(path).save(placeholderPng(WIDTH, HEIGHT, colourFor(path)), {
      contentType: 'image/png',
      resumable: false,
    });
    written++;
  }

  console.log(`Wrote ${written} placeholders. These are NOT the real images.`);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
