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
- It is during this copy/paste event that [some](##-features) `Zxxx`-effects are processed and your pattern is mutated.

This basically means that you need to use Renoise in a slightly different way than you're used to:

- Don't put stuff in pattern 0: it **will** get overwritten by this tool.
- It's pretty useless to play a pattern outside of the live tool, because the `Zxxx`-conditions are only triggered when you start your project from the Live-tool (e.g. all notes will be triggered at once).
- It **is** possible to live edit: just start the live tool, navigate to the pattern you want to edit and start editing. Just be aware that at all times it's pattern 0 that is playing, and your work will only be copy/pasted/processed to pattern 0 the moment the pattern has finished a cycle (e.g. played it's last note and goes back to note 1).
- For a complete list, see [known issues and limitations](##-known-issues-and-limitations)

## Features

This tool adds the following effects to the pattern editor:

- The following effects are applicable to both **columns** and **tracks**:
    - Note t**r**iggers (`ZR` and `ZI`)
        - `ZR01` : Only play the first run of this pattern.
        - `ZR00` : Don't play the first run of this pattern.
        - `ZRn0` : Only play the nth run of this pattern.
        - `ZRyx` : Play every xth pattern after y runs. Some examples:
            - `ZR21` : Play the note on run 1, but not run 2 (`2:1`)
            - `ZR33` : Play the note on run 3, but not on 1 and 2 (`3:3`)
        - `ZIyx` : **I**nverted trigger (Don't play every xth pattern after y runs). Some examples:
            - `ZI41` : Play the note on run 2, 3 and 4, but not on 1 (`4:1`)
            - `ZI33` : Play the note on run 1 and 2, but not 3 (`3:3`)
    - **F**ills (`ZF`)
        - `ZF00` : Only play when not having a fill/transition to another pattern
        - `ZF01` : Only play when having a fill/transition to another pattern
    - **M**uting (`ZM`)
        - `ZM00` : Start track muted
        - `ZMxx` : Unmute after `xx` runs (in dec)
- The following effects are applicable to **only tracks**:
    - Automatically set **n**ext pattern (`ZN`)
        - `ZNxx` : Set pattern `xx` (in dec) to be the next one in the queue.
    - Set pattern **p**lay count (`ZP`)
        - `ZPxx` : Set pattern play count to `xx` (transitions will be triggered in the last count). When a next pattern is queued, the current pattern plays a full `xx` runs. For example: a 16-bar pattern with `ZP04` will always play in sets of 4, but you can already queue it on the first run. Fills will be triggered in the last run.
    - **C**utoff pattern (useful to generate polymeter / polyrhythms) (`ZC`)
        - `ZC00` : Cut off (and repeat) the pattern from this point. This is up to but not included, so a cut on line 4 would repeat lines 1,2 and 3; effectively creating a [polyrhythm](https://en.wikipedia.org/wiki/Polyrhythm). 
            - Triggs (`ZR`) and inverted triggs (`ZI`) are supported when a track uses `ZC`
            - Fills (`ZF`) and muting (`ZM`) are not supported when a track uses `ZC`

## Keyboard shortcuts

- `arrow left` : queue previous pattern
- `arrow right` : queue next pattern
- `f` : trigger fill
- `esc` : close dialog
- `1` to `8` : mute / unmute track 1 to 8
- `q` to `i` _(upper keys on a qwerty keyboard)_ : mute / unmute track 9 to 16

## Ideas

This is a rough lists of ideas that I want to add to this plugin in the future:

- Get text from song and translate to instructions per pattern
- When queueing mute, do play the first note before muting
- Add trig condition that only plays on the first pattern after a fill
    - suggestion: `ZF02`
- Add trig condition that doesn't plays on the first pattern after a fill
    - suggestion: `ZF03`
- Alternative fill
    - suggestion: `ZF04`
- "Break" mute / fill (mute (a group?), do a fill and then unmute again)
- Force unmute
- Stutter / randomize track
- Muting Groups - where you can mute/unmute multiple tracks at once
- Track playback speed (1/2, 1/3, 1/4, 1/8, 1/16, 1/32, 1/64)
    - Also stretch delay column
    - suggestion: `ZSxx`
- One tap on stop should not reset pattern, stop while stop should
- External midi syncing / queueing
- More optimizations (any help is welcome)

## Known issues & limitations

- Things break when loading a new song while the Live dialog is open. Close the dialog before opening a new song.
- Line effects are only measured on effect column 1
- Fills don't work in tracks that are cut with the `ZC` command
- Muting in tracks don't work in tracks that are cut with the `ZC` command
- When live-editing a track with a `ZC` command, funky things will happen due to the virtual counting.
- Transitioning between patterns of different lengths not yet very stable. Using `ZB00` on the end of your pattern helps when the next pattern is longer, but when transitioning from a longer to a shorter pattern it's not really stable yet.
- The Mute buttons of the UI only apply to tracks. So when applying on columns, it makes sense to make use of the timed muters
