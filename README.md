# Live

_Renoise Live Sequence Player_

## What is it?

This is a tool to use Renoise as an advanced sequencer that you can use for live performances. It's heavily inspired on
sequencers from existing grooveboxes, which means it's always a pattern on loop. You can set different conditions on 
how a pattern behaves in a loop with the `Lxxx`-effects, that both apply to columns and tracks.

## How does it work?

The plugin is accessible under `Tools > Live`, and basically does the following:

- The **only** pattern that is every playing is pattern **0**.
- The tool copy/pastes the source pattern the pattern 0 every time a loop has ended or when a fill / transition is triggered.
- It is during this copy/paste event that `Lxxx`-effects are processed and your pattern is mutated.

This basically means that you need to use Renoise in a slightly different way than you're used to:

- Don't put stuff in pattern 0: it **will** get overwritten by this tool.
- It's pretty useless to play a pattern outside of the live tool, because the `Lxxx`-conditions are only triggered when you start your project from the Live-tool (e.g. all notes will be triggered at once).
- It **is** possible to live edit: just start the live tool, navigate to the pattern you want to edit and start editing. Just be aware that at all times it's pattern 0 that is playing, and your work will only be copy/pasted/processed to pattern 0 the moment the pattern stops.

## Features

This tool adds the following effects to the pattern editor:

- The following effects are applicable to both **columns** and **tracks**:
    - Note triggers
        - 1st pattern only
            `LT01`
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
    - Start muted
        - `LM00`
        - `LMxx`    : Unmute after `xx` runs (in dec)
- The following effects are applicable to **only tracks**:
    - Automatically set next pattern
        - `LNxx`    : Set pattern `xx` (in dec) the next one in the queue.
    - Set pattern play count
        - `LPxx`    : Set pattern play count to `xx` (transitions will be triggered in the last count)
    - Cutoff pattern (generate polyrhythm)
        - `LC00`    : Cut off (and repeat) the pattern from this point. This is up to but not included, so a cut on line 4 would repeat lines 1,2 and 3; effectively creating a [polyrhythm](https://en.wikipedia.org/wiki/Polyrhythm). Triggs (`LT`) and inverted triggs (`LI`) are supported; fills (`LF`) and muting (`LM`) are not.

## Ideas

This is a rough lists of ideas that I want to add to this plugin in the future:

- Get text from song and translate to instructions per pattern
- Add mute / unmute buttons to UI
    - Queue mute / unmute
        - When queueing mute, do play the first note before muting    
- Add fill button to UI
    - So you can trigger a fill without a transition
- Add trig condition that only plays on the first pattern after a fill
    - suggestion: `LF02`
- Add trig condition that doesn't plays on the first pattern after a fill
    - suggestion: `LF03`
- Stutter / randomize track

## Known issues & limitations

- Things break when loading a new song while the Live dialog is open. Close the dialog before opening a new song.
- Line effects are only measured on effect column 1
- Fills don't work in tracks that are cut with the `LC` command
- Muting in tracks don't work in tracks that are cut with the `LC` command
- When live-editing a track with a `LC` command, funky things will happen due to the virtual counting.
- Possibly a Renoise bug, but when you delete an effect from a track, the `L` in the FX column changes (to a `K` for example).