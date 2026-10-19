require "test_helper"

# Compiled output under app/javascript/controllers/ is committed (see
# DESIGN_PROPOSAL_FINAL.md's TypeScript section) - there's no deploy-time
# build step to regenerate it. That means it's possible to edit a .ts/.tsx
# source file, forget to run `npm run build`, and commit stale JS with
# nothing to catch it - there's no CI on this repo either. This test is
# that catch: it re-runs the real build and fails if the committed output
# doesn't match what the current source actually compiles to.
#
# Skips, rather than fails, when Node isn't installed - running the app
# and the rest of the test suite never requires it (see the three build
# questions answered in DESIGN_PROPOSAL_FINAL.md), so a machine without
# Node shouldn't fail a test over a dev-time tool it was never promised.
class BuildControllersTest < ActiveSupport::TestCase
  test "compiled controller output matches what the TypeScript source currently builds to" do
    skip "Node not installed - this check only runs where it's available" unless system("which node > /dev/null 2>&1")

    Dir.chdir(Rails.root) do
      typecheck_ok = system("npx tsc --noEmit", out: File::NULL, err: File::NULL)
      assert typecheck_ok, "tsc --noEmit failed - the TypeScript source itself doesn't type-check, independent of any drift"

      build_ok = system("node bin/build_controllers.js", out: File::NULL, err: File::NULL)
      assert build_ok, "the esbuild step itself failed to run"

      diff = `git diff --name-only -- app/javascript/controllers`
      assert diff.empty?,
        "app/javascript/controllers/*.js is out of sync with controllers_src/*.ts(x) - " \
        "rebuilding just changed: #{diff.split("\n").join(', ')}. " \
        "Run `npm run build` and commit the result."
    end
  end
end
