---
name: rtl-a11y
description: RTL and accessibility rules for this bilingual (English + Arabic) app that no design file specifies — EdgeInsetsDirectional / AlignmentDirectional / PositionedDirectional, which icons mirror and which don't, surviving 2.0 text scale, 48dp touch targets, Semantics labels on icon-only buttons, bidi-safe values, and testing in both cultures. Use on every widget, screen, card, dialog, icon, padding, alignment, arrow / chevron, tooltip, or overflow task, and whenever a request mentions Arabic, RTL, right-to-left, mirroring, direction, Directionality, "looks wrong in Arabic", "cut off", overflow, accessibility, a11y, screen reader, VoiceOver, TalkBack, font size, or text scale. Trigger without being asked: every design handoff this app receives is LTR at default text scale.
---

# RTL & accessibility

Text direction comes from the active locale: `AppearanceCubit` holds the locale (persisted in `app_settings`), `MaterialApp.router` receives it with `GlobalMaterialLocalizations`, and Flutter sets `Directionality` to RTL for Arabic. Everything below is what keeps a screen correct once that flip happens.

## Directional layout — physical values are bugs

| Never | Always |
|---|---|
| `EdgeInsets.only(left: …)` / `right:` / `EdgeInsets.fromLTRB` | `EdgeInsetsDirectional.only(start: …)` / `end:` / `.fromSTEB` |
| `Alignment.centerLeft` / `topRight` … | `AlignmentDirectional.centerStart` / `topEnd` … |
| `Positioned(left: …)` | `PositionedDirectional(start: …)` |
| `BorderRadius.only(topLeft: …)` on an asymmetric shape | `BorderRadiusDirectional.only(topStart: …)` |
| `TextAlign.left` / `right` | `TextAlign.start` / `end` |
| `TextDirection.ltr` / `rtl` anywhere in `lib/` | nothing — read `Directionality.of(context)` only to *decide*, never to *force* |

`EdgeInsets.symmetric` / `.all` are fine — they are symmetric. Colours still come from `ColorsManager` / `context.colors`, spacing from `verticalSpace` / `horizontalSpace`.

## Icons — which mirror

- **Mirror** under RTL: back / forward arrows, chevrons (`>` in a list row, expand/collapse pointing sideways), "send", "reply", "undo/redo", text-alignment and indent icons, anything that implies reading direction. Do it once: `Directionality.of(context) == TextDirection.rtl ? Transform.flip(flipX: true, child: icon) : icon` — or prefer a directional Material icon (`Icons.arrow_back` is already direction-aware via `Icons.adaptive` / `MatchTextDirection` on `Icon`).
- **Never mirror**: clocks, play/pause, the download arrow (it points down), checkmarks, logos, the app icon, progress rings, calendar, search, settings, folder, numbers-with-sign badges.
- A drop-down / expansion caret pointing **down** does not mirror.

## Text, numbers and bidi

- Values that start or end with neutrals (`245 MB`, `68%`, `18.4 MB/s`, `1080p`, `00:38`, `12/03/2026`) get scrambled under Arabic base direction. The shared formatters in `lib/core/helpers/formatters.dart` wrap them in U+2068…U+2069 isolates — always format through them. A raw URL or file path in an Arabic layout is shown in its own `Text` with `textDirection: TextDirection.ltr` (the one allowed literal, via the shared `LtrText` widget), never for prose.
- Video titles are user content in any script: never force their direction; let Flutter's bidi algorithm pick it (Arabic titles in an English UI must still read right-to-left).
- Every user-facing string goes through `context.l10n.<key>` (ARB). No concatenated translated fragments — use one parameterised message.

## Text scale — survive `textScaler` 2.0

- No fixed heights on containers that hold text; let the content size the box and cap with `ConstrainedBox(maxHeight:)` only where a real maximum exists.
- `maxLines: 1` + ellipsis is for secondary text only; titles, values and button labels must wrap or scale.
- Buttons and chips grow with their label; rows that must stay one line use `FittedBox` on the value, not a smaller font.
- Verify at 2.0 once per screen (device Settings › Display › Font size, or `MediaQuery(data: …copyWith(textScaler: TextScaler.linear(2)))` in a widget test).

## Touch targets and semantics (adopt on what you touch — no retrofit)

- Every tappable area is at least **48×48 dp** (`IconButton` does this; a bare `GestureDetector` around a 20px icon does not — pad it).
- Icon-only buttons get a `tooltip:` (Material announces it) or a `Semantics(label:)`; decorative images `ExcludeSemantics`; a card that is one tappable unit uses `MergeSemantics`.
- Colour is never the only signal — a status disc pairs with text or an icon (the score pills already do; keep it that way).

## Done means

Run the screen in **both locales** (Settings → Appearance → Language), both themes, and — on mobile — both orientations; on desktop, resize down to the minimum window. Say which of those were actually checked.
