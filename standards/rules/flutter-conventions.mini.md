---
name: flutter-conventions
description: Flutter/Dart idioms — widget rebuilds, state-management discipline, dispose hygiene, async BuildContext safety
applies_to:
  frameworks: ["flutter"]
  languages: []
  architectures: ["frontend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Flutter conventions

Flutter rewards working *with* the widget tree's rebuild model. Code that
fights it becomes janky the moment a screen grows past a demo.

## State management — match, don't prescribe

This repo already has a state-management choice (Provider, Riverpod, BLoC,
`get_it`, or none) — check `pubspec.yaml`'s `dependencies:` before writing a
single stateful widget. Never introduce a second stack for one feature; it
means every future file has to guess which pattern it's in. If the repo has
no codegen (`build_runner`, `freezed`), don't add one for a single feature
either — that's a project-wide decision, not a per-PR one.

## Widget-level checks

- **`const` constructors** wherever the widget's inputs are compile-time
  constant. Skipping `const` on a static widget is a needless rebuild.
- **No business logic in `build()`** — a `build()` method that branches on
  API/network state instead of reading it from the state layer rebuilds on
  every frame it doesn't need to and is untestable without a full widget tree.
- **`ListView.builder`/`GridView.builder`**, not an unbounded `Column` of
  children, for any list whose length depends on data. Unbounded children in
  a scroll view is the "RenderFlex overflowed" / "unbounded height" class of
  bug, not a corner case.
- **Keys** (`ValueKey`/`ObjectKey`) on list items that can reorder, insert, or
  delete — without one, Flutter reconciles by position and animates/rebuilds
  the wrong element.

## Dispose discipline

Every `AnimationController`, `TextEditingController`, `FocusNode`, and
`StreamSubscription` created in `initState()` (or a controller's own `init`)
must be released in `dispose()`. Not releasing one is a leak that surfaces as
"used after dispose" or a growing memory footprint under widget churn, not
immediately.

## Async + `BuildContext`

Never use a `BuildContext` after an `await` without checking `mounted` first
(`StatefulWidget`) or capturing what you need before the gap. The widget can
be disposed while the future is in flight; using its context after that
throws in debug and silently misbehaves in release.

## `setState` scope

Call `setState` with the narrowest closure that actually changes — wrapping
a large `build()` subtree in one `setState`-driven widget when only a leaf
needs to rebuild costs real frame time on longer lists and animated screens.

## Stack-specific don'ts

- Don't rebuild the whole screen from a single top-level `StatefulWidget`
  when a `Consumer`/`Selector`/BLoC listener scoped to the changing subtree
  is available in the repo's existing stack.
- Don't call `setState` after the widget is unmounted — combine with the
  `BuildContext`/`mounted` rule above.
- Don't hardcode platform-specific spacing/sizing; use the repo's existing
  responsive helper (e.g. `flutter_screenutil`) if one is already a
  dependency, rather than a second sizing convention.

## See also

- [`testing-pyramid.mini.md`](./testing-pyramid.mini.md) — widget vs.
  integration test balance applies here same as any UI layer.
- Flutter docs: https://docs.flutter.dev
- Dart docs: https://dart.dev/guides
