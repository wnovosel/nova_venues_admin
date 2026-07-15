# Nova Venues Admin — Agent Operating Rules

## Product goal
Nova Venues Admin is a fast, premium hospitality operations app. It must prioritize getting work done. The visual target is the clarity of Flighty and the precision of Linear, with restrained Nova branding.

## Non-negotiable design rules
- Support Light, Dark, and System theme modes.
- Use neutral charcoal surfaces in dark mode and warm off-white surfaces in light mode.
- Use burgundy primarily for primary actions, active navigation, and important emphasis.
- Use semantic colors only for clear statuses: success, warning, critical, information.
- Use clean sans-serif typography for operational screens.
- Avoid fantasy, magical, rustic, gold-heavy, glass-heavy, gradient-heavy, or cinematic styling.
- Favor compact, scannable layouts over oversized decorative cards.
- Do not hardcode colors, spacing, radii, shadows, or typography inside feature screens.
- Reuse approved design-system components before creating new widgets.
- Preserve information density. Do not remove fields, buttons, data, or workflows to make a screen prettier.

## Engineering rules
- Preserve existing APIs, authentication, tenant behavior, permissions, and business logic.
- Do not modify backend contracts during UI migration.
- Do not add mock APIs or fake production data.
- Keep business logic out of widgets.
- Continue using the existing Provider and API service architecture unless a task explicitly changes it.
- Do not duplicate an existing component.
- Do not redesign the app shell, navigation, or core tokens from a feature-screen task.
- Make changes in small, reviewable batches.

## Required screen states
Every migrated screen must support, where applicable:
- initial loading
- refresh
- empty state
- populated state
- recoverable error
- disabled or unauthorized state
- success feedback
- destructive-action confirmation

## Accessibility and responsiveness
- Verify small-phone layouts and text scaling.
- Avoid clipped text and horizontal overflow.
- Maintain readable contrast in both themes.
- Use touch targets of at least 44 logical pixels for primary actions.
- Do not rely on color alone to communicate status.

## Validation commands
Run before completion:
- `dart format .`
- `flutter analyze`
- `flutter test`

If the full suite cannot run, document the exact blocker and run the narrowest relevant checks.

## Definition of done
- The assigned screens use the approved Nova design system.
- Light, Dark, and System modes work.
- Existing functionality is preserved.
- Loading, empty, error, success, and confirmation states are handled.
- No new hardcoded visual values remain in migrated feature widgets unless explicitly documented.
- Formatting, analysis, and tests pass or blockers are documented.
- Light and dark screenshots are captured for review.
- Changed files, checks run, and remaining risks are summarized.

## Stop conditions
Continue autonomously unless:
- an API contract is missing or contradictory;
- required credentials or external authorization are unavailable;
- a backend or database change is truly required;
- two repository requirements directly conflict.
