# Nova Venues Admin UI System

## Product direction
Nova Venues Admin is an operational command center for hospitality businesses. The interface should feel fast, calm, precise, and unmistakably useful.

Primary references:
- Flighty: timelines, status, complex data made immediately understandable.
- Linear: restraint, speed, compact information density, precise interaction.
- Perplexity: structured intelligence blocks and clear inline actions.
- Spotify: use only for event imagery, campaign media, and dynamic color accents.

The product must not drift into Project Wonder fantasy styling.

## Theme strategy
Support three user-selectable modes:
- Light
- Dark
- System

Persist the preference locally. Theme changes should apply immediately without restarting the app.

### Light theme
- Canvas: warm off-white, not pure white.
- Surfaces: white and subtle warm-gray elevations.
- Text: near-black charcoal.
- Dividers: soft neutral gray.
- Primary action: Nova burgundy.

### Dark theme
- Canvas: neutral charcoal, not textured or blue-black.
- Surfaces: progressively lighter charcoal layers.
- Text: soft white, not pure white everywhere.
- Dividers: low-contrast neutral gray.
- Primary action: Nova burgundy with accessible contrast.

## Foundation tokens
Create centralized tokens for:
- color
- typography
- spacing
- radius
- elevation
- motion
- icon sizing

Recommended spacing scale: 4, 8, 12, 16, 20, 24, 32, 40.
Recommended radii: 8 controls, 12 inputs/buttons, 16 cards, 20 feature panels, 24 sheets.
Recommended motion: 160–240 ms for ordinary transitions, restrained spring motion for sheets.

## Typography
Use a clean sans-serif throughout operational screens. Use tabular figures for revenue, attendance, inventory, and percentages.

Hierarchy:
- Display: greetings and major page titles.
- Heading: section titles.
- Body: normal content.
- Label: controls, metadata, and status.
- Data: large metrics with tabular numerals.

Avoid decorative serif typography on work screens.

## Navigation
Primary mobile navigation:
1. Today
2. Inbox
3. Operate
4. Grow
5. More

Operate contains Events, Reservations, Rentals, Vendors, Hiring, Calendar, Wine Club, Inventory, and other operational modules.

Grow contains Marketing, Snap & Post, Loyalty, Gift Cards, campaigns, and metrics.

More contains Settings, Appearance, Staff Access, Accounting, Displays, Support, and tenant switching.

Do not use a large drawer as the primary navigation model.

## Core components
Build and reuse:
- NovaAppShell
- NovaBottomNavigation
- NovaPageHeader
- NovaSectionHeader
- NovaCard
- NovaMetricTile
- NovaActionRow
- NovaStatusBadge
- NovaTimeline
- NovaButton
- NovaIconButton
- NovaTextField
- NovaSearchField
- NovaFilterBar
- NovaEmptyState
- NovaErrorState
- NovaLoadingState
- NovaConfirmSheet
- NovaAppearanceSelector

## Screen principles
- Information first, decoration second.
- Show important actions inline.
- Prefer compact rows for work queues.
- Use cards only when grouping improves comprehension.
- Use event imagery on event-focused screens, not throughout the app.
- Use status colors sparingly and consistently.
- Write summaries as plain operational language, not AI-sounding prose.

## Gold-standard screens
The first approved reference screens are:
1. Today
2. Events
3. Inbox

These establish the patterns all later screens must follow.

## Screenshot requirements
For each migrated screen capture:
- light mode
- dark mode
- populated state
- empty state where practical
- narrow-phone layout

Review screenshots for clipping, overflow, weak contrast, inconsistent padding, and unnecessary visual noise.
