/**
 * Art for the site, all our own:
 * - LINE_ART: the four «Line» drawings from the story drafts
 *   (design/video-ads/_src/story-drafts.template.html), copied unchanged.
 *   `.d` strokes draw themselves in, `.f` parts fade in (src/main.ts).
 * - beep(): Beep the mascot, poses from design/video-ads/_src/poses.json
 *   (rendered by design/memes/own/_src/beep.py).
 * - ICONS: Solar line icons, as the app uses them (assets/icons/).
 */
import { readFileSync } from 'node:fs';

export const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function octagon(cx, cy, r) {
  const p = [];
  for (let k = 0; k < 8; k++) {
    const a = ((22.5 + 45 * k) * Math.PI) / 180;
    p.push((cx + r * Math.cos(a)).toFixed(1) + ',' + (cy + r * Math.sin(a)).toFixed(1));
  }
  return p.join(' ');
}

export const LINE_ART = [
 L=>`<svg viewBox="0 0 280 230" class="ln">
   <path class="f dotted thin" d="M112,178 Q96,160 86,146"/><path class="f dotted thin" d="M170,178 Q190,160 198,146"/>
   <g class="flt" style="--d:0s"><polygon class="d" points="${octagon(84,92,28)}"/><text class="f" x="84" y="97" font-size="12" text-anchor="middle">STOP</text><path class="d" d="M84,120 V140"/></g>
   <g class="flt" style="--d:.8s"><path class="d" d="M170,70 H230 L200,120 Z"/><path class="d thin" d="M183,78 H217 L200,106 Z"/><path class="d" d="M200,120 V140"/></g>
   <path class="d" d="M128,50 a14,14 0 1 1 24,0 c-4,5 -5,8 -5,12 h-14 c0,-4 -1,-7 -5,-12 z"/><path class="d" d="M134,68 h12 M136,74 h8"/>
   <g class="blink"><path class="d thin" d="M140,14 v-7 M118,24 l-5,-5 M162,24 l5,-5 M112,44 h-7 M168,44 h7"/></g>
   <path class="d" d="M40,190 Q90,172 140,184 Q190,172 240,190 V212 Q190,196 140,208 Q90,196 40,212 Z"/><path class="d" d="M140,184 V208"/>
   <path class="d thin" d="M62,192 Q92,184 122,190 M158,190 Q188,184 218,192"/>
 </svg>`,
 L=>`<svg viewBox="0 0 280 230" class="ln">
   <path class="d" d="M140,40 V14"/><path class="d" d="M140,14 H162 L156,21 L162,28 H140"/>
   <path class="d" d="M60,76 L140,40 L220,76 Z"/><text class="f" x="140" y="69" font-size="13" text-anchor="middle">DMV</text>
   <path class="d" d="M56,76 H224 V86 H56 Z"/>
   <path class="d" d="M74,86 V150 M100,86 V150 M180,86 V150 M206,86 V150"/>
   <path class="d" d="M122,150 V114 Q140,102 158,114 V150"/>
   <path class="d" d="M48,150 H232 M40,162 H240"/>
   <g class="flt" style="--d:.3s"><rect class="d" x="176" y="118" width="70" height="92" rx="9" fill="#fff"/><rect class="d" x="197" y="111" width="28" height="13" rx="4" fill="#fff"/>
   <rect class="d thin" x="187" y="138" width="11" height="11" rx="2"/><rect class="d thin" x="187" y="160" width="11" height="11" rx="2"/><rect class="d thin" x="187" y="182" width="11" height="11" rx="2"/>
   <path class="d thin" d="M205,143.5 h30 M205,165.5 h26 M205,187.5 h30"/>
   <path class="d late" d="M188,143 l4,4 l8,-9"/><path class="d late2" d="M188,165 l4,4 l8,-9"/><path class="d late3" d="M188,187 l4,4 l8,-9"/></g>
 </svg>`,
 L=>`<svg viewBox="0 0 280 230" class="ln">
   <path class="f dotted" d="M40,214 Q130,196 214,192"/>
   <path class="d" d="M58,210 V176 Q58,130 104,128 Q150,130 150,176 V210"/><path class="d" d="M90,130 L104,146 L118,130"/>
   <circle class="d" cx="104" cy="96" r="22"/>
   <path class="d" d="M80,88 Q82,58 104,58 Q126,58 128,88 Z" fill="#fff"/><path class="d" d="M78,88 H146"/><circle class="d thin" cx="104" cy="73" r="4"/>
   <circle class="f" cx="97" cy="98" r="2" style="fill:#0048C3;stroke:none"/><circle class="f" cx="111" cy="98" r="2" style="fill:#0048C3;stroke:none"/>
   <path class="d thin" d="M96,106 Q104,112 112,106"/>
   <rect class="d" x="122" y="150" width="36" height="44" rx="6" fill="#fff"/><path class="d thin late" d="M130,165 l4,4 l8,-9"/><path class="d thin" d="M130,180 h20 M130,187 h13"/>
   <g class="flt" style="--d:.2s"><path class="d" d="M172,38 H236 Q248,38 248,50 V78 Q248,90 236,90 H194 L180,104 L183,90 H172 Q160,90 160,78 V50 Q160,38 172,38 Z"/><text class="f" x="204" y="69" font-size="14" text-anchor="middle">${esc(L.ready)}</text></g>
   <g class="bnc"><path class="d" d="M222,188 C222,188 200,164 200,148 A22,22 0 0 1 244,148 C244,164 222,188 222,188 Z"/><circle class="d thin" cx="222" cy="148" r="7"/></g>
 </svg>`,
 L=>`<svg viewBox="0 0 280 230" class="ln">
   <circle class="d" cx="226" cy="50" r="17"/><g class="spin-slow"><path class="d thin" d="M226,20 v-8 M226,80 v8 M196,50 h-8 M256,50 h8 M205,29 l-5,-5 M247,71 l5,5 M247,29 l5,-5 M205,71 l-5,5"/></g>
   <g class="drift"><path class="d thin" d="M40,76 a11,11 0 0 1 20,-6 a13,13 0 0 1 25,7 a9,9 0 0 1 -2,18 H44 a10,10 0 0 1 -4,-19 z"/></g>
   <path class="d thin" d="M0,150 Q60,112 130,142 T280,128"/>
   <path class="d" d="M0,200 H280"/><path class="f dash" d="M-20,220 H300"/>
   <g class="f thin"><path d="M24,160 H54 M14,172 H48 M30,184 H58"/></g>
   <g class="bob">
     <path class="d" d="M68,190 V176 Q68,166 78,164 L98,161 L112,143 Q116,137 124,137 H168 Q176,137 181,143 L196,161 L214,165 Q222,167 222,176 V190 Z" fill="#fff"/>
     <path class="d thin" d="M118,159 L127,147 H146 V159 Z M154,159 V147 H170 L180,159 Z"/><path class="d thin" d="M208,172 h8"/>
     <circle class="d" cx="102" cy="192" r="13" fill="#fff"/><circle class="d" cx="190" cy="192" r="13" fill="#fff"/>
     <g class="spin"><path class="f thin" d="M102,184 V200 M94,192 H110"/></g><g class="spin"><path class="f thin" d="M190,184 V200 M182,192 H198"/></g>
   </g>
 </svg>`
];

