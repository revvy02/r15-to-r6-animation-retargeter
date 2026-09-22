# R15 to R6 retargeting

`rvy/retarget_r15_to_r6` is a Roblox-target pesde package for converting an R15 `KeyframeSequence` into a new R6 sequence. No game hierarchy, asset fetching, plugin, or third-party dependencies are required.

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

The joint definitions are calibrated to the bundled reference R15 and R6 rigs. This is a lossy mapping from articulated R15 limbs onto rigid R6 limbs, not a universal avatar-proportion solver. Facial, finger, and other non-body pose channels are not transferred. CurveAnimation inputs are not supported. Existing sampling and easing behavior is preserved by this extraction.

The package is private and is consumed from Git; it is never published to a registry.
