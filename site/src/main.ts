/**
 * Motion for driveusallc.com, with the admin panel's library (`motion`) and the
 * app's timings (lib/theme/app_motion.dart): entrances decelerate
 * (easeOutCubic), 180 / 240 / 320 / 380 ms, siblings staggered.
 *
 * Nothing here runs when the visitor asked for reduced motion: boot.js then
 * leaves out the `.motion` class, the CSS never hides anything, and the page
 * is complete as served. The only loop (the phone) pauses off-screen, on
 * hover/focus and in a background tab.
 */
import { animate, inView, stagger } from 'motion';

const ENTER = [0.215, 0.61, 0.355, 1] as const;
const SPRING = { type: 'spring', stiffness: 260, damping: 22 } as const;
const motion = document.documentElement.classList.contains('motion');

const $$ = <T extends Element = HTMLElement>(sel: string, root: ParentNode = document) => Array.from(root.querySelectorAll<T>(sel));

// The header gets a hairline once the page scrolls under it.
const top = document.querySelector<HTMLElement>('[data-top]');
if (top) {
  const onScroll = () => top.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

// Close the language menu on an outside click or Escape.
const lang = document.querySelector<HTMLDetailsElement>('.lang');
if (lang) {
  document.addEventListener('click', (e) => {
    if (lang.open && !lang.contains(e.target as Node)) lang.open = false;
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && lang.open) {
      lang.open = false;
      lang.querySelector('summary')?.focus();
    }
  });
}

carousel();

if (motion) {
  // Hero: copy rises in line by line, the phone card settles after it.
  animate($$('[data-in]'), { opacity: [0, 1], y: [18, 0] }, { duration: 0.38, ease: ENTER, delay: stagger(0.07, { startDelay: 0.05 }) });
  const stage = document.querySelector('[data-stage]');
  if (stage) animate(stage, { opacity: [0, 1], scale: [0.96, 1], y: [24, 0] }, { ...SPRING, delay: 0.18 });

  // Single blocks fade up as they enter.
  for (const el of $$('[data-reveal]')) {
    inView(el, () => {
      animate(el, { opacity: [0, 1], y: [24, 0] }, { duration: 0.38, ease: ENTER });
      // Any part entering counts: a share of a tall block (the privacy
      // policy is ~5 screens) may never fit on screen at once.
    }, { margin: '0px 0px -12% 0px' });
  }

  // Grids: children one after another.
  for (const group of $$('[data-stagger]')) {
    inView(group, () => {
      animate(Array.from(group.children), { opacity: [0, 1], y: [28, 0] }, { duration: 0.38, ease: ENTER, delay: stagger(0.08) });
    }, { margin: '0px 0px -12% 0px' });
  }

  // Numbers count up from zero.
  for (const el of $$('[data-count]')) {
    const to = Number(el.dataset.count);
    el.textContent = '0';
    inView(el, () => {
      animate(0, to, { duration: 1.1, ease: ENTER, onUpdate: (v) => (el.textContent = String(Math.round(v))) });
    }, { amount: 0.6 });
  }

  // State and language chips pop in.
  for (const list of $$('.chips')) {
    inView(list, () => {
      animate(Array.from(list.children), { opacity: [0, 1], scale: [0.8, 1] }, { ...SPRING, delay: stagger(0.024, { startDelay: 0.2 }) });
    }, { amount: 0.3 });
  }
}

// Line drawings draw themselves in, then their small loops run while on screen.
for (const svg of $$<SVGSVGElement>('.ln')) {
  let drawn = false;
  inView(svg, () => {
    if (!drawn && motion) draw(svg);
    drawn = true;
    svg.classList.add('live');
    return () => svg.classList.remove('live');
  }, { amount: 0.4 });
}

function draw(svg: SVGSVGElement) {
  const strokes = $$<SVGGeometryElement>('.d', svg);
  strokes.forEach((p, i) => {
    const len = Math.ceil(p.getTotalLength?.() ?? 400);
    p.style.strokeDasharray = `${len}`;
    p.style.strokeDashoffset = `${len}`;
    p.style.visibility = 'visible';
    const late = p.classList.contains('late3') ? 0.5 : p.classList.contains('late2') ? 0.35 : p.classList.contains('late') ? 0.2 : 0;
    animate(p, { strokeDashoffset: [len, 0] }, { duration: 0.9, ease: ENTER, delay: 0.1 + i * 0.05 + late }).finished.then(() => {
      p.style.strokeDasharray = '';
      p.style.strokeDashoffset = '';
    });
  });
  animate($$('.f', svg), { opacity: [0, 1] }, { duration: 0.32, delay: 0.25 + strokes.length * 0.05 });
}

// The quiz mock answers itself: B turns green (green only ever means correct).
for (const quiz of $$('[data-quiz]')) {
  inView(quiz, () => {
    const t = setTimeout(() => quiz.classList.add('revealed'), motion ? 700 : 0);
    return () => clearTimeout(t);
  }, { amount: 0.6 });
}