const POSES = JSON.parse(readFileSync(new URL('../src/art/poses.json', import.meta.url), 'utf8'));

/** Beep with the given poses stacked; the first one shows. `cls` styles it. */
export function beep(poses, cls) {
  const g = poses.map((k, i) => `<g class="pose" data-k="${k}"${i ? ' style="opacity:0"' : ''}>${POSES[k]}</g>`).join('');
  return `<svg class="${cls}" viewBox="-146 -206 292 210" aria-hidden="true" focusable="false"><g class="beep-body">${g}</g></svg>`;
}

export const ICONS = {
  "clock-circle-linear": "<svg aria-hidden=\"true\" focusable=\"false\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-width=\"1.5\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path stroke-linejoin=\"round\" d=\"M12 8V12L14.5 14.5\"/></g></svg>",
  "clipboard-check-linear": "<svg aria-hidden=\"true\" focusable=\"false\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-width=\"1.5\"><path d=\"M16 4C18.175 4.01211 19.3529 4.10856 20.1213 4.87694C21 5.75562 21 7.16983 21 9.99826V15.9983C21 18.8267 21 20.2409 20.1213 21.1196C19.2426 21.9983 17.8284 21.9983 15 21.9983H9C6.17157 21.9983 4.75736 21.9983 3.87868 21.1196C3 20.2409 3 18.8267 3 15.9983V9.99826C3 7.16983 3 5.75562 3.87868 4.87694C4.64706 4.10856 5.82497 4.01211 8 4\"/><path stroke-linejoin=\"round\" d=\"M9 13.4L10.7143 15L15 11\"/><path d=\"M8 3.5C8 2.67157 8.67157 2 9.5 2H14.5C15.3284 2 16 2.67157 16 3.5V4.5C16 5.32843 15.3284 6 14.5 6H9.5C8.67157 6 8 5.32843 8 4.5V3.5Z\"/></g></svg>",
  "book-2-linear": "<svg aria-hidden=\"true\" focusable=\"false\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-width=\"1.5\"><path d=\"M4 8C4 5.17157 4 3.75736 4.87868 2.87868C5.75736 2 7.17157 2 10 2H14C16.8284 2 18.2426 2 19.1213 2.87868C20 3.75736 20 5.17157 20 8V16C20 18.8284 20 20.2426 19.1213 21.1213C18.2426 22 16.8284 22 14 22H10C7.17157 22 5.75736 22 4.87868 21.1213C4 20.2426 4 18.8284 4 16V8Z\"/><path d=\"M19.9997 16H7.89749C6.96751 16 6.50253 16 6.12103 16.1022C5.08575 16.3796 4.29986 17.1212 4.02246 18.1564\"/><path d=\"M8 7H16\"/><path d=\"M8 10.5H13\"/><path d=\"M19.9239 19H8\"/></g></svg>",
  "chat-round-line-linear": "<svg aria-hidden=\"true\" focusable=\"false\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-width=\"1.5\"><path d=\"M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 13.5997 2.37562 15.1116 3.04346 16.4525C3.22094 16.8088 3.28001 17.2161 3.17712 17.6006L2.58151 19.8267C2.32295 20.793 3.20701 21.677 4.17335 21.4185L6.39939 20.8229C6.78393 20.72 7.19121 20.7791 7.54753 20.9565C8.88837 21.6244 10.4003 22 12 22Z\"/><path d=\"M8 10.5H16\"/><path d=\"M8 14H13.5\"/></g></svg>",
  "layers-minimalistic-linear": "<svg aria-hidden=\"true\" focusable=\"false\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-width=\"1.5\"><path d=\"M4.97883 9.68508C2.99294 8.89073 2 8.49355 2 8C2 7.50645 2.99294 7.10927 4.97883 6.31492L7.7873 5.19153C9.77318 4.39718 10.7661 4 12 4C13.2339 4 14.2268 4.39718 16.2127 5.19153L19.0212 6.31492C21.0071 7.10927 22 7.50645 22 8C22 8.49355 21.0071 8.89073 19.0212 9.68508L16.2127 10.8085C14.2268 11.6028 13.2339 12 12 12C10.7661 12 9.77318 11.6028 7.7873 10.8085L4.97883 9.68508Z\"/><path d=\"M22 12C22 12 21.0071 12.8907 19.0212 13.6851L16.2127 14.8085C14.2268 15.6028 13.2339 16 12 16C10.7661 16 9.77318 15.6028 7.7873 14.8085L4.97883 13.6851C2.99294 12.8907 2 12 2 12\"/><path d=\"M22 16C22 16 21.0071 16.8907 19.0212 17.6851L16.2127 18.8085C14.2268 19.6028 13.2339 20 12 20C10.7661 20 9.77318 19.6028 7.7873 18.8085L4.97883 17.6851C2.99294 16.8907 2 16 2 16\"/></g></svg>",
  "check-linear": "<svg aria-hidden=\"true\" focusable=\"false\" viewBox=\"0 0 24 24\"><path fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\" d=\"M5 13L9 17L19 7\"/></svg>",
  "alt-arrow-right-linear": "<svg aria-hidden=\"true\" focusable=\"false\" viewBox=\"0 0 24 24\"><path fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\" d=\"M9 5L15 12L9 19\"/></svg>"
};
