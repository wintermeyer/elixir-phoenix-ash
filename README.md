# Elixir, Phoenix and Ash Beginner's Guide

Content is authored in AsciiDoc under `modules/ROOT/pages/` and rendered
by [Antora](https://antora.org). The visual style matches
[wintermeyer-consulting.de](https://wintermeyer-consulting.de) and is
produced by a custom Tailwind CSS v4 UI bundle that lives in
`ui-bundle/`.

## Build

The site build is two steps: first build the UI bundle, then run Antora.

```sh
# 1. Build the UI bundle (produces ui-bundle/build/ui-bundle.zip)
cd ui-bundle
npm install
npm run build
cd ..

# 2. Render the site against the local source (build/site/)
npx antora --fetch antora-local-playbook.yml
```

Open `build/site/index.html` in a browser to preview.

To render the production playbook (pulls content from the remote repo
instead of the working directory), swap step 2 for:

```sh
npx antora --fetch antora-playbook.yml
```

## UI bundle development

Work on the chrome and styles lives in `ui-bundle/src/`:

- `css/site.css` — Tailwind v4 source (`@theme` tokens, `@custom-variant
  dark`, and `@apply`-scoped rules for Antora's class surface)
- `partials/header-content.hbs`, `partials/footer-content.hbs` — the
  wincon-matching top nav and four-column footer
- `partials/*.hbs`, `layouts/*.hbs`, `helpers/*.js`, `js/site.js`,
  `img/*.svg` — carried from the Antora default UI so Antora's internal
  plumbing and sidebar JS keep working

For a tight iteration loop:

```sh
cd ui-bundle
npm run dev      # Tailwind CLI in watch mode
# then, in another shell, rebuild the bundle + site on demand
npm run build && cd .. && npx antora --fetch antora-local-playbook.yml
```

Dark mode follows the OS `prefers-color-scheme`; there is no toggle.
