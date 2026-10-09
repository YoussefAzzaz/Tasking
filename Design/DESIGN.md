---
name: Obsidian Kinetic
colors:
  surface: '#051424'
  surface-dim: '#051424'
  surface-bright: '#2c3a4c'
  surface-container-lowest: '#010f1f'
  surface-container-low: '#0d1c2d'
  surface-container: '#122131'
  surface-container-high: '#1c2b3c'
  surface-container-highest: '#273647'
  on-surface: '#d4e4fa'
  on-surface-variant: '#c7c4d7'
  inverse-surface: '#d4e4fa'
  inverse-on-surface: '#233143'
  outline: '#908fa0'
  outline-variant: '#464554'
  surface-tint: '#c0c1ff'
  primary: '#c0c1ff'
  on-primary: '#1000a9'
  primary-container: '#8083ff'
  on-primary-container: '#0d0096'
  inverse-primary: '#494bd6'
  secondary: '#7bd0ff'
  on-secondary: '#00354a'
  secondary-container: '#00a6e0'
  on-secondary-container: '#00374d'
  tertiary: '#4edea3'
  on-tertiary: '#003824'
  tertiary-container: '#00885d'
  on-tertiary-container: '#000703'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e1e0ff'
  primary-fixed-dim: '#c0c1ff'
  on-primary-fixed: '#07006c'
  on-primary-fixed-variant: '#2f2ebe'
  secondary-fixed: '#c4e7ff'
  secondary-fixed-dim: '#7bd0ff'
  on-secondary-fixed: '#001e2c'
  on-secondary-fixed-variant: '#004c69'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#051424'
  on-background: '#d4e4fa'
  surface-variant: '#273647'
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.03em
  headline-xl-mobile:
    fontFamily: Space Grotesk
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.025em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.015em
  title-lg:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  title-md:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Space Mono
    fontSize: 13px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-md:
    fontFamily: Space Mono
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.06em
  label-sm:
    fontFamily: Space Mono
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 12px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  gutter-md: 1rem
  margin: 1rem
  margin-md: 1.5rem
  margin-lg: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system embodies high-velocity execution, executive focus, and visceral personal progression. Tailored for ambitious builders, knowledge workers, and technical operators, it strips away playful, cartoonish gamification in favor of a sleek, arcade-grade tactical cockpit. Every micro-interaction communicates immediate responsiveness, structural discipline, and momentum.

The design movement combines **Deep Surface Glassmorphism** with **Atmospheric Luminescence**:
- Ultra-dense obsidian and slate surfaces serve as an absorbing, non-distracting canvas.
- Glass panels float via subtle chromatic edge refraction, ultra-thin borders, and selective backdrop blur.
- Vibrant, laser-focused emissive accents (electric indigo, cyan, emerald, and auric amber) act as directional vectors for attention, signaling progress metrics, automated scheduling slots, and completion states without visual fatigue.
- Interfaces feel lightweight, tactile, and precision-engineered for instantaneous local-first state mutations.

## Colors

The palette relies on deep value contrasts where ambient blackness meets luminous state feedback.

### Surface Hierarchy
- **Canvas Base:** `#0B0F19` — Deep void obsidian anchoring high-contrast readability.
- **Glass Panel Surface:** `#131A2A` (rendered at varying alpha thresholds: `rgba(19, 26, 42, 0.75)` to `rgba(19, 26, 42, 0.92)`) for modal sheets, task rows, and timeblocks.
- **Surface Highlight / Elevation 2:** `#1E293B` — Used for nested elements, pressed states, and inner control segments.
- **Subtle Surface Strokes:** `rgba(255, 255, 255, 0.08)` to `rgba(99, 102, 241, 0.25)` for active bounding boxes.

### Functional Accents
- **Primary Kinetic Accent (`#6366F1` - Electric Violet / Indigo):** Primary calls to action, active navigation states, interactive scheduling nodes, and primary timeline markers.
- **Secondary Atmospheric Accent (`#38BDF8` - Cyan):** 15-minute auto-schedule engine badges, synchronized states, and analytical time-tracking metrics.
- **Growth & Gamification Core (`#10B981` / `#34D399` - Radiant Emerald):** XP tallies, streak multipliers, completed micro-actions, and daily progression meters.
- **Priority & Prestige Accent (`#F59E0B` / `#FBBF24` - Auric Amber):** Critical priorities, high-tier achievement unlocks, urgent deadlines, and milestone badges.

### Text & Contrast
- **Text High-Contrast:** `#F8FAFC` — Primary headings, active item names, numerical XP counters.
- **Text Muted:** `#94A3B8` — Secondary metrics, timestamps, contextual metadata.
- **Text Dim:** `#475569` — Disabled states, unfilled track guides, structural dividers.

## Typography

The typographic hierarchy bridges computational rigor and editorial punch:

- **Headline Font (`Space Grotesk`):** Delivers geometric confidence to milestone screens, level metrics, and daily summaries. Distinctive glyph architecture prevents the interface from feeling like generic corporate software.
- **Body Font (`Geist`):** Provides clinical, ultra-readable legibility across variable light settings, rapid vertical task scanning, and dense nested lists.
- **Label & Micro-Stat Font (`Space Mono`):** Applied exclusively to XP values, 15-minute quantum intervals (`09:15 - 09:30`), streak counters, status badges, and tag chips. The monospace cadence reinforces the feel of a precision engine.
- Tabular figures must be enabled for all numerical values to eliminate jitter during real-time counters and timer increments.

## Layout & Spacing

This design system employs an adaptable mobile-first layout engine based on a dynamic 4-column structure on mobile devices, expanding into a 6-to-8 column layout for tablets and expanded viewports.

