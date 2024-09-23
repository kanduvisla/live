-- Some basic vars for reuse:
local app = renoise.app()
local tool = renoise.tool()
local song = renoise.song()
local doc = renoise.Document

-- View Builder for preferences and set scale
local vbp = renoise.ViewBuilder()
local vbc = renoise.ViewBuilder
local vbwp = vbp.views

-- Variables used:
local currLine = 0
local prevLine = -1
local currPattern = 1
local nextPattern = 1

-- Main window
showMainWindow = function()
  -- Load song comments (pattern remarks are in song comments)

  app:show_custom_dialog(
    "Live",
    vbp:column {
      margin = 1,
      vbp:horizontal_aligner {
        margin = 1,
        mode = "justify", 
        vbp:column {
          margin = 1,
          vbp:text { text = "Welcome to Live - a Renoise Live Performance Tool" },
          vbp:text { text = "Usage: ..." }
        },
        vbp:button {
          text = "Play",
          width = 50,
          height = 50,
          pressed = function()
            -- Play pattern 0 in loop
            song.transport.loop_pattern = true
            local song_pos = renoise.SongPos(1, 1)
            song.transport:start_at(song_pos)
          end
        },
        vbp:button {
          text = "Stop",
          width = 50,
          height = 50,
          pressed = function()
            song.transport:stop()
          end
        }
        -- Add pattern remarks
        
      },
      vbp:horizontal_aligner {
        margin = 1,
        mode = "justify",
        vbp:button {
          text = "Prev",
          width = 50,
          height = 50,
          pressed = function()
            if currPattern > 1 then
              currPattern = currPattern - 1
              song.transport:set_scheduled_sequence(currPattern)
            end
          end
        },
        vbp:button {
          text = "Next",
          width = 50,
          height = 50,
          pressed = function()
             currPattern = currPattern + 1
             song.transport:set_scheduled_sequence(currPattern)
          end
        }
      }
    }
  )
  
  setupPattern()
end

-- Setup pattern, this is called every time a new pattern begins
setupPattern = function()
  print("Setting up pattern")
end

-- Add notifier each time the loop ends:
local function stepNotifier()  
  -- Check for pattern change:
  if currLine == song.patterns[1].number_of_lines then
    -- Change patterns:
    setupPattern()
  end
end

-- Step notifier:
renoise.tool().app_idle_observable:add_notifier(function()
  currLine = song.transport.playback_pos.line
  if song.transport.playing and currLine ~= prevLine then
    stepNotifier()
    prevLine = currLine
  end
end)

-- Add menu entry:
tool:add_menu_entry {
  name = "Main Menu:Tools:Live",
  invoke = function()
    showMainWindow()
  end
}
