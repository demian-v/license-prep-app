/**
 * A small JPEG built segment by segment, so a test can say exactly which
 * metadata a phone left in it. Not decodable as a picture — the stripper and
 * the trigger only walk the segments.
 */
const seg = (marker: number, body: Buffer) => {
  const head = Buffer.alloc(4);
  head[0] = 0xff; head[1] = marker; head.writeUInt16BE(body.length + 2, 2);
  return Buffer.concat([head, body]);
};

export const JFIF = seg(0xe0, Buffer.from('JFIF\0\x01\x01\0\0\x01\0\x01\0\0', 'latin1'));
export const EXIF_GPS = seg(0xe1, Buffer.from('Exif\0\0GPSLatitude 41.8819N GPSLongitude 87.6278W', 'latin1'));
export const XMP = seg(0xe1, Buffer.from('http://ns.adobe.com/xap/1.0/\0<x:xmpmeta>Chicago</x:xmpmeta>', 'latin1'));
export const ICC = seg(0xe2, Buffer.from('ICC_PROFILE\0\x01\x01sRGB-profile-bytes', 'latin1'));
export const IPTC = seg(0xed, Buffer.from('Photoshop 3.0\0city=Chicago', 'latin1'));
export const COMMENT = seg(0xfe, Buffer.from('taken at 123 Main St', 'latin1'));
export const DQT = seg(0xdb, Buffer.alloc(65, 1));
export const SOF = seg(0xc0, Buffer.from([8, 0, 1, 0, 1, 1, 1, 0x11, 0]));
export const SCAN = Buffer.concat([seg(0xda, Buffer.from([1, 1, 0, 0, 0x3f, 0])), Buffer.from([0x12, 0xff, 0x00, 0x34, 0xff, 0xd9])]);

export const jpeg = (...segments: Buffer[]) => Buffer.concat([Buffer.from([0xff, 0xd8]), ...segments, SCAN]);
export const phonePhoto = () => jpeg(JFIF, EXIF_GPS, XMP, ICC, IPTC, COMMENT, DQT, SOF);

/**
 * A real EXIF block (TIFF header + IFD0) as a phone writes it: Make, the
 * Orientation tag and a pointer to a GPS IFD holding a latitude. `order` is
 * the TIFF byte order — iPhones write 'MM', many Android phones 'II'.
 */
export function exifWithOrientation(orientation: number, order: 'II' | 'MM' = 'MM') {
  const le = order === 'II';
  const t = Buffer.alloc(96);
  const u16 = (v: number, o: number) => (le ? t.writeUInt16LE(v, o) : t.writeUInt16BE(v, o));
  const u32 = (v: number, o: number) => (le ? t.writeUInt32LE(v, o) : t.writeUInt32BE(v, o));
  t.write(order, 0, 'latin1'); u16(42, 2); u32(8, 4);
  u16(3, 8); // IFD0: 3 entries
  u16(0x010f, 10); u16(2, 12); u32(6, 14); u32(50, 18); // Make -> "Apple" at 50
  u16(0x0112, 22); u16(3, 24); u32(1, 26); u16(orientation, 30); // Orientation
  u16(0x8825, 34); u16(4, 36); u32(1, 38); u32(60, 42); // GPS IFD at 60
  u32(0, 46);
  t.write('Apple\0', 50, 'latin1');
  u16(1, 60); u16(0x0002, 62); u16(2, 64); u32(1, 66); u32(80, 70); u32(0, 74); // GPSLatitude
  t.write('GPSLatitude41.88N', 78, 'latin1');
  return seg(0xe1, Buffer.concat([Buffer.from('Exif\0\0', 'latin1'), t]));
}