// The CTA's Beep breathes while visible.
for (const b of $$('.cta-beep')) {
  inView(b, () => {
    b.classList.add('live');
    return () => b.classList.remove('live');
  });
}

/**
 * The phone: real screens swap every few seconds, and Beep hops and changes
 * pose with each one. Dots pick a screen, and a horizontal swipe (touch or
 * mouse drag) goes to the next/previous one. Autoplay only with motion allowed.
 */
function carousel() {
  const phone = document.querySelector<HTMLElement>('[data-phone]');
  if (!phone) return;
  const shots = $$<HTMLImageElement>('.shot', phone);
  const dots = $$<HTMLButtonElement>('.dot');
  const beep = document.querySelector<SVGSVGElement>('.hero-beep');
  const poses = beep ? $$<SVGGElement>('.pose', beep) : [];
  let index = 0;
  let timer = 0;
  let visible = true;
  let held = false;

  /** `dir` set = a swipe: slide sideways that way; unset = autoplay/dots: rise. */
  const show = (next: number, dir?: 1 | -1, fromX = 0) => {
    if (next === index) return;
    const from = shots[index];
    const to = shots[next];
    shots.forEach((s, i) => s.setAttribute('aria-hidden', String(i !== next)));
    dots.forEach((d, i) => d.setAttribute('aria-selected', String(i === next)));
    index = next;
    if (motion) {
      const out = dir ? { opacity: [1, 0], x: [fromX, -70 * dir] } : { opacity: [1, 0], y: [0, -14] };
      const enter = dir ? { opacity: [0, 1], x: [70 * dir, 0] } : { opacity: [0, 1], y: [14, 0] };
      animate(from, out, { duration: 0.24, ease: [0.55, 0.055, 0.675, 0.19] }).finished.then(() => {
        from.classList.remove('on');
        from.style.transform = '';
      });
      to.classList.add('on');
      animate(to, enter, { duration: 0.38, ease: ENTER });
    } else {
      from.classList.remove('on');
      to.classList.add('on');
    }
    const pose = to.dataset.pose;
    if (!beep) return;
    const swap = () => poses.forEach((p) => (p.style.opacity = p.dataset.k === pose ? '1' : '0'));
    if (motion) {
      animate(beep, { y: [0, -34, 0], rotate: [0, -6, 0] }, { duration: 0.6, ease: 'easeInOut' });
      setTimeout(swap, 260);
    } else swap();
  };

  const schedule = () => {
    clearTimeout(timer);
    if (!motion || !visible || held || document.hidden) return;
    timer = window.setTimeout(() => {
      show((index + 1) % shots.length);
      schedule();
    }, 3400);
  };

  dots.forEach((d, i) =>
    d.addEventListener('click', () => {
      show(i);
      schedule();
    }),
  );
  const stage = (phone.closest('[data-stage]') ?? phone) as HTMLElement;

  // Swipe: a mostly-horizontal drag of 40 px or more changes the screen; the
  // screen follows the finger a little meanwhile. Vertical drags stay page
  // scrolls (`touch-action: pan-y` in the CSS).
  let startX = 0;
  let startY = 0;
  let dragging = false;
  let dx = 0;
  stage.addEventListener('pointerdown', (e) => {
    if ((e.target as Element).closest('.dot') || (e.pointerType === 'mouse' && e.button !== 0)) return;
    dragging = true;
    dx = 0;
    startX = e.clientX;
    startY = e.clientY;
    stage.setPointerCapture(e.pointerId);
  });
  stage.addEventListener('pointermove', (e) => {
    if (!dragging) return;
    dx = e.clientX - startX;
    if (motion && Math.abs(dx) > Math.abs(e.clientY - startY)) shots[index].style.transform = `translateX(${dx * 0.35}px)`;
  });
  const endDrag = (e: PointerEvent) => {
    if (!dragging) return;
    dragging = false;
    const dy = e.clientY - startY;
    const current = shots[index];
    if (Math.abs(dx) >= 40 && Math.abs(dx) > Math.abs(dy) * 1.2) {
      const dir = dx < 0 ? 1 : -1;
      show((index + dir + shots.length) % shots.length, dir, dx * 0.35);
      schedule();
    } else if (motion && current.style.transform) {
      animate(current, { x: [dx * 0.35, 0] }, SPRING).finished.then(() => (current.style.transform = ''));
    }
  };
  stage.addEventListener('pointerup', endDrag);
  stage.addEventListener('pointercancel', endDrag);

  stage.addEventListener('pointerenter', () => ((held = true), schedule()));
  stage.addEventListener('pointerleave', () => ((held = false), schedule()));
  stage.addEventListener('focusin', () => ((held = true), schedule()));
  stage.addEventListener('focusout', () => ((held = false), schedule()));
  document.addEventListener('visibilitychange', schedule);
  inView(stage, () => {
    visible = true;
    schedule();
    return () => {
      visible = false;
      schedule();
    };
  });
}
