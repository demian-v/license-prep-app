/**
 * The photo students see carries no phone metadata (instructors plan v2 §8;
 * found 2026-10-02: image_picker kept the EXIF GPS position).
 */
import { stripJpegMetadata } from '../jpeg-metadata';
import { COMMENT, DQT, EXIF_GPS, ICC, IPTC, JFIF, SCAN, SOF, XMP, exifWithOrientation, jpeg, phonePhoto } from './helpers/jpeg';

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

  // Found on a real iPhone 12 Pro 2026-10-05: a portrait photo arrives as
  // landscape pixels + Orientation 6, so dropping the whole EXIF block
  // published it sideways. Only the Orientation tag survives.
  describe('orientation', () => {
    // Walks the output's EXIF the way a decoder does: the Orientation value
    // and how many IFD0 entries there are.
    const exifOf = (out: Buffer) => {
      const at = out.indexOf(Buffer.from('Exif\0\0', 'latin1'));
      if (at < 0) return null;
      const t = out.subarray(at + 6);
      const le = t.toString('latin1', 0, 2) === 'II';
      const u16 = (o: number) => (le ? t.readUInt16LE(o) : t.readUInt16BE(o));
      const ifd = le ? t.readUInt32LE(4) : t.readUInt32BE(4);
      return { entries: u16(ifd), tag: u16(ifd + 2), orientation: u16(ifd + 10) };
    };

    it.each([['MM', 6], ['II', 6], ['MM', 8], ['II', 3]] as const)(
      'keeps orientation (%s, %d) and nothing else from EXIF', (order, value) => {
        const out = stripJpegMetadata(jpeg(JFIF, exifWithOrientation(value, order), XMP, DQT, SOF))!;
        expect(exifOf(out)).toEqual({ entries: 1, tag: 0x0112, orientation: value });
        const text = out.toString('latin1');
        for (const leak of ['GPSLatitude', 'Apple', 'xmpmeta']) expect(text).not.toContain(leak);
      });

    it('keeps it where the EXIF block was, after JFIF', () => {
      const out = stripJpegMetadata(jpeg(JFIF, exifWithOrientation(6), DQT, SOF))!;
      expect(out.indexOf(Buffer.from('Exif', 'latin1'))).toBeGreaterThan(out.indexOf(Buffer.from('JFIF', 'latin1')));
      expect(out.subarray(2, 2 + JFIF.length)).toEqual(JFIF);
    });

    it('writes no EXIF for an upright photo (orientation 1)', () => {
      expect(stripJpegMetadata(jpeg(JFIF, exifWithOrientation(1), DQT, SOF))).toEqual(jpeg(JFIF, DQT, SOF));
    });

    it('drops an EXIF block it cannot read rather than refuse the photo', () => {
      expect(stripJpegMetadata(jpeg(JFIF, EXIF_GPS, DQT, SOF))).toEqual(jpeg(JFIF, DQT, SOF));
      const bad = exifWithOrientation(6);
      bad.writeUInt16BE(99, 10 + 2); // not TIFF magic 42
      expect(stripJpegMetadata(jpeg(JFIF, bad, DQT, SOF))).toEqual(jpeg(JFIF, DQT, SOF));
    });

    it('keeps one orientation when a file carries two EXIF blocks', () => {
      const out = stripJpegMetadata(jpeg(exifWithOrientation(6), exifWithOrientation(8), DQT, SOF))!;
      expect(out.toString('latin1').split('Exif').length - 1).toBe(1);
      expect(exifOf(out)!.orientation).toBe(6);
    });
  });
});
