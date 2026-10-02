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
