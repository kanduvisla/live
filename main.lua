-- Some basic vars for reuse:
local app = renoise.app()
local tool = renoise.tool()
local song = nil
local doc = renoise.Document

-- View Builder for preferences and set scale
local vbp = renoise.ViewBuilder()
local vbc = renoise.ViewBuilder
local vbwp = vbp.views

-- Variables used:
local currLine = 0
local prevLine = -1
local currPattern = doc.ObservableNumber(0)
local nextPattern = doc.ObservableNumber(1)
local patternPlayCount = 0

reset = function()
  currLine = 0
  prevLine = -1
  currPattern.value = 0
  nextPattern.value = 1
  patternPlayCount = 0
end

-- Pattern indicator
local patternIndicatorView = vbp:text {
  text =  "-",
  align = "center",
  font = "big",
  style = "strong",
  width = 100,
  height = 50
}

updatePatternIndicator = function()
  if currPattern.value ~= nextPattern.value then
    patternIndicatorView.text = string.format(
      "%s → %s", 
      currPattern.value,
      nextPattern.value
    )
  else 
    patternIndicatorView.text = string.format("%s", currPattern.value)
  end
end

nextPattern:add_notifier(updatePatternIndicator)

local dialog = vbp:column {
  margin = 1,
  vbp:horizontal_aligner {
    margin = 1,
    mode = "justify", 
    vbp:column {
      margin = 1,
      vbp:text { text = "Welcome to Live - a Renoise Live Performance Tool" },
      vbp:text { text = "Special FX:" },
      vbp:text { text = "LF00 - Only play when transitioning to a new pattern" },
      vbp:text { text = "LF01 - Only play when not transitioning to a new pattern" },
      vbp:text { text = "LNxx - Set next pattern to play to xx" },
      vbp:text { text = "LTxx - Triggers" },
    },
    vbp:button {
      text = "Play",
      width = 50,
      height = 50,
      pressed = function()
        -- Play pattern 0 in loop
        currPattern.value = 1
        nextPattern.value = 1
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
        reset()
        setupPattern()
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
        if nextPattern.value > 1 then
          nextPattern.value = nextPattern.value - 1
          updatePattern()
        end
      end
    },
    patternIndicatorView,
    vbp:button {
      text = "Next",
      width = 50,
      height = 50,
      pressed = function()
        if nextPattern.value < song.transport.song_length.sequence - 1 then
          nextPattern.value = nextPattern.value + 1
          updatePattern()
        end
      end
    }
  }
}

-- Setup pattern, this is called every time a new pattern begins
setupPattern = function()
  if nextPattern.value ~= currPattern.value then
    local dst = song:pattern(1)
    local src = song:pattern(nextPattern.value + 1)
    dst.number_of_lines = src.number_of_lines
    dst:copy_from(src)
    -- Hook into here to add custom trig conditions
    patternPlayCount = 0

    -- O = modulo, for example 001 = every loop, 002, every 2nd loop, 003 = every 3rd, etc.
    currPattern.value = nextPattern.value
    updatePattern()
    updatePatternIndicator()
  else
    patternPlayCount = patternPlayCount + 1
    updatePattern()
  end
end

-- Check for transition fills. These are triggered when a transition is going to happen from one pattern to the other
updatePattern = function()
  local dst = song:pattern(1)
  local src = song:pattern(currPattern + 1)
  dst:copy_from(src)

  -- F = fill
  --     F000 - Play when transitioning to the next pattern
  --     F001 - Play when not transitioning to the next pattern
  for t=1, #song.tracks do
    -- Only for note tracks
    if song.tracks[t].type == 1 then
      for l=1, dst.number_of_lines do
        -- Check for filter
        local line = dst.tracks[t].lines[l]
        local effect = line:effect_column(1)
        -- Fill:
        if effect.number_string == "LF" then
          -- Remove the not playing ones:
          if nextPattern.value ~= currPattern.value and effect.amount_string == "01" then
            line:clear()
          end
          if nextPattern.value == currPattern.value and effect.amount_string == "00" then
            line:clear()
          end
        end
        -- Auto-queue next pattern
        if effect.number_string == "LN" then
          if nextPattern.value == currPattern.value then
            nextPattern.value = effect.amount_value
          end
        end
        -- Trigger
        if effect.number_string == "LT" then
          -- LT00 = !1st
          if effect.amount_string == "00" and patternPlayCount == 0 then
            line:clear()
          end
          -- LT01 == 1st
          if effect.amount_string == "01" and patternPlayCount ~= 0 then
            line:clear()
          end
          -- LTn0 = nth
          local length = tonumber(effect.amount_string:sub(1, 1))
          local modulo = tonumber(effect.amount_string:sub(2, 2))
          if patternPlayCount % length ~= modulo - 1 then
            line:clear()
          end
        end
        -- Inversed Trigger
        if effect.number_string == "LI" then
          -- LTn0 = nth
          local length = tonumber(effect.amount_string:sub(1, 1))
          local modulo = tonumber(effect.amount_string:sub(2, 2))
          if patternPlayCount % length == modulo - 1 then
            line:clear()
          end
        end
        -- Start track muted, and provide functionality for auto-unmute
        if effect.number_string == "LM" then
          if patternPlayCount == 0 then
            song.tracks[t]:mute()
          end
          if effect.amount_string ~= "00" then
            if patternPlayCount == tonumber(effect.amount_string) then
              song.tracks[t]:unmute()
            end
          end
        end
      end
    end
  end
end

-- Add notifier each time the loop ends:
local function stepNotifier()  
  -- Check for pattern change:
  if currLine == song.patterns[1].number_of_lines then
    -- Change patterns:
    setupPattern()
  end
end

-- Idle observer
local function idleObserver()
  currLine = song.transport.playback_pos.line
  if song.transport.playing and currLine ~= prevLine then
    stepNotifier()
    prevLine = currLine
  end
end

-- Main window
showMainWindow = function()
  if song == nil then
    song = renoise.song()
  end
  
  -- Step notifier:
  if renoise.tool().app_idle_observable:has_notifier(idleObserver) == false then
    renoise.tool().app_idle_observable:add_notifier(idleObserver)
  end

  -- Load song comments (pattern remarks are in song comments)
  updatePatternIndicator()
  
  -- Reset properties:
  reset()
  
  -- Show dialog:
  app:show_custom_dialog("Live", dialog)
 
  setupPattern()
end

-- Add menu entry:
tool:add_menu_entry {
  name = "Main Menu:Tools:Live",
  invoke = function()
    showMainWindow()
  end
}
