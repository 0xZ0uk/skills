---
name: blender-fps-rigging
description: "Use when rigging/animating FPS weapons and arms in Blender."
platforms: [linux, macos, windows]
---

# Blender FPS Rigging & Animation

Distilled from David Stenfors' "Blender FPS Rigging & Animation Tutorial" (25-part course, ~5h34m). Full pipeline: gun rig → arms rig → controller bones/constraints → FPS animations → FBX export to Unity/UE5.

## When to use
- Rigging or skinning a first-person weapon or arms model in Blender
- Creating FPS animation sets (idle, walk, fire, reload)
- Exporting rigged Blender animations to Unity or Unreal Engine 5

## Course map (with per-phase references)
Load the matching reference before working:

| Phase | Content | Reference |
|---|---|---|
| Gun rig | armature chain, automatic weights, per-part bones (slide, mag, bolt) | references/rigging.md |
| Arms rig | controller bones, custom bone shapes, mirroring, IK constraints, FPS camera, skinning, gun import | references/rigging.md |
| Animation | workspace, reference pose, idle / walk / fire / reload | references/animation.md |
| Export & engines | FBX settings, Unity + UE5 import, import checklist | references/export.md |

## Golden rules (course's hard-won lessons)
- **Keyframes start on frame 1, never frame 0.** Frame 0 breaks engine loops; the dedicated export videos fix old files by selecting all keys → G → X → +1.
- **Extrude bones out of existing bones** — chains stay parented/connected automatically. Don't add orphan bones and re-parent.
- **Mirror instead of rebuilding**: rig the right arm fully with `.R` suffixes, then X-mirror to generate `.L`. Suffix naming must be correct before mirroring.
- **Arms and gun are separate rigs with separate actions**, exported as separate FBX files; sync by matching frame ranges in-engine.
- Keep one .blend per phase so a stuck student can open the finished file.

## Repo layout convention (when shipping this as a project)
```
fps-rig/
├── assets/weapon.fbx, arms.fbx  (exports)
├── blender/gun-rig.blend, arms-rig.blend, animations.blend
├── engine/  (Unity or UE5 project)
└── docs/rig-map.md  (bone inventory + what each controls)
```