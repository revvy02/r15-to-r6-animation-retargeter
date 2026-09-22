# R15 to R6 retargeting

Convert an R15 `KeyframeSequence` into a new R6 sequence. No game hierarchy, asset fetching, plugin, or third-party dependencies are required.

## Installation

In your `wally.toml`:

```toml
[dependencies]
retarget_r15_to_r6 = "revvy02/retarget-r15-to-r6@0.1.0"
```

Run `wally install`, then require `Packages.retarget_r15_to_r6`.

The same source is available as the pesde Git package `rvy/retarget_r15_to_r6`:

```toml
[dependencies]
retarget_r15_to_r6 = { repo = "https://github.com/revvy02/r15-to-r6-animation-retargeter", rev = "<full-commit-sha>", path = "package" }
```

Git installation requires repository access while the source repository is private.

## Usage

```luau
local retarget = require(path.to.retarget_r15_to_r6)
local converted = retarget(sequence, { counterWaistSwingOnLegs = false })
if converted then
    converted.Parent = destination
end
```

`retarget(sequence: KeyframeSequence, options: Options?): KeyframeSequence?`

- Returns a detached clone with R6 poses, or `nil` if the input has no recognized R15 body poses.
- Leaves the input unchanged. The input and its relevant descendants must be Archivable.
- Preserves sequence loop/priority, attributes, keyframe times/names, and keyframe markers through cloning. Names the result `<source>_Precise` for compatibility.
- `counterWaistSwingOnLegs` defaults to `false`; enabling it adds compensating leg motion when the R15 waist animates but its legs do not.
- Callers own and must eventually parent or destroy returned instances.

## Scope

The joint definitions are calibrated to the repository's reference R15 and R6 rigs. This is a lossy mapping from articulated R15 limbs onto rigid R6 limbs, not a universal avatar-proportion solver. Facial, finger, and other non-body pose channels are not transferred. CurveAnimation inputs are not supported. Existing sampling and easing behavior is preserved by this extraction.

## License

MIT; see [LICENSE](LICENSE). The published package contains the converter, this documentation, its license, and package metadata. Roblox rigs, animation fixtures, videos, and the Studio plugin are not included.

`private = true` in `pesde.toml` prevents publication to the pesde registry. Wally publication uses the separate `wally.toml` manifest.
