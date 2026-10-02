/**
 * Removes the metadata a phone writes into a JPEG before a photo is shown to
 * students (instructors plan v2 §8). Found on the simulator 2026-10-02:
 * image_picker resizes the picture but copies its EXIF, GPS position
 * included, so an instructor's home location would travel with their photo.
 *
 * Drops APP1 (EXIF, XMP), APP13 (IPTC / Photoshop) and COM segments; keeps
 * everything that affects how the picture looks (JFIF, the ICC colour
 * profile in APP2, Adobe APP14, the tables and the scan). image_picker
 * already rotates the pixels upright (orientation 1), so dropping the EXIF
 * orientation does not turn the app's own uploads sideways.
 *
 * Returns null when the bytes are not a JPEG this can walk; the caller then
 * refuses the upload (fail-closed).
 */
const DROP = new Set([0xe1, 0xed, 0xfe]);

export function stripJpegMetadata(input: Buffer): Buffer | null {
  if (input.length < 4 || input[0] !== 0xff || input[1] !== 0xd8) return null;
  const parts: Buffer[] = [input.subarray(0, 2)];
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
    if (!DROP.has(marker)) parts.push(input.subarray(i, i + 2 + length));
    i += 2 + length;
  }
  return null;
}
