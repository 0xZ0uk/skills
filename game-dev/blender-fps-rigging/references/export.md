# Export from Blender → Unity / UE5

## Export (Part 23) — one FBX per rig
Arms and gun export **separately** so each engine object animates independently.

For each export (arms then gun):
1. File → Export → FBX (.fbx).
2. **Limit to Selected Objects** = on (shift-select mesh + its armature only).
3. Export scale: match armature/units (default 0.01 usually fine for FBX in engines; verify size after import).
4. Include the actions belonging to that rig.
5. Path mode: copy embedded textures if materials matter.

## Unity import (Part 24)
- Drop both FBX files into `Assets/`. Rig tab: Animation Type = **Humanoid** if arms use a standard skeleton; else Generic with avatar.
- Prefab hierarchy: arms model + child gun, attach the ViewModel to the FPS controller camera.
- Animation tab per FBX: exported clips appear as idle/walk/fire/reload; set Unity-side loop points (or fix loops in Blender re-export).
- Animator: default state idle, idle↔walk on a speed parameter, triggers for fire/reload. Fire transitions: "has exit time" unchecked (instant reaction); reload→idle keeps exit time.

## UE5 import (Part 25, addendum video)
- Import both FBX through the Content Browser; UE imports skeleton + animation set per FBX.
- If the skeleton isn't Unreal-compatible, map to the UE5 default skeleton during import or correct bone names.
- Animation Blueprint state machine: idle default, walk on velocity, fire/reload as montage triggers.

## Checklist before any engine import
- [ ] Keyframes start at frame 1
- [ ] Timeline end = last driven keyframe
- [ ] Loops match on first/last frame
- [ ] Arms and gun exported as separate FBX
- [ ] Object scale sane after import (no 100× or 0.01×)
- [ ] Clips named after their actions