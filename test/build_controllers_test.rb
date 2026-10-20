require "test_helper"
require "tmpdir"

# Compiled output under app/javascript/controllers/ is committed (see
# DESIGN_PROPOSAL_FINAL.md's TypeScript section) - there's no deploy-time
# build step to regenerate it. That means it's possible to edit a .ts/.tsx
# source file, forget to run `npm run build`, and commit stale JS with
# nothing to catch it - there's no CI on this repo either. This test is
# that catch: it rebuilds into a scratch directory and compares the result
# to the committed output, without ever touching app/javascript/controllers/
# or relying on git's index (so running this test can't silently overwrite
# the committed JS, and it can't fail just because a correct rebuild hasn't
# been staged yet).
#
# Skips, rather than fails, unless node_modules is actually installed
# locally - running the app and the rest of the test suite never requires
# Node (see the three build questions answered in DESIGN_PROPOSAL_FINAL.md),
# so a machine without it shouldn't fail a test over a dev-time tool it was
# never promised. Calling node_modules/.bin/tsc directly, rather than `npx
# tsc`, also means this never tries to download TypeScript on the fly.
class BuildControllersTest < ActiveSupport::TestCase
  test "compiled controller output matches what the TypeScript source currently builds to" do
    tsc = Rails.root.join("node_modules/.bin/tsc")
    skip "node_modules not installed - this check only runs where the local toolchain is available" unless tsc.exist?

    Dir.chdir(Rails.root) do
      typecheck_ok = system(tsc.to_s, "--noEmit", out: File::NULL, err: File::NULL)
      assert typecheck_ok, "tsc --noEmit failed - the TypeScript source itself doesn't type-check, independent of any drift"

      Dir.mktmpdir do |scratch_dir|
        build_ok = system("node", "bin/build_controllers.js", scratch_dir, out: File::NULL, err: File::NULL)
        assert build_ok, "the esbuild step itself failed to run"

        committed_dir = Rails.root.join("app/javascript/controllers")
        built_names = Dir.glob("#{scratch_dir}/*.js").map { |f| File.basename(f) }
        drifted = built_names.reject do |name|
          committed_path = committed_dir.join(name)
          committed_path.exist? && File.read(File.join(scratch_dir, name)) == File.read(committed_path)
        end

        assert drifted.empty?,
          "app/javascript/controllers/*.js is out of sync with controllers_src/*.ts(x) - " \
          "rebuilding produces different output for: #{drifted.join(', ')}. " \
          "Run `npm run build` and commit the result."
      end
    end
  end
end
