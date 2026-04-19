// Content-hash cache-bust for the UI bundle.
//
// The HBS partials reference the CSS and JS by a plain path:
//   <link href="{{uiRootPath}}/css/site.css">
//   <script src="{{uiRootPath}}/js/site.js">
//
// Nginx serves /antora-assets/ with `expires 30d`, so returning
// visitors were getting up to 30 days of stale chrome after every
// UI bundle rebuild. Appending `?v=<sha1[:8]>` of each asset means
// the URL only changes when the asset itself changes, so cached
// visitors pick up real changes immediately and keep hitting the
// cache when nothing moved.
//
// Runs after build:copy + build:css and before build:zip.

import { createHash } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'

function hashOf(path) {
  return createHash('sha1').update(readFileSync(path)).digest('hex').slice(0, 8)
}

const cssHash = hashOf('build/bundle/css/site.css')
const jsHash = hashOf('build/bundle/js/site.js')

function stamp(partial, assetPath, hash) {
  const file = `build/bundle/partials/${partial}`
  const original = readFileSync(file, 'utf8')
  const stamped = original.replace(assetPath, `${assetPath}?v=${hash}`)
  if (stamped === original) {
    throw new Error(`stamp-version: ${assetPath} not found in ${partial}`)
  }
  writeFileSync(file, stamped)
}

stamp('head-styles.hbs', 'css/site.css', cssHash)
stamp('footer-scripts.hbs', 'js/site.js', jsHash)

console.log(`stamped css?v=${cssHash}  js?v=${jsHash}`)
