import { toPackageId } from '../receipt-validation';

/**
 * Risk #42 — `packageId` must always be stored as a number.
 *
 * It was written as three different types by three different writers: the int
 * `3` by the trial function, a `subscriptionsType` **document id** (a string)
 * by receipt validation, and a raw client value by `upgradeSubscription`
 * (since deleted under #2). `user_subscription.dart` parses it with
 * `_parseInt`, which returns null for anything non-numeric — so `packageId`
 * became `0`, `getPackageById` returned null, and the paywall and upgrade UI
 * degraded with no error on any layer.
 *
 * It works in production today only because the catalogue's document ids
 * happen to be "1", "2" and "3". That makes renaming a document to something
 * descriptive — an ordinary, apparently safe piece of tidying — a way to break
 * every purchase.
 */
describe('risk #42 — packageId is always a number', () => {
  // Silence the deliberate console.error in the fallback path.
  let errorSpy: jest.SpyInstance;
  beforeEach(() => {
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
  });
  afterEach(() => errorSpy.mockRestore());

  describe('the ids production actually has', () => {
    it.each([
      ['1', 'monthly', 1],
      ['2', 'yearly', 2],
      ['3', 'trial', 3],
    ])('document id %s (%s) becomes the number %i', (raw, plan, expected) => {
      const result = toPackageId(raw, plan);
      expect(result).toBe(expected);
      expect(typeof result).toBe('number');
    });

    it('passes an existing number through unchanged', () => {
      // createTrialSubscription already writes the int 3.
      expect(toPackageId(3, 'trial')).toBe(3);
    });
  });

  describe('the rename that used to break purchases', () => {
    it('falls back to the catalogue default instead of storing 0', () => {
      // The whole defect: 'monthly_subscription' is what
      // PAYMENT_SYSTEM_IMPLEMENTATION.md documents the plan as, so somebody
      // renaming the document to match the docs is the realistic path here.
      expect(toPackageId('monthly_subscription', 'monthly')).toBe(1);
    });

    it.each([
      ['monthly-plan', 'monthly', 1],
      ['', 'monthly', 1],
      ['abc', 'trial', 3],
      ['1.5', 'monthly', 1],
      ['1abc', 'monthly', 1],
    ])('%s is refused and falls back (%s → %i)', (raw, plan, expected) => {
      expect(toPackageId(raw, plan)).toBe(expected);
    });

    it('says loudly what happened, because the fallback is a misconfiguration', () => {
      toPackageId('monthly_subscription', 'monthly');
      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('is not numeric'),
      );
      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('Rename the document back to a numeric id'),
      );
    });

    it('does NOT throw — the customer has already been charged (risk #20)', () => {
      // Failing shut here costs someone a purchase they paid for. Falling back
      // costs an operational alarm. #20 made that call; this applies it.
      expect(() => toPackageId('monthly_subscription', 'monthly')).not.toThrow();
    });
  });

  describe('what it still refuses', () => {
    it('throws for an unknown plan with an unusable id', () => {
      // No catalogue default to fall back to. Guessing a package id for a
      // product nobody knows about is worse than refusing.
      expect(() => toPackageId('whatever', 'some_new_plan')).toThrow(
        /Cannot derive a numeric packageId/,
      );
    });

    it('still resolves an unknown plan when the id itself is numeric', () => {
      // The id is the thing that has to be usable; the plan only matters for
      // the fallback.
      expect(toPackageId('7', 'some_new_plan')).toBe(7);
    });
  });

  describe('a stored packageId is parseable by the Dart model', () => {
    // Mirrors UserSubscription._parseInt: int, double, or int.tryParse on a
    // String, else null — which the model turns into 0.
    const dartParseInt = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      if (typeof value === 'number') return Math.trunc(value);
      if (typeof value === 'string') {
        const n = Number.parseInt(value, 10);
        return Number.isNaN(n) ? null : n;
      }
      return null;
    };

    it.each([
      ['1', 'monthly'],
      ['2', 'yearly'],
      ['3', 'trial'],
      ['monthly_subscription', 'monthly'],
      ['renamed-for-clarity', 'trial'],
    ])('a catalogue id of %s survives the round trip', (raw, plan) => {
      const stored = toPackageId(raw, plan);
      const readBack = dartParseInt(stored);

      expect(readBack).not.toBeNull();
      expect(readBack).toBe(stored);
      expect(readBack).toBeGreaterThan(0); // 0 is what getPackageById fails on
    });

    it('proves the defect: the raw document id would NOT have survived', () => {
      // The positive control. Without toPackageId, this is what reached
      // Firestore and what the app then read back.
      expect(dartParseInt('monthly_subscription')).toBeNull();
    });
  });
});
