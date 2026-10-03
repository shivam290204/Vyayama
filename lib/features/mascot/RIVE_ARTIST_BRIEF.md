# Rive artist brief: Vyayama mascot

Deliver one file: **`assets/rive/mascot.riv`**. The app loads it automatically.
Until it exists, the app draws a simple placeholder character.

## Character
- Fully **original**. Do not copy or imitate any existing mascot
  (for example Duolingo's owl) or other trademarked character.
- Friendly, rounded, playful. Reads clearly at 120 px and at 300 px.
- The placeholder is a round bean with a small sprout antenna, stubby arms
  and feet. You may redesign it, but keep the personality warm.
- No text inside the artboard. No body-shaming or insulting expressions:
  the sad and angry moods must stay playful and encouraging.
- Must look good on both light and dark app backgrounds (transparent artboard).

## Technical requirements
- Artboard: square, for example 512 x 512, transparent background.
- **State machine name: `MascotMachine`**
- **One number input named `mood`** (type: Number, not Boolean or Trigger).
- Every mood is a looping idle animation; blend between them (0.2 to 0.4 s).
- Keep the file small (under about 300 KB) and avoid heavy meshes.
- Avoid animation that flashes. The app may pause motion for users who ask
  for reduced motion.

## Mood values (input `mood`)

| Value | Mood | Look and motion |
|---|---|---|
| 0 | neutral | Calm idle, gentle breathing. Used while loading. |
| 1 | happy | Smile, light bounce, small blink cycle. |
| 2 | proud | Chest out, eyes happy-closed, big smile, slow nod. Workout done. |
| 3 | sad | Droopy antenna, eyebrows up in the middle, small frown, slow sway. Optional tear. Playful, not tragic. |
| 4 | angry | Puffed cheeks, steam puffs, brows angled down, little foot stomp. Comic, never scary. |
| 5 | sleepy | Half-closed eyes, slow breathing, floating "z" shapes. Sleep time. |
| 6 | celebrating | Jumping with arms up, open smile, confetti burst. Milestones and challenges. |
| 7 | worried | Wide eyes glancing sideways, sweat drop, small tremble. A friend sent a snap and the user has not yet. |

The Flutter side sets `mood` whenever the mascot's mood changes. Values outside
0 to 7 are never sent.

## Testing
Open the app in debug mode and use the "Debug: force mascot mood" panel
to preview every mood.
