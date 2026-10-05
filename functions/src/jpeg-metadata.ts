/**
 * Removes the metadata a phone writes into a JPEG before a photo is shown to
 * students (instructors plan v2 §8). Found on the simulator 2026-10-02:
 * image_picker resizes the picture but copies its EXIF, GPS position
 * included, so an instructor's home location would travel with their photo.
 *
 * Drops APP1 (EXIF, XMP), APP13 (IPTC / Photoshop) and COM segments; keeps
 * everything that affects how the picture looks (JFIF, the ICC colour
 * profile in APP2, Adobe APP14, the tables and the scan).
 *
 * One EXIF value affects how it looks too: Orientation. An iPhone portrait
 * photo reaches us as landscape pixels + Orientation 6 (image_picker does
 * not rotate the pixels — found on a real iPhone 12 Pro 2026-10-05; the
 * simulator's test photo was already upright), so dropping it published the
 * photo sideways. It is kept as a minimal EXIF block with that one tag, in
 * place of the original; an EXIF block it cannot read is just dropped.
 *
 * Returns null when the bytes are not a JPEG this can walk; the caller then
 * refuses the upload (fail-closed).
 */
const DROP = new Set([0xe1, 0xed, 0xfe]);
const EXIF = Buffer.from('Exif\0\0', 'latin1');

/** IFD0's Orientation (2–8), or null for upright, absent or unreadable. */
function exifOrientation(body: Buffer): number | null {
  if (body.length < 6 + 8 || !body.subarray(0, 6).equals(EXIF)) return null;
  const tiff = body.subarray(6);
  const order = tiff.toString('latin1', 0, 2);
  if (order !== 'II' && order !== 'MM') return null;
  const le = order === 'II';
  const u16 = (o: number) => (le ? tiff.readUInt16LE(o) : tiff.readUInt16BE(o));
  const u32 = (o: number) => (le ? tiff.readUInt32LE(o) : tiff.readUInt32BE(o));
  if (u16(2) !== 42) return null;
  const ifd = u32(4);
  if (ifd + 2 > tiff.length) return null;
  for (let k = 0, n = u16(ifd); k < n; k++) {
    const entry = ifd + 2 + k * 12;
    if (entry + 12 > tiff.length) return null;
    if (u16(entry) !== 0x0112) continue;
    const value = u16(entry + 8);
    return u16(entry + 2) === 3 && value >= 2 && value <= 8 ? value : null;
  }
  return null;
}

/** An APP1 segment holding only IFD0 { Orientation }, big-endian. */
function orientationSegment(value: number): Buffer {
  const out = Buffer.alloc(36);
  out.writeUInt16BE(0xffe1, 0);
  out.writeUInt16BE(34, 2);
  EXIF.copy(out, 4);
  out.write('MM', 10, 'latin1');
  out.writeUInt16BE(42, 12);
  out.writeUInt32BE(8, 14); // IFD0 right after the TIFF header
  out.writeUInt16BE(1, 18); // one entry
  out.writeUInt16BE(0x0112, 20); // Orientation
  out.writeUInt16BE(3, 22); // SHORT
  out.writeUInt32BE(1, 24);
  out.writeUInt16BE(value, 28);
  out.writeUInt32BE(0, 32); // no next IFD
  return out;
}

export function stripJpegMetadata(input: Buffer): Buffer | null {
  if (input.length < 4 || input[0] !== 0xff || input[1] !== 0xd8) return null;
  const parts: Buffer[] = [input.subarray(0, 2)];
  let orientationKept = false;
  let i = 2;
  while (i + 4 <= input.length) {
    if (input[i] !== 0xff) return null;
    const marker = input[i + 1];
    // Fill bytes between segments.
    if (marker === 0xff) { i += 1; continue; }
    // Start of scan: the rest is image data up to EOI, copied as is.
    if (marker === 0xda) {
      parts.push(input.subarray(i));
      return Buffer.concat(parts);
    }
    // Markers without a length (TEM, RSTn) do not appear before SOS in a
    // valid file; EOI before SOS means there is no image.
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd9)) return null;
    const length = input.readUInt16BE(i + 2);
    if (length < 2 || i + 2 + length > input.length) return null;
    if (!DROP.has(marker)) {
      parts.push(input.subarray(i, i + 2 + length));
    } else if (marker === 0xe1 && !orientationKept) {
      const orientation = exifOrientation(input.subarray(i + 4, i + 2 + length));
      if (orientation !== null) {
        parts.push(orientationSegment(orientation));
        orientationKept = true;
      }
    }
    i += 2 + length;
  }
  return null;
}
