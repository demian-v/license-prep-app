import * as functions from 'firebase-functions/v1';
import Stripe from 'stripe';
import { defineSecret } from 'firebase-functions/params';

/**
 * Stripe, test mode only on this branch (instructors plan v2 §9, P9).
 *
 * Keys never live in the repo (it is public, risk #1 / #32). All three are
 * secrets — Secret Manager in production, the git-ignored
 * functions/.secret.local on the emulator, dummies in jest:
 * - STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET;
 * - STRIPE_PUBLISHABLE_KEY — public by design, but a secret here so it sits in
 *   no tracked file either, and because a `defineString` param stops the
 *   emulator at an interactive prompt (found 2026-10-17, like the defineInt
 *   entry in the risk register). createBooking hands it to the app with the
 *   PaymentIntent, so the app needs no build-time define.
 *
 * STRIPE_WEBHOOK_SECRET may hold several `whsec_…` values separated by commas:
 * production has one endpoint for the platform's own events and one for
 * connected accounts (account.updated), each with its own secret. The Stripe
 * CLI forwards both with one secret.
 */
export const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
export const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');
const stripePublishableKey = defineSecret('STRIPE_PUBLISHABLE_KEY');

/** Every function that talks to Stripe declares all three. */
export const STRIPE_SECRETS = [stripeSecretKey, stripeWebhookSecret, stripePublishableKey];

let clientOverride: Stripe | null = null;
let client: { key: string; stripe: Stripe } | null = null;

/** Tests only: a fake client (no network in jest). null restores the real one. */
export function setStripeClient(fake: unknown) {
  clientOverride = fake as Stripe | null;
}

function secretKey(): string {
  try {
    return stripeSecretKey.value() ?? '';
  } catch {
    return '';
  }
}

/**
 * True when Stripe should take the payments. A live key is never used on
 * the emulator: this branch is test mode only.
 */
export function stripeConfigured(): boolean {
  if (clientOverride) return true;
  const key = secretKey();
  if (!key) return false;
  if (process.env.FUNCTIONS_EMULATOR === 'true' && /^(sk|rk)_live_/.test(key)) {
    functions.logger.error('A live Stripe key on the emulator — refusing to use it. Test keys only.');
    return false;
  }
  return true;
}

export function stripe(): Stripe {
  if (clientOverride) return clientOverride;
  if (!stripeConfigured()) throw new functions.https.HttpsError('failed-precondition', 'payments-unavailable');
  const key = secretKey();
  if (client?.key !== key) client = { key, stripe: new Stripe(key, { maxNetworkRetries: 2 }) };
  return client.stripe;
}

export function publishableKey(): string {
  try {
    return stripePublishableKey.value() ?? '';
  } catch {
    return '';
  }
}

/**
 * Verifies a webhook's signature against each configured secret and returns
 * the event, or null when none matches. Offline: no API call.
 */
export function verifyWebhook(rawBody: Buffer | string, signature: string | undefined): Stripe.Event | null {
  if (!signature) return null;
  let secrets: string[] = [];
  try {
    secrets = (stripeWebhookSecret.value() ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  } catch {
    secrets = [];
  }
  for (const secret of secrets) {
    try {
      // The signature check constructEvent makes (the 5-minute replay window
      // included), without its refusal of v2 thin events (`object:
      // 'v2.core.event'`), which come to the same endpoint.
      Stripe.webhooks.signature!.verifyHeader(rawBody, signature, secret, Stripe.webhooks.DEFAULT_TOLERANCE);
    } catch {
      continue; // try the next secret
    }
    return JSON.parse(rawBody.toString()) as Stripe.Event;
  }
  return null;
}

/** Where Stripe sends an instructor back after onboarding (needs http(s)). */
export function functionUrl(name: string): string {
  const project = process.env.GCLOUD_PROJECT ?? 'licenseprepapp';
  return process.env.FUNCTIONS_EMULATOR === 'true'
    ? `http://127.0.0.1:5001/${project}/us-central1/${name}`
    : `https://us-central1-${project}.cloudfunctions.net/${name}`;
}
