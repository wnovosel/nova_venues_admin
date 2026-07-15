# Codex Task Prompts — Nova Venues Admin

## Task 1: Design-system foundation

Implement the Nova Venues Admin design-system foundation only.

Read `AGENTS.md`, `docs/nova_ui/NOVA_UI_SYSTEM.md`, and `docs/nova_ui/UI_MIGRATION_MANIFEST.yaml` before coding.

Scope:
- Create centralized color, spacing, radius, typography, elevation, and motion tokens.
- Implement Light, Dark, and System theme modes.
- Persist the selected appearance locally.
- Add a reusable appearance selector.
- Create the approved shared components listed in the UI system document.
- Refactor the app shell and navigation to support Today, Inbox, Operate, Grow, and More.
- Fix navigation state so the selected destination always matches the visible screen.
- Preserve all existing screens, APIs, authentication, and business logic.

Do not redesign feature screens in this task except where minimal integration is required.

Validate with `dart format .`, `flutter analyze`, and `flutter test`. Capture light and dark screenshots of the shell and appearance selector.

## Task 2: Gold-standard Today screen

Migrate `lib/screens/morning/morning_screen.dart` into the approved Today experience.

Preserve every existing data source and action. Reuse the shared design system. Establish the canonical patterns for compact metrics, operational timeline, needs-attention queue, upcoming events, recent activity, loading, empty, error, and refresh states.

The screen must be operational, not decorative. Avoid serif typography, gold, fantasy textures, oversized cards, and unnecessary gradients.

Capture light and dark screenshots and verify a narrow-phone layout.

## Task 3: Gold-standard Events and Inbox

Migrate Events and Inbox as the remaining reference screens.

Events must establish search, filters, event summaries, status badges, progress, and detail navigation. Inbox must establish category tabs, unread badges, communication previews, and inline actions.

Preserve all current workflows and APIs. Do not modify the app shell or token definitions unless fixing a demonstrated shared defect.

## Batch task template

Migrate the assigned screens in `UI_MIGRATION_MANIFEST.yaml` to the approved Nova UI system.

Work autonomously until the assigned batch is complete. Preserve all APIs, fields, actions, permissions, and tenant behavior. Reuse approved components and do not introduce parallel visual patterns. Support Light, Dark, and System appearances. Handle loading, empty, populated, error, success, disabled, and destructive-confirmation states where applicable.

Run formatting, analysis, and tests. Capture light and dark screenshots. Stop only for a missing/contradictory API contract, unavailable credentials, a genuinely required backend change, or conflicting repository requirements.

At completion report screens completed, components reused/added, files changed, checks run, screenshots, unresolved risks, and any manifest items not completed.
