# 5. Design system

Code: [`app/lib/core/theme`](../app/lib/core/theme) and [`app/lib/core/widgets`](../app/lib/core/widgets).

## 5.1 Brand

* **Name:** Sanad (سند, "support").
* **Mark:** a white medical cross held by a supporting arc on a blue rounded
  tile (`SanadLogo`; app icons generated from the same drawing).
* **Tone:** calm, clinical, trustworthy. Blue for the brand and primary actions,
  white surfaces, generous spacing.

## 5.2 Colour tokens (`AppColors`)

| Token | Hex | Use |
|-------|-----|-----|
| `primary` | `#1A56DB` | Primary buttons, links, selected states |
| `primaryDark` | `#1E3A8A` | Header gradient, strong text on soft blue |
| `primarySoft` | `#E8F0FE` | Selected chips, icon tiles, totals bar |
| `background` | `#F5F7FB` | Screen background |
| `surface` | `#FFFFFF` | Cards, inputs, sheets |
| `border` | `#E2E8F0` | Card and input outlines |
| `textPrimary` / `textSecondary` / `textMuted` | `#0F172A` / `#475569` / `#64748B` | Text hierarchy |
| `success` / `successSoft` | `#15803D` / `#E7F6EC` | Saved, cash |
| `warning` / `warningSoft` | `#B45309` / `#FEF3E2` | Offline queue, needs review |
| `error` / `errorSoft` | `#DC2626` / `#FDECEC` | Errors, destructive actions |
| `electronic` / `electronicSoft` | `#6D28D9` / `#F1EAFE` | Electronic payment |

Status colours are always paired with an icon and a label, never colour
alone. Text and background pairs meet WCAG AA contrast.

## 5.3 Typography

**Cairo** (bundled, OFL), which covers Arabic and Latin with matching metrics.
Scale: headline 22/700 · title 20/700 · title-medium 16/600 · body 16 & 14/400 ·
label 15/600 · caption 12.5. Phone numbers use tabular figures and always
render left-to-right, also in Arabic. User-entered text takes its own
direction (`textDirectionOf`), so mixed Arabic/Latin addresses aren't reordered.

## 5.4 Spacing, shape, touch

* 4-pt scale: 4 · 8 · 12 · 16 · 20 · 24 · 32. Page padding 16.
* Radius: inputs/buttons 12, cards 16, sheets 24, pills 999.
* Touch targets ≥ 48 px. Primary buttons are 52 px high and full width.
  Payment options are 60 px high.
* Elevation: flat cards with 1 px borders; shadows only on the sticky bottom
  action bar and FABs.

## 5.5 Components

| Component | Purpose |
|-----------|---------|
| `AppTextField` | Labelled input with helper/error text, "(Optional)" suffix |
| `PickerField` + `showSearchablePicker` | Input-looking field that opens a searchable bottom sheet, with an optional **+ Add “…”** row |
| `PrimaryButton` | Full-width button with a built-in loading state |
| `BottomAction` | Sticky bottom bar holding the screen's main action |
| `SectionCard`, `SectionHeader`, `InfoRow` | Grouped content, label/value rows |
| `StatTile` | Dashboard metric |
| `StatusChip`, `PaymentChip`, `SyncChip` | Small labelled statuses |
| `CustomerTile`, `CustomerSummaryCard`, `RecordTile` | Domain list items: name **and** phone always together |
| `EmptyView`, `ErrorView`, `LoadingView`, `InlineBanner` | Empty, error (with retry), loading and banner states |
| `context.showSuccess / showFailure / confirm` | Snackbars and confirmation dialogs |
| `SanadLogo`, `InitialsAvatar` | Brand mark, avatars |

## 5.6 States every screen handles

Loading (spinner or kept previous data while refreshing) · empty (icon, title,
explanation, call to action) · error (localised message + retry) · offline
(banner) · validation (inline, next to the field, cleared as the user fixes
it) · success (snackbar or success screen) · destructive confirmation (red
button in a dialog).

## 5.7 Localisation and RTL

English and Arabic with full RTL mirroring (navigation, icons, chevrons,
alignment). Language follows the device unless set in Settings. Excel exports
use the app language (RTL sheets in Arabic).

## 5.8 Motion

Platform-default transitions only. No decorative animation. Loading
indicators appear only while waiting on the network.
