// Runs before first paint: marks the page as animated unless the visitor
// asked for reduced motion, so content never flashes and then hides.
if (!matchMedia('(prefers-reduced-motion: reduce)').matches) document.documentElement.classList.add('motion');
