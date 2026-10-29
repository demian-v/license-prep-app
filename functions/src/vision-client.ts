import { google } from 'googleapis';

/**
 * Cloud Vision SafeSearch for instructor profile photos (instructors plan v2
 * §8, P10b): `images:annotate` with SAFE_SEARCH_DETECTION, through the
 * `googleapis` client the functions already use (no extra package). The
 * function's own service account authenticates; the Cloud Vision API must
 * be enabled in the project (owner setup).
 *
 * The emulator never calls it: it would run on the developer's credentials
 * against the real project (risk register 2026-10-17), and Vision has no
 * sandbox. There, and in jest, the fake below answers.
 */

export type Likelihood = 'UNKNOWN' | 'VERY_UNLIKELY' | 'UNLIKELY' | 'POSSIBLE' | 'LIKELY' | 'VERY_LIKELY';

export interface SafeSearch {
  adult: Likelihood;
  violence: Likelihood;
  racy: Likelihood;
}

export interface VisionClient {
  /** Throws when Vision can't answer — the caller holds the photo (fail-closed). */
  safeSearch(jpeg: Buffer): Promise<SafeSearch>;
}

const ORDER: Likelihood[] = ['UNKNOWN', 'VERY_UNLIKELY', 'UNLIKELY', 'POSSIBLE', 'LIKELY', 'VERY_LIKELY'];

/** Plan v2 §8: LIKELY or above on adult, violence or racy is refused. */
export function isUnsafe(s: SafeSearch): boolean {
  return [s.adult, s.violence, s.racy].some((v) => ORDER.indexOf(v) >= ORDER.indexOf('LIKELY'));
}

const realVision: VisionClient = {
  async safeSearch(jpeg) {
    const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-vision'] });
    const vision = google.vision({ version: 'v1', auth });
    const res = await vision.images.annotate({
      requestBody: { requests: [{ image: { content: jpeg.toString('base64') }, features: [{ type: 'SAFE_SEARCH_DETECTION' }] }] },
    });
    const r = res.data.responses?.[0];
    if (!r || r.error) throw new Error(`Vision: ${r?.error?.message ?? 'no response'}`);
    const a = r.safeSearchAnnotation;
    if (!a) throw new Error('Vision: no SafeSearch annotation');
    const like = (v: string | null | undefined): Likelihood => (ORDER.includes(v as Likelihood) ? v as Likelihood : 'UNKNOWN');
    return { adult: like(a.adult), violence: like(a.violence), racy: like(a.racy) };
  },
};

/**
 * The emulator's Vision: every photo is fine, except a JPEG carrying the
 * test marker below in a comment (the seed's held/refused examples, so the
 * panel's held photos can be tried locally). Real photos never carry it,
 * and published photos lose every comment segment (stripJpegMetadata).
 */
export const VISION_TEST_MARKER = 'DRIVEUSA-VISION-TEST:';
export const fakeVision: VisionClient = {
  async safeSearch(jpeg) {
    const text = jpeg.toString('latin1');
    if (text.includes(`${VISION_TEST_MARKER}error`)) throw new Error('Vision (emulator fake): simulated outage');
    if (text.includes(`${VISION_TEST_MARKER}unsafe`)) return { adult: 'VERY_LIKELY', violence: 'UNLIKELY', racy: 'LIKELY' };
    return { adult: 'VERY_UNLIKELY', violence: 'VERY_UNLIKELY', racy: 'VERY_UNLIKELY' };
  },
};

let override: VisionClient | null = null;

/** Tests only. null restores the choice below. */
export function setVisionClient(fake: VisionClient | null) {
  override = fake;
}

export function vision(): VisionClient {
  if (override) return override;
  return process.env.FUNCTIONS_EMULATOR === 'true' ? fakeVision : realVision;
}
