import type { Transition, Variants } from 'motion/react';

/**
 * The reference's page change: the old page fades out with a blur, the new
 * panels rise into place one after another (blur + translate + fade, not a
 * cut). Reduced motion: no blur, no movement — a short fade only.
 */
export const spring: Transition = { type: 'spring', stiffness: 380, damping: 34, mass: 0.9 };

export function pageVariants(reduced: boolean): Variants {
  return reduced
    ? { initial: { opacity: 0 }, enter: { opacity: 1, transition: { duration: 0.12 } }, exit: { opacity: 0, transition: { duration: 0.08 } } }
    : {
      initial: {},
      enter: { transition: { staggerChildren: 0.055, delayChildren: 0.02 } },
      exit: { opacity: 0, filter: 'blur(10px)', scale: 0.985, transition: { duration: 0.18, ease: [0.4, 0, 1, 1] } },
    };
}

export function riseVariants(reduced: boolean): Variants {
  return reduced
    ? { initial: { opacity: 1 }, enter: { opacity: 1 } }
    : {
      initial: { opacity: 0, y: 22, filter: 'blur(8px)' },
      enter: { opacity: 1, y: 0, filter: 'blur(0px)', transition: { type: 'spring', stiffness: 260, damping: 28, mass: 0.8 } },
    };
}
