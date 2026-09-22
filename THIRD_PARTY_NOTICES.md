# Roblox reference assets

The MIT licenses in this repository cover its original converter, plugin, tooling, and documentation. They do not relicense Roblox-created content in the following files or the underlying Roblox content shown in comparison videos and screenshots.

## Reference rigs

- `assets/r15.rbxm`: Roblox R15 reference character, including its meshes, face, animation references, and stock `Animate` script.
- `assets/r6.rbxm`: Roblox R6 reference character, including its face, animation references, and stock `Animate` script.

The rigs are retained for Roblox Studio preview and development. The plugin removes their scripts from preview clones before use. Roblox retains its applicable rights to these assets and scripts.

## Animation fixtures

Each fixture contains an animation authored and published by **Roblox** (Roblox user ID `1`). The keyframe and pose data was checked against the corresponding source asset on 22 September 2026.

| Fixture | Roblox asset |
| --- | --- |
| `tests/fixtures/rbx_animate_walk.rbxm` | [Tony Walk — 10921541949](https://www.roblox.com/library/10921541949) |
| `tests/fixtures/rbx_animate_dance.rbxm` | [R15Dance1A — 507771019](https://www.roblox.com/library/507771019) |
| `tests/fixtures/rbx_animate_jump.rbxm` | [R15Jump — 507765000](https://www.roblox.com/library/507765000) |
| `tests/fixtures/r6_animate_idle1.rbxm` | [Idle1LoopAnimation — 180435571](https://www.roblox.com/library/180435571) |

The comparison videos and posters in `tests/fixtures/videos/` were generated using these animations and reference rigs. Attribution does not grant additional rights to the underlying Roblox content. See the [Roblox Terms of Use](https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use) for applicable terms.

## Package contents

The Wally and pesde packages contain the converter code and package documentation/metadata only. These reference rigs, their stock scripts, animation fixtures, and generated videos are excluded from both package distributions.
