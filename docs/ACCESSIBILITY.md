# Accessibility: what is built, what is not yet verified

Built into the code:
- Every status uses an icon **and** words (`statusStyle`), never colour alone. Charts show counts and percentages as text.
- Choice lists are 56 dp tall tap targets with selected state as icon + bold + border, and screen-reader `checked` / `inMutuallyExclusiveGroup` semantics (`ChoiceTile`). The app has no dropdown menus by design.
- Headings use `Semantics(header: true)`. Cards expose a single readable label (reference, service, status, next action).
- Text size setting (100/115/130% on top of the system scale); layouts scroll rather than clip.
- Reduce-motion setting and respect for the system "remove animations" flag (instant page transitions).
- Light, dark and system themes with separate semantic colours per mode; focus colour set in the theme.
- Form errors are plain sentences, shown near the field, and announced as live regions in sheets.
- Navigation: bottom bar on phones, rail on wide screens, a Home button on every non-home screen.

Not yet verified (needs a real device or tool):
- TalkBack and VoiceOver walkthroughs.
- Keyboard-only walkthrough and focus order on Windows/Linux/macOS.
- Measured contrast for every colour pair (palette chosen for ≥4.5:1 but not measured).
- Layout at 200% text on a 360 px phone.
Run these and record results here before claiming WCAG 2.2 AA conformance.
