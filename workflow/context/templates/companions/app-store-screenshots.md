## app-store-screenshots (store screenshots, fallback route)

[ParthJadhav/app-store-screenshots](https://github.com/ParthJadhav/app-store-screenshots)
is a skill that scaffolds a local Next.js editor and renders App Store and Play
Store screenshot decks with device frames and themes.

- **Pencil first.** If this project has a `.pen` design source, make store
  screenshots with the `design-to-code` store flow instead. This skill is for
  apps without one.
- **Sibling folder, never the app repo.** The skill copies its template into the
  working directory and runs a dev server whose API routes write to disk
  (`/api/project`, `/api/upload`, `/api/upload-font`). Scaffold it next to the
  app (`mkdir ../<app>-store-screenshots && cd` there before invoking the
  skill), run it locally, never deploy it.
- **Feed it 3x captures.** Low-res captures upscale about 3x and blur. Use 3x
  exports or simulator screenshots, and tune each slide's transform: the
  defaults do not fit arbitrary content.
