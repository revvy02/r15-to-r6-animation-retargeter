# R15 → R6 animation retargeter

Private Roblox animation converter with a reusable pesde package and a standalone Studio plugin.

- `package/`: the converter extracted from game-prototype's anim-utils. No game dependencies.
- `plugin/`: input resolution, conversion, undo, and comparison UI.
- `assets/`: reference R15/R6 rigs used by the preview.
- `tests/`: synthetic coverage and four representative animation fixtures.
- `visual-reviews/ui/plugin/index.html`: visual review with full-resolution captures.

## Build and install

```sh
mise run build
```

The plugin is written to `out/R15ToR6Retargeter.rbxm`. Copy it into Studio's local Plugins folder (on macOS, `~/Documents/Roblox/Plugins`) and reopen Studio. Open **R15 → R6 → Retarget** from the toolbar.

The plugin bundles the converter directly from `package/src`, so plugin and package share one implementation. It does not need this game or a pesde install to build.

## Use

Paste numeric IDs, `rbxassetid://` IDs, or Roblox asset URLs; separate entries with spaces, commas, semicolons, or new lines. Choose **Convert IDs**. Or select one or more `Animation` / `KeyframeSequence` instances in Explorer and choose **Convert selection**.

Successful results are created in a new `ServerStorage/RetargetedR6` folder and selected. A batch is one Studio undo/redo action. Input failures are reported individually; valid inputs still convert. Sources are never replaced. ID access uses the current Studio account and Roblox's normal asset permissions.

The comparison displays the source on the bundled R15 rig and the result on the R6 rig. Use Previous / Next to browse the batch and Pause / Play to inspect it. The waist option applies to the next conversion. Outputs are local KeyframeSequences; publishing an animation remains a separate Studio action.

Supported: standard body-pose KeyframeSequences. Unsupported: CurveAnimation, empty/non-R15 sequences, and arbitrary rig proportions. See [package/README.md](package/README.md) for the converter contract and calibration limits.

## Git dependency

In the consuming game's `[dependencies]`:

```toml
r15_to_r6 = { repo = "ssh://git@github.com/revvy02/r15-to-r6-animation-retargeter.git", rev = "<full-commit-sha>", path = "package" }
```

Use a pushed commit SHA and commit the game's generated pesde.lock. Each machine installing the dependency needs access to the private repository. `private = true` in the package manifest prevents registry publication.

## Validation

```sh
mise run test
mise run review
```

The test command opens its own temporary Studio and checks conversion invariants, bundled fixtures, ID parsing, a real Roblox animation fetch, mixed failures, and batch undo/redo. It requires Studio login/network access for the online case. The review command checks the live plugin. For native Studio captures, run `rodeo run --place --focus tests/review.luau -- --interactive`; it pauses at named `Workspace.RetargetReviewStage` attributes. Capture the plugin window, then set `Workspace.RetargetReviewContinue` to true to advance. Screenshots live alongside the HTML review (viewport-only captures exclude native dock widgets).
