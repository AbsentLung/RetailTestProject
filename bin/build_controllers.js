// Compiles app/javascript/controllers_src/*.{ts,tsx} into plain ES modules
// under app/javascript/controllers/, where importmap-rails already expects
// Stimulus controllers to live (config/importmap.rb's pin_all_from).
//
// Deliberately bundle: false - this strips types and transforms JSX, it
// doesn't bundle. Bare imports like "react" stay as-is in the output and
// resolve in the browser via the importmap, exactly like every other
// pinned package already does. `tsc --noEmit` (run separately, see
// package.json's "build" script) is what actually catches type errors;
// esbuild here only emits JavaScript, it doesn't type-check.
import { build } from "esbuild"
import { readdirSync } from "fs"
import { fileURLToPath } from "url"
import path from "path"

const here = path.dirname(fileURLToPath(import.meta.url))
const srcDir = path.join(here, "..", "app", "javascript", "controllers_src")
// Optional override (an absolute path) so the build-drift test can build
// into a scratch directory and diff it against the committed output,
// instead of overwriting the committed output to find out it drifted.
const outDir = process.argv[2] || path.join(here, "..", "app", "javascript", "controllers")

const entryPoints = readdirSync(srcDir)
  .filter((f) => f.endsWith(".ts") || f.endsWith(".tsx"))
  .map((f) => path.join(srcDir, f))

if (entryPoints.length === 0) {
  console.log("No controller sources found in", srcDir)
  process.exit(0)
}

await build({
  entryPoints,
  outdir: outDir,
  bundle: false,
  format: "esm",
  target: "es2022",
  jsx: "automatic",
  loader: { ".ts": "ts", ".tsx": "tsx" },
  logLevel: "info",
})
