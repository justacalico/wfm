# WFM landing page

Standalone Flutter web page served at the site root; the app itself lives under
`/app/`. Shows a short feature overview, screenshots, and the latest releases
fetched from the GitLab API.

## Develop

```sh
flutter pub get
flutter run -d chrome
```

## Test

```sh
flutter test                    # widget + golden tests
flutter test --update-goldens   # regenerate test/goldens/*.png
```

## Layout

- `lib/main.dart` - page layout, theme and locale switching
- `lib/showcase.dart` - hand-drawn feature mockups
- `lib/releases.dart` - GitLab releases fetcher (injected in tests)
- `lib/l10n/` - own ARB set (en, en_GB, zh, ru, ga), separate from the app
- `assets/screenshots/` - app golden PNGs, refreshed from `../test/goldens/`
  by CI on deploy
- `web/` - index.html, manifest and icons

All user-facing strings go through the ARB files; the release fetcher is
injected so tests never hit the network.
