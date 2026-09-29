# Video ads: story drafts

Two onboarding story drafts from the 2026-09-29 session. The owner picked
option C for the in-app onboarding and kept these two as candidates for a
future App Store preview video.

Open `story-drafts.html` in a browser (or through the `design-pages` preview
server at `http://localhost:8765/video-ads/story-drafts.html`). Each phone is
a live prototype. The page also holds option C, which became the onboarding
(`design/onboarding/`).

| Draft | Story (4 cards, then screenshot steps) | Look |
|---|---|---|
| **A · Line** | Learn the rules → Pass the DMV test → Find an instructor → Hit the road | Single-line blue drawings that draw themselves in and whoosh out sideways, after the BERD shot <https://dribbble.com/shots/17039086-Onboarding-Animation> |
| **B · Beep** | Beep reads the handbook → DMV exam, «СДАНО» stamp → instructor car rolls in, map pin drops → open road with confetti | The Beep mascot from the result memes (`design/memes/own/_src/beep.py`). The world slides past while Beep hops, changing pose mid-air |

Both continue into screenshot steps of the real app (Tests, Theory, Profile,
trial card removed), with the tab highlighted and a ring that springs between
tabs.

## Turning a draft into a video

- Record the page in a browser at 2× (Playwright `page.video` or a screen
  recording), one phone at a time. «Replay» restarts it.
- Before recording, check Apple's current App Preview specs: length limit,
  accepted resolutions per device size, and frame rate.
- Captions and screenshots are Russian. A preview for another storefront needs
  that locale's texts and screenshots (see
  `design/onboarding/_src/compose_shots.py`).
- Beep is our own art, so there's no rights question. The Rubik font is OFL.

## Files

- `story-drafts.html`: built page (self-contained: poses and screenshots embedded).
- `_src/story-drafts.template.html`: source, with `/*POSES*/` and `/*SHOTS*/` placeholders.
- `_src/poses.py`: renders the Beep poses to `poses.json` (uses `design/memes/own/_src/beep.py`).
- `_src/shots/`: composited screenshots.
- `_src/build.py`: `python3 design/video-ads/_src/build.py` rebuilds the page.
