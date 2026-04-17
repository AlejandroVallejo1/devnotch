# Marketing mockups

Two pixel-accurate mockups of DevNotch, rendered in HTML/CSS. Open one in
Chrome / Safari, press ⌃⌘F for fullscreen, then ⇧⌘4 + Space to screenshot
the whole window. Result is marketing-ready.

## Files

- **`hero-sessions.html`** — the Sessions tab pill sitting above a realistic
  fake VS Code window (editor + sidebar + terminal showing a `claude --resume`
  in action). Best as the **main README hero image**.
- **`hero-usage.html`** — the Usage tab pill with all 4 live bars
  (session / weekly / Sonnet-only / extra credits at 104%) on a clean dark
  gradient. Best for the "live plan meter" section or for Twitter/LinkedIn
  launch posts.

## Recommended usage

- Save at **2×** resolution for retina: Chrome DevTools → toggle device toolbar
  → set 1600×1000 @ 2× → ⇧⌘P → "Capture full size screenshot".
- Replace `docs/preview.png` with the hero-sessions shot (that's what the
  README `![preview]` tag points at).
- For Product Hunt / social, crop the tagline in or out depending on format.

## Tweaks you might want

Every color and measurement is defined in the `:root` variables at the top
of each file, matching `DS.Palette` from the actual app:

- `--coral` (Anthropic signature `#D97757`) — accent + "live" badge
- `--blue` (`#4D7EEB`) — Claude progress-bar blue
- `--bg` (`#1A1918`) — warm near-black pill fill
- `--cream` (`#F5F1E8`) — primary text

The row titles and numbers in `hero-sessions.html` are fake but believable —
swap them for your own real recent session titles before screenshotting if
you want it to be truthful.