### Grid & Margins
- **Mobile Handheld (360px - 480px):** 4 columns, `margin: 1rem` (16px), `gutter: 0.75rem` (12px). All main interaction zones sit within strict one-handed thumb arcs (bottom 60% of the viewport).
- **Tablet & Split-Screen (481px - 840px):** 6-8 columns, `margin-md: 1.5rem` (24px), `gutter-md: 1rem` (16px). Dual-pane configuration displays the 15-minute auto-scheduler alongside priority lists.

### Rhythmic Density
- **Micro Spacing (`0.25rem` to `0.5rem`):** Reserved for chip internal padding, icon-to-label gaps, and XP badge metrics.
- **Component Padding (`0.75rem` to `1rem`):** Establishes tight, modern spatial density inside glassy cards and timeblock slices without wasted vertical estate.
- **Stack Spacing (`1.5rem`):** Segregates distinct conceptual blocks (e.g., Streak Engine Header vs. Agenda Stream).

## Elevation & Depth

Depth is established strictly through light-transmitting surfaces, edge luminescence, and optical blurs rather than muddy drop shadows.

### Surface Tiers
- **Base Tier (Ground):** Solid `#0B0F19` void.
- **Glass Tier 1 (Timeline & Static Cards):** Background `rgba(19, 26, 42, 0.65)`, backdrop-filter `blur(16px)`, border `1px solid rgba(255, 255, 255, 0.06)`.
- **Glass Tier 2 (Interactive Modules & Active Task Rows):** Background `rgba(25, 34, 54, 0.82)`, backdrop-filter `blur(20px)`, border `1px solid rgba(255, 255, 255, 0.12)`.
- **Floating Overlays & Action Sheets:** Background `rgba(19, 26, 42, 0.94)`, backdrop-filter `blur(24px)`, outer border `1px solid rgba(99, 102, 241, 0.25)`.

### Emissive Lighting (Accented Glows)
- **XP / Streak Surge Glow:** Box shadow `0 0 24px -4px rgba(16, 185, 129, 0.35)`. Applied to completed milestones and current streak badges.
- **Active Schedule Node:** Box shadow `0 0 20px -4px rgba(56, 189, 248, 0.3)`. Applied to current 15-minute executing timeblock.
- **High-Priority Critical Aura:** Box shadow `0 0 20px -4px rgba(245, 158, 11, 0.3)`.

## Shapes

The geometric framework balances tactile ergonomic curvature with razor-sharp structural discipline. 

- **Cards and Structural Surfaces:** Leverage `0.5rem` (`8px`) to `1rem` (`16px`) radius values. This preserves clear perimeter definition across stacked glass panes and schedule timelines.
- **Chips, Badges, and Micro-Stats:** Pure pill shapes (`9999px` radius) to enforce immediate differentiation between organizational containers (cards) and actionable metadata (pills).
- **Control Targets:** Interactive segments, checkboxes, and inline action toggles adhere to a standardized `8px` corner radius to maintain a modern, engineered feel.

## Components

### Buttons & Interactive Controls
- **Primary Kinetic Action:** Solid `#6366F1` background, `#F8FAFC` label, crisp `8px` radius. Hover/active states trigger a radiant cyan-tinted inner glow (`inset 0 0 12px rgba(56, 189, 248, 0.4)`).
- **Secondary Glass Trigger:** Semi-transparent base `rgba(30, 41, 59, 0.6)`, `1px solid rgba(255, 255, 255, 0.1)`, `8px` radius.
- **Floating Execution Orb:** Pill-shaped quick-add button seated along the bottom navigation axis with a subtle indigo-cyan gradient border.

### Pill Tags & Status Chips
- Height constrained to `24px` or `28px`.
- Rendered with monospace styling (`Space Mono`, `label-sm` or `label-md`).
- Fully rounded (`border-radius: 9999px`) with 10% translucent accent fills (e.g., `rgba(245, 158, 11, 0.12)` for high-priority amber tags) accompanied by a solid colored leading indicator dot (4px).

### Gamified Progress & Streak Meters
- **Micro XP Bar:** Ultra-slim horizontal gauge (`4px` to `6px` height) with a deep `#1E293B` track. Filled via an emerald-to-cyan gradient (`#10B981` to `#38BDF8`) terminating in an emissive leading point.
- **Streak Node Badge:** Pill shape enclosing an active flame icon paired with an emerald counter. On streak milestones, cards gain a localized emerald rim light (`border-color: rgba(16, 185, 129, 0.4)`).
- **Level Progress Badge:** Monospaced level pill (`LVL 08`) featuring an integrated circular radial ring indicating percentage to next level.

### Checkboxes & Completion Nodes
- Custom `20x20px` geometric squares with `6px` radius.
- Inactive: Border `1.5px solid rgba(148, 163, 184, 0.3)`, interior transparent.
- Complete: Instant spring animation to solid `#10B981` fill with an obsidian checkmark icon, immediately emitting an ephemeral emerald shockwave ring.

### 15-Minute Auto-Schedule Blocks
- Sliced vertical cards representing 15-minute quanta.
- Standard blocks utilize glass tier 1 styling with a left-accent rail (`3px` width).
- Cyan rails indicate auto-scheduled AI allocations; Indigo rails denote locked user commitments.
- Currently executing timeblock features glowing edge treatment and dynamic real-time progress fill.

### Task Cards
- Glass Tier 1 background with an inner vertical padding of `12px` and horizontal padding of `14px`.
- Composed of three primary zones: Lead checkbox, body content (Geist title with optional secondary tag cluster), and trailing metadata (15m quantum tag + micro XP yield in Space Mono).