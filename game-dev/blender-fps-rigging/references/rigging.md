# Rigging & Skinning the Gun and Arms

## Concepts (Part 4)
- **Armature** = object containing bones; more bones = longer hierarchy under armature.
- Blender ships humanoid/face/animal rig presets (built-in add-on) — this course deliberately skips them and builds from single bones so you learn the mechanism.
- **Rigging** = building the armature + controls. **Skinning** = binding mesh weights to bones.
- Bones move/rotate anything (meshes, cameras, objects), not just meshes.

## Gun rig (Parts 5–6)
1. Import/prepare the weapon model; clean transforms (Ctrl+A → all).
2. Add armature, build the bone chain by **extruding** (E) from the first bone — magazine bone, slide/bolt bone, trigger, stock — so each animated part gets a bone.
3. Parent mesh to armature with automatic weights; hand-fix parts that deform wrong (slide, mag) with weight painting or parent-with-empty-groups + assign.
4. Verify by rotating test bones — weapon parts should follow cleanly.

## Arms rig (Parts 7–14)
1. Add armature for the right arm: shoulder → upper arm → forearm → hand bone chain, extruded end to end.
2. **Controller bones** (Part 8): separate control bones at wrist/elbow that drive the deformer bones. Animate the controllers, not the raw chain.
3. **Custom bone shapes** (Part 9): bone properties → custom shape; assign simple primitives so controllers stand out and you grab the right bone.
4. **Mirror** (Part 10): give bones `.R` suffixes, then X-axis mirror the armature to generate the left side with `.L` suffixes. Symmetrize, don't manually build the left arm.
5. **Constraints** (Part 11, 21 min): IK constraints on the controller chains driving the arm chains, copy rotation as needed, limit rotations so joints bend the right direction. Test each constraint before adding the next.
6. **First-person camera** (Part 12): camera parented to the rig so the view moves with the body — for previewing and rendering FPS shots.
7. **Skin the arms** (Part 13): parent arm → automatic weights, then weight paint (hands/grip region matters most). Rotate bones in pose mode to find torn weights; smooth via blur/weaken tools.
8. **Import the gun rig** (Part 14): append the gun + its rig into the arms scene; compose the grip pose, parent the gun to the hand bone. One file, one rig, ready for animation.

## Reference
Course source: David Stenfors, "Blender FPS Rigging & Animation Tutorial" (YouTube playlist, 25 parts).