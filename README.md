# R15 → R6 animation retargeter

Private Roblox animation converter with a reusable pesde package and a standalone Studio plugin.

- `package/`: the converter extracted from game-prototype's anim-utils. No game dependencies.
- `plugin/`: input resolution, conversion, undo, and comparison UI.
- `assets/`: reference R15/R6 rigs used by the preview.
- `tests/`: synthetic coverage and [animation fixtures with comparison videos](tests/fixtures/README.md).

## Build and install

```sh
mise run build
```

The plugin is written to `out/R15ToR6Retargeter.rbxm`. Copy it into Studio's local Plugins folder (on macOS, `~/Documents/Roblox/Plugins`) and reopen Studio. Open **R15 → R6 → Retarget** from the toolbar.

The panel opens docked on the right. This update resets the previous floating layout once; Studio remembers any position or size you choose afterward.

The plugin bundles the converter directly from `package/src`, so plugin and package share one implementation. It does not need this game or a pesde install to build.

## Use

Paste numeric IDs, `rbxassetid://` IDs, or Roblox asset URLs; separate entries with spaces, commas, semicolons, or new lines. Choose **Convert IDs**. Or select one or more `Animation` / `KeyframeSequence` instances in Explorer and choose **Convert selection**.

Successful results are created in a new `ServerStorage/RetargetedR6` folder and selected. A batch is one Studio undo/redo action. Input failures are reported individually; valid inputs still convert. Sources are never replaced. ID access uses the current Studio account and Roblox's normal asset permissions.

The comparison displays the source on the bundled R15 rig and the result on the R6 rig. Use Previous / Next to browse the batch and Pause / Play to inspect it. The waist option applies to the next conversion. Outputs are local KeyframeSequences; publishing an animation remains a separate Studio action.

Supported: standard body-pose KeyframeSequences. Unsupported: CurveAnimation, empty/non-R15 sequences, and arbitrary rig proportions. See [package/README.md](package/README.md) for the converter contract and calibration limits.

## Git dependency

In the consuming game's `[dependencies]`:

```toml
retarget_r15_to_r6 = { repo = "ssh://git@github.com/revvy02/r15-to-r6-animation-retargeter.git", rev = "<full-commit-sha>", path = "package" }
```

Use a pushed commit SHA and commit the game's generated pesde.lock. Each machine installing the dependency needs access to the private repository. `private = true` in the package manifest prevents registry publication.

## Validation

```sh
mise run test
mise run review
```

The test command opens its own temporary Studio and checks conversion invariants, bundled fixtures, ID parsing, a real Roblox animation fetch, mixed failures, and batch undo/redo. It requires Studio login/network access for the online case. The review command checks the live plugin. For native Studio captures, run `rodeo run --place --focus tests/review.luau -- --interactive`; it pauses at named `Workspace.RetargetReviewStage` attributes. Capture the plugin window, then set `Workspace.RetargetReviewContinue` to true to advance. Viewport-only captures exclude native dock widgets.

## Fixture videos

Walk, dance, and jump each include a source KeyframeSequence and a side-by-side MP4 in [tests/fixtures](tests/fixtures/README.md). Regenerate them after converter changes:

```sh
mise run videos
# Or update one fixture:
mise run videos -- --fixture rbx_animate_walk
```

Requires Roblox Studio, Python 3, and FFmpeg (`ffmpeg` and `ffprobe`) on PATH, plus the configured rodeo tool. You can also run `python3 tools/videos.py` directly, or `mise run --skip-tools videos` to bypass installation of unrelated tools inherited from a parent workspace. The task opens its own temporary Studio, converts the local fixtures using `package/src`, and renders both rigs at identical timestamps with a fixed camera fitted to the entire motion. Videos are 1280×720 H.264 at 24 FPS, at least six seconds and two cycles each. One-shot clips repeat for comparison. The R6-only negative fixture is skipped.

MP4s, poster images, and `generation.json` are kept in `tests/fixtures/videos/` alongside the source fixtures. Metadata records source/converter/renderer hashes, capture settings, and verified video properties. Intermediate captures stay under ignored `out/videos/`; pass `--keep-frames` to retain raw PNGs. Options include `--fps`, `--seconds`, `--cycles`, `--counter-waist`, and `--port` (uses that port and the next one). Keep the capture window at the same size throughout the run.
