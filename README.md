# Live

Renoise Live Sequence Player

## Features

Effects:

- Note triggers
    - !1st pattern only
        `LT00`
    - nth pattern only
        `LTn0`
    - Play every xth pattern after y runs
        `LTyx`
        `LT21`  : Triggers the first pattern after 2 runs (`2:1`)
        `LT33`  : Triggers the third pattern after 3 runs (`3:3`)
    - Inverted (Don't play every xth pattern after y runs)
        `LIyx`
        `LI21`  : Triggers the first pattern after 2 runs (`2:1`)
        `LI33`  : Triggers the third pattern after 3 runs (`3:3`)
- Fills
    - Only play when not having a fill
        `LF00`
    - Only play when transitioning to another pattern
        `LF01`
- Automatically set next pattern
    - `LNxx`    : Go to pattern `xx` (in dec)
- Start track muted
    - `LM00`
    - `LMxx`    : Unmute after `xx` runs (in dec)

## Ideas

- Get text from song and translate to instructions per pattern
- Support for multi-column tracks
- Add mute / unmute buttons to UI
    - Queue mute / unmute
- Add fill button to UI

## Known issues

(todo)