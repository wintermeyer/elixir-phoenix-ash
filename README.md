# Elixir, Phoenix and Ash Beginner's Guide

Content is authored in AsciiDoc under `modules/ROOT/pages/` and rendered
by [Antora](https://antora.org). The visual chrome (Tailwind v4 theme,
sidebars, pagination, TOC) comes from the shared UI bundle at
[`wintermeyer/wincon-antora-ui`](https://github.com/wintermeyer/wincon-antora-ui),
which is also used by the Rails book at `/rails/book/`.

## Build

```sh
npm install                                          # installs Antora
npx antora --fetch antora-local-playbook.yml         # renders build/site/
```

`--fetch` refreshes both the content source and the UI bundle
(pulled from the `latest` release of wincon-antora-ui). Open
`build/site/index.html` to preview.

To render against the main branch on GitHub instead of the local
working copy:

```sh
npx antora --fetch antora-playbook.yml
```

## UI bundle changes

Edit `src/` in
[wintermeyer/wincon-antora-ui](https://github.com/wintermeyer/wincon-antora-ui)
and push to main. A GitHub Actions workflow rebuilds `ui-bundle.zip`
and re-uploads it to the `latest` release in ~30 seconds. The next
deploy of this book (or of the Rails book) picks it up.

For a tight local loop while editing the bundle, point this repo's
playbook at the UI bundle checkout:

```yaml
ui:
  bundle:
    url: /path/to/wincon-antora-ui/build/ui-bundle.zip
    snapshot: true
```

## Per-book chrome override

`scripts/fetch-partials.sh` pulls the canonical nav + footer from
[`wincon/priv/static/partials/`](https://github.com/wintermeyer/wincon/tree/main/priv/static/partials),
stamps `data-book-current="phoenix"` into the nav, and drops the files
into `ui-supplemental/partials/`. Antora's `ui.supplemental_files`
overlay then overrides the default `header-content.hbs` and
`footer-content.hbs` shipped with the UI bundle. The `ui-supplemental/`
directory is gitignored — it's generated at every deploy.

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`, which runs
on the self-hosted runner (label `books`) on bremen2. The runner
checks the repo out, runs `scripts/deploy.sh`, and publishes the
rendered site to `/var/www/phoenix-book/releases/<timestamp>/`.
An atomic symlink swap makes `/var/www/phoenix-book/current/`
point at the new release. The last five releases are kept.

`scripts/deploy.sh`:

1. Activates mise (Node 20 pinned in `.tool-versions`).
2. Calls `scripts/fetch-partials.sh` to pull the canonical nav/footer.
3. Runs `npm ci` and `npx antora --fetch antora-playbook.yml`.
4. Copies `build/site/` into the new release dir and swaps the
   `current` symlink.
5. Prunes old releases (keeps last 5).

A fetch failure in step 2 is non-fatal: Antora silently falls back to
the UI bundle's default partials (with an empty `data-book-current`).

## Nginx

The site is served under <https://wintermeyer-consulting.de/phoenix/book/>
via two location blocks on the `wintermeyer-consulting.de` vhost (one
for pages, one for `antora-assets/`). The old domain
<https://elixir-phoenix-ash.com> returns a path-preserving 301 to the
new location.
