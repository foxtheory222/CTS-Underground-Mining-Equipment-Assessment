# CTS Underground Mining Equipment Assessment Design

## Source Of Truth

The attached product prompt is the approved V1 specification for App 1: `CTS Underground Mining Equipment Assessment`. This app remains a standalone Android tablet APK and public GitHub repository at `foxtheory222/CTS-Underground-Mining-Equipment-Assessment`.

## Architecture

The app reuses the seed's offline Flutter architecture: Riverpod, go_router, local SQLite-backed inspection records, inspection-scoped media folders, local PDF generation, ZIP export/import, and Android share handoff. The mining assessment is implemented as a data-driven template catalog so sections, item labels, required rules, machine-specific subsections, purpose options, health scores, recommendation rows, and cost forecast rows are declared in one place and reused by validation, tests, UI labels, and PDF/export metadata.

## Branding

The app display name is `CTS Underground Mining Equipment Assessment`. Report output uses `COMBINED TECHNICAL SERVICES` and the report title `UNDERGROUND MINING EQUIPMENT REBUILD ASSESSMENT & LIFE EXTENSION REPORT`. The public-facing logo asset and Android launcher icons use the supplied Combined Technical Services branding, not the seed app wording.

## Data And Status

Each inspection stores `templateKey = underground_mining_rebuild_life_extension`, `templateVersion = 1.0.0`, app name, created/updated/completed/emailed timestamps, generated PDF path, import metadata, permanent local document number, machine header fields, manual health scores, checklist responses, photos, action items, signatures, export records, and recent customer/site/inspector/recipient values. Editing an emailed or completed record clears generated/sent state until validation, signoff, PDF generation, and share confirmation are redone.

## Validation

Global item ratings support Good, Fair, Poor, N/A, and Not Inspected. Fair and Not Inspected require comments. Poor requires comment, photo, and action item. Critical/Out of Service is a separate toggle requiring comment, photo, action item, and the CTS/site escalation acknowledgement. Completion requires required header fields, at least one purpose, final CTS recommendation, manual health score fields, inspector typed name, drawn signature, and all flagged documentation.

## UI

The tablet UI remains landscape-first with a dashboard, list/search/filter, new/edit flow, persistent section navigation, review/completion surface, PDF/share/export actions, and settings/about. The editor presents the mining section list in the required order, health score controls, machine-type conditional content for Rock Scaler, Jumbo, Utility Vehicle, and Other, and a right-side validation/action/photo summary on wide layouts.

## Testing

Tests cover template completeness, document numbering, validation rules, manual score fields, action item generation, PDF/export filenames, status transitions, edit-after-email invalidation, autosave persistence, export/import conflict handling, duplicate-without-media behavior, widget navigation, and the end-to-end tablet flow. Final verification includes automated test commands, release APK build, and Android emulator matrix testing of settings/options.
