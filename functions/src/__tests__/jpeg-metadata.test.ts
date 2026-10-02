/**
 * The photo students see carries no phone metadata (instructors plan v2 §8;
 * found 2026-10-02: image_picker kept the EXIF GPS position).
 */
import { stripJpegMetadata } from '../jpeg-metadata';
import { COMMENT, DQT, EXIF_GPS, ICC, IPTC, JFIF, SCAN, SOF, jpeg, phonePhoto } from './helpers/jpeg';

describe('stripJpegMetadata', () => {
  it('drops EXIF (GPS), XMP, IPTC and comments', () => {
    const out = stripJpegMetadata(phonePhoto())!;
    const text = out.toString('latin1');
    for (const leak of ['GPSLatitude', 'xmpmeta', 'Photoshop', 'city=Chicago', '123 Main St', 'Exif']) {
      expect(text).not.toContain(leak);
    }
  });

  it('keeps what the picture needs, byte for byte and in order', () => {
    expect(stripJpegMetadata(phonePhoto())).toEqual(jpeg(JFIF, ICC, DQT, SOF));
  });

  it('copies the scan data unchanged, 0xFF bytes and all', () => {
    const out = stripJpegMetadata(jpeg(JFIF, EXIF_GPS, DQT, SOF))!;
    expect(out.subarray(out.length - SCAN.length)).toEqual(SCAN);
  });

  it('leaves a clean JPEG as it is', () => {
    const clean = jpeg(JFIF, DQT, SOF);
    expect(stripJpegMetadata(clean)).toEqual(clean);
  });

  it.each([
    ['not a JPEG', Buffer.from('\x89PNG\r\n\x1a\n', 'latin1')],
    ['empty', Buffer.alloc(0)],
    ['cut off inside a segment', phonePhoto().subarray(0, 30)],
    ['no scan', Buffer.concat([Buffer.from([0xff, 0xd8]), JFIF, Buffer.from([0xff, 0xd9])])],
    ['a bad segment length', Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe1, 0x00, 0x01]), SCAN])],
    ['garbage between segments', Buffer.concat([Buffer.from([0xff, 0xd8]), JFIF, Buffer.from([0x00]), SCAN])],
  ])('refuses %s', (_name, bytes) => {
    expect(stripJpegMetadata(bytes)).toBeNull();
  });

  it('skips fill bytes between segments', () => {
    const filled = Buffer.concat([Buffer.from([0xff, 0xd8]), JFIF, Buffer.from([0xff]), EXIF_GPS, SCAN]);
    expect(stripJpegMetadata(filled)).toEqual(jpeg(JFIF));
  });

  it('drops comment segments', () => {
    expect(stripJpegMetadata(jpeg(COMMENT, IPTC))).toEqual(jpeg());
  });
});
