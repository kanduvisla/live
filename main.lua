require("../includes/track_play_count.lua")

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
local trackLengths = {}   -- Remember the individual lengths of tracks

reset = function()
  currLine = 0
  prevLine = -1
  currPattern.value = 0
  nextPattern.value = 1
  patternPlayCount = 0
  trackLengths = {}
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
      vbp:text { text = "LF00 / LF01 - Play only on FILL / !FILL" },
      vbp:text { text = "LMxx - Start muted, unmute after xx plays" },
      vbp:text { text = "LNxx - Set next pattern to play to xx" },
      vbp:text { text = "LTxy - Trig (00=1st, 01=!1st, x mod y)" },
      vbp:text { text = "LIxy - Inverse Trig (x mod y)" },
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
  local dst = song:pattern(1)
  if nextPattern.value ~= currPattern.value then
    -- Prepare a new pattern
    local src = song:pattern(nextPattern.value + 1)
    dst.number_of_lines = src.number_of_lines
    dst:copy_from(src)

    -- Reset the count:
    patternPlayCount = 0
    for t=1, #dst.tracks do
      -- Only for note tracks
      if song.tracks[t].type == 1 then
        trackLengths[t] = get_track_length(song.tracks[t])
      end
    end

    currPattern.value = nextPattern.value

    updatePattern()
    updatePatternIndicator()
  else
    patternPlayCount = patternPlayCount + 1
    -- Update track play count
    updatePattern()
  end
end

-- Get the length of an individual track (based on it's cutoff point)
get_track_length = function(track)
  local dst = song:pattern(1)
  local number_of_lines = dst.number_of_lines
  for l=1, number_of_lines do
    local line = track.lines[l]
    local effect = line:effect_column(1)
    if effect.number_string == "LC" then
      -- Cut!
      return l
    end
  end
  return number_of_lines
end

-- Check for transition fills. These are triggered when a transition is going to happen from one pattern to the other
updatePattern = function()
  -- TODO: refactor this whole function in multiple - testable functions
  local dst = song:pattern(1)
  local src = song:pattern(currPattern + 1)
  dst:copy_from(src)

  local trackPlayCount = get_track_play_count(patternPlayCount, dst.number_of_lines, trackLengths)

  for t=1, #dst.tracks do
    -- Only for note tracks
    if song.tracks[t].type == 1 then
      for l=1, dst.number_of_lines do
        -- Check for filter
        local line = dst.tracks[t].lines[l]

        -- Check for track effect (these apply to the whole line):
        local effect = line:effect_column(1)

        -- Cutoff point:
        if effect.number_string == "LC" then
          -- A cutoff point indicates a place in the track where a selection needs to be copy/pasted.
          -- This means we "fill" the pattern with everything that is above the LC, and keep track of how many
          -- times it has already copied to keep the remainder in mind:
          for fl=1, l do
            -- How many times does this pattern "fit" in this track:
            local duplicationCount = math.ceil(dst.number_of_lines / trackLengths[t])
            -- Offset from the previous iteration:
            local offset = 0
            if patternPlayCount > 0 then
              offset = (patternPlayCount * dst.number_of_lines) % trackLengths[t]
            end
            for d=1, duplicationCount do
              local dstLine = fl + (trackLengths[t] * (duplicationCount - 1)) - offset
              if dstLine < dst.number_of_lines and dstLine > 0 then
                dst.tracks[t]:line(dstLine):copy_from(src.tracks[t]:line(fl))
              end
            end
          end

        -- Fill:
        elseif effect.number_string == "LF" then
          -- Remove the not playing ones:
          if nextPattern.value ~= currPattern.value and effect.amount_string == "01" then
            line:clear()
          end
          if nextPattern.value == currPattern.value and effect.amount_string == "00" then
            line:clear()
          end
        
        
        -- Auto-queue next pattern:
        elseif effect.number_string == "LN" then
          if nextPattern.value == currPattern.value then
            nextPattern.value = effect.amount_value
          end
        
        -- Trigger:
        elseif effect.number_string == "LT" then
          -- TODO: This should be with trackPlayCount:
          if effect.amount_string == "00" and patternPlayCount == 0 then
            line:clear()
          end

          -- TODO: This should be with trackPlayCount:
          if effect.amount_string == "01" and patternPlayCount ~= 0 then
            line:clear()
          end

          -- TODO: This should be with trackPlayCount:
          local length = tonumber(effect.amount_string:sub(1, 1))
          local modulo = tonumber(effect.amount_string:sub(2, 2))
          if patternPlayCount % length ~= modulo - 1 then
            line:clear()
          end
        
        -- Inversed Trigger:
        elseif effect.number_string == "LI" then
          -- TODO: This should be with trackPlayCount:
          local length = tonumber(effect.amount_string:sub(1, 1))
          local modulo = tonumber(effect.amount_string:sub(2, 2))
          if patternPlayCount % length == modulo - 1 then
            line:clear()
          end
        
        -- Start track muted, and provide functionality for auto-unmute:
        elseif effect.number_string == "LM" then
          -- TODO: This should be with trackPlayCount:
          if patternPlayCount == 0 then
            song.tracks[t]:mute()
          end
          if effect.amount_string ~= "00" then
            if patternPlayCount == tonumber(effect.amount_string) then
              song.tracks[t]:unmute()
            end
          end
        end

        -- Check for column effects (the apply to a single column):
        local columns = line.note_columns
        for c=1, #columns do
          local column = line:note_column(c)
          local effect_number = column.effect_number_string
          local effect_amount = column.effect_amount_string
          -- Fill:
          if effect_number == "LF" then
            -- Remove the not playing ones:
            if nextPattern.value ~= currPattern.value and effect_amount == "01" then
              column:clear()
            end
            if nextPattern.value == currPattern.value and effect_amount == "00" then
              column:clear()
            end
          
          -- Trigger:
          elseif effect_number == "LT" then
            -- TODO: This should be with trackPlayCount:
            if effect_amount == "00" and patternPlayCount == 0 then
              column:clear()
            end

            -- TODO: This should be with trackPlayCount:
            if effect_amount == "01" and patternPlayCount ~= 0 then
              column:clear()
            end

            -- TODO: This should be with trackPlayCount:
            local length = tonumber(effect_amount:sub(1, 1))
            local modulo = tonumber(effect_amount:sub(2, 2))
            if patternPlayCount % length ~= modulo - 1 then
              column:clear()
            end
          
          -- Inversed Trigger:
          elseif effect_number == "LI" then
            -- TODO: This should be with trackPlayCount:
            local length = tonumber(effect_amount:sub(1, 1))
            local modulo = tonumber(effect_amount:sub(2, 2))
            if patternPlayCount % length == modulo - 1 then
              column:clear()
            end
          
          -- Start column muted, and provide functionality for auto-unmute:
          elseif effect_number == "LM" then
            -- TODO: This should be with trackPlayCount:
            if patternPlayCount == 0 then
              song.tracks[t]:set_column_is_muted(c, true)
            end
            if effect_amount ~= "00" then
              if patternPlayCount == tonumber(effect_amount) then
                song.tracks[t]:set_column_is_muted(c, false)
              end
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
  if song ~= nil then
    currLine = song.transport.playback_pos.line
    if song.transport.playing and currLine ~= prevLine then
      stepNotifier()
      prevLine = currLine
    end
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

-- Reset when a new project is loaded:
renoise.tool().app_release_document_observable:add_notifier(function()
  song = nil
end)

-- Add menu entry:
tool:add_menu_entry {
  name = "Main Menu:Tools:Live",
  invoke = function()
    showMainWindow()
  end
}
