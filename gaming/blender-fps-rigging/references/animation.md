# FPS Animations (idle, walk, fire, reload)

## Workspace setup (Parts 15–16)
- Keep Dope Sheet + Graph Editor side by side — timing lives in the Graph Editor.
- One Action per animation; name actions (`ArmIdle`, `GunWalk`, ...). Arms and gun get separate actions that stay in sync frame-to-frame.

## Reference & idle (Parts 17–18)
1. Pose the reference frame first: neutral FPS grip (gun center-right, arms bent naturally). Everything returns to this base.
2. Idle = subtle breathing/sway loop: small sine-like offsets on gun position + arm rotation; first frame = last frame for a seamless loop.

## Walk (Part 19)
Rhythmic up/down bob + slight roll on the gun, arms swaying through controller bones. Loop in place — locomotion is the engine's job; the animation only adds motion feel.

## Fire (Part 20, 34 min)
- Key pose structure: anticipation (slight recoil-load) → impact (sharp up kick) → recovery back to idle.
- Sharp = closely spaced keys; steepen the impact curve in the Graph Editor. Nudge the camera/rig on recoil too.
- Animate the weapon's moving parts: slide/bolt bone pulls back, mag moves.

## Reload (Part 21, 63 min)
Most detailed animation. Plan the timeline first: mag release → mag out → new mag in → charge → back to idle.
- Animate the hand controller between mag-well and off-screen (or a spare-hand mesh).
- Animate gun bones simultaneously: mag drops out, new mag seats, bolt/slide charges.
- Discrete phases with holds between them; a reload with no pauses reads as fast-forward. Ease in/out at each phase boundary.

## Loop hygiene (course's #1 export mistake)
- Every keyframe set starts on **frame 1**, not frame 0 (select all keys → G → X → +1).
- Timeline end = last keyframe of the longest action (e.g. arms end f57, gun ends f71 → set 71).
- First frame ≈ last frame for any looping action.