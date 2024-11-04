require("includes/track_play_count")
require("includes/note_triggers")
require("includes/cutoff_points")
require("includes/fill")

-- Some basic vars for reuse:
local app = renoise.app()
local tool = renoise.tool()
local song = nil
local doc = renoise.Document
local benchmark = true   -- Output benchmarking information to the console, for dev purposes

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
local patternSetCount = 1   -- How many patterns in a "set"
local trackLengths = {}     -- Remember the individual lengths of tracks
local userInitiatedFill = false
local buttonSize = 96

reset = function()
  currLine = 0
  prevLine = -1
  currPattern.value = 0
  nextPattern.value = 1
  patternPlayCount = 0
  patternSetCount = 1
  trackLengths = {}
  userInitiatedFill = false
end

-- Pattern indicator
local patternIndicatorView = vbp:text {
  text =  "-",
  align = "center",
  font = "big",
  style = "strong",
  width = buttonSize,
  height = buttonSize
}

updatePatternIndicator = function()
  if currPattern.value ~= nextPattern.value then
    patternIndicatorView.text = string.format(
      "%s → %s (%s/%s)", 
      currPattern.value,
      nextPattern.value,
      (patternPlayCount % patternSetCount) + 1,
      patternSetCount
    )
  else 
    patternIndicatorView.text = string.format(
      "%s (%s/%s)%s", 
      currPattern.value,
      (patternPlayCount % patternSetCount) + 1,
      patternSetCount,
      userInitiatedFill and " (F)" or ""
    )
  end
end

nextPattern:add_notifier(updatePatternIndicator)

-- Queue the next pattern
local queue_next_pattern = function()
  if nextPattern.value < song.transport.song_length.sequence - 1 then
    nextPattern.value = nextPattern.value + 1
    updatePattern()
  end
end

-- Queue the previous pattern
local queue_previous_pattern = function()
  if nextPattern.value > 1 then
    nextPattern.value = nextPattern.value - 1
    updatePattern()
  end
end

-- Trigger a fill
local trigger_fill = function()
  userInitiatedFill = true
  vbp.views.fill_button.color = {255, 255, 255}
  updatePatternIndicator()
  updatePattern()   
end

-- Keep state of the tracks (mute status, etc.)
local trackState = {}

setTrackButtonColor = function(trackIndex)
  local button = vbp.views["track_button_" .. trackIndex]
  
  if trackState[trackIndex].trigged.value == true then
    if trackState[trackIndex].muted.value == true then
      button.color = {255, 0, 0}
    else 
      button.color = {128, 200, 0}
    end
  elseif trackState[trackIndex].muted.value == true then
    button.color = {200, 0, 0}
  else 
    button.color = trackState[trackIndex].trackColor
  end
end

toggleMute = function(trackIndex)
  local track = song.tracks[trackIndex]
  if track == nil or track.type ~= 1 then
    return
  end
  
  if track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
    track:mute()
    trackState[trackIndex].muted.value = true
  else
    track:unmute()
    trackState[trackIndex].unmuteCounter.value = 0
    trackState[trackIndex].muted.value = false
    trackState[trackIndex].mutedColumnCount.value = 0
    -- Unmute all columns?
  end
  setTrackButtonColor(trackIndex)
end

createTrackButton = function(trackIndex)
  local button = vbp:button {
    id = "track_button_" .. trackIndex,
    text = "-",
    color = {0, 0, 0},
    width = buttonSize,
    height = buttonSize,
    active = false,
    pressed = function() 
      toggleMute(trackIndex)
    end
  }

  trackState[trackIndex] = {
    track = nil,
    trackName = "-",
    trackColor = {0, 0, 0},
    muted = doc.ObservableBoolean(false),
    unmuteCounter = doc.ObservableNumber(0),
    trigged = doc.ObservableBoolean(false),
    mutedColumnCount = doc.ObservableNumber(0)
  }

  local function setButtonText()
    local trackName = trackState[trackIndex].trackName
    
    if trackState[trackIndex].unmuteCounter.value > 0 then
      button.text = string.format(
        "%s\n%s\n(M:%s)", 
        trackIndex, 
        trackName, 
        trackState[trackIndex].unmuteCounter.value
      )  
    elseif trackState[trackIndex].muted.value == true then
      button.text = string.format("%s\n%s\n(M)", trackIndex, trackName)
    elseif trackState[trackIndex].mutedColumnCount.value > 0 then
      button.text = string.format(
        "%s\n%s\n(MC:%s)", 
        trackIndex, 
        trackName,
        trackState[trackIndex].mutedColumnCount.value
      )
    else        
      button.text = string.format("%s\n%s", trackIndex, trackName)
    end
  end
  
  -- Observer for the mute button change color behavior
  trackState[trackIndex].unmuteCounter:add_notifier(setButtonText)
  trackState[trackIndex].muted:add_notifier(setButtonText)
  trackState[trackIndex].mutedColumnCount:add_notifier(setButtonText)
    
  -- Observer for the blinking Indicator
  trackState[trackIndex].trigged:add_notifier(function()
    setTrackButtonColor(trackIndex)  
  end)
  
  return button
end

local updateTrackButton = function(trackIndex)
  local track = song.tracks[trackIndex]
  local button = vbp.views["track_button_" .. trackIndex]
  
  if track == nil or track.type ~= 1 then
    trackState[trackIndex].track = nil
    
    button.text = "-"
    button.color = {0, 0, 0}
    button.active = false
  else
    local trackName = track.name
    local trackColor = track.color
    
    trackState[trackIndex].track = trackIndex
    trackState[trackIndex].trackName = trackName
    trackState[trackIndex].trackColor = trackColor
    trackState[trackIndex].muted.value = track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE
    trackState[trackIndex].unmuteCounter.value = 0
    trackState[trackIndex].trigged.value = false
    trackState[trackIndex].mutedColumnCount.value = 0
  
    button.color = trackColor
    button.active = true
    button.text = string.format("%s\n%s", trackIndex, trackName)
  end
end

local playButton = vbp:button {
  id = "transport_button",
  text = "Play",
  width = buttonSize,
  height = buttonSize,
  color = {0, 128, 0},
  pressed = function()
    if song.transport.playing then
      song.transport:stop()
      reset()
      setupPattern()
      vbp.views.transport_button.text = "Play"
      vbp.views.transport_button.color = {0, 128, 0}
    else
      -- Play pattern 0 in loop
      currPattern.value = 1
      nextPattern.value = 1
      song.transport.loop_pattern = true
      local song_pos = renoise.SongPos(1, 1)
      song.transport:start_at(song_pos)
      vbp.views.transport_button.text = "Stop"
      vbp.views.transport_button.color = {128, 0, 0}
    end
  end
}

-- Dialog structure:
--
-- .---------. .---.
-- |    1    | | 2 | 
-- |         | |   | 
-- | .-----. | |   | 
-- | |  3  | | |   | 
-- | `-----` | |   | 
-- |   etc   | |   | 
-- `---------` `---`
-- .---------------.
-- |       4       |
-- `---------------`
--
createDialog = function()
  local dialog = vbp:column {
    id = "container",
    margin = 0,
    vbp:row {
      id = "top_wrapper",
      margin = 0,
      vbp:column {
        id = "track_buttons_container",
        margin = 0,
        vbp:horizontal_aligner {
          id = "track_buttons_row1",
          margin = 0,
          mode = "justify",
          createTrackButton(1),
          createTrackButton(2),
          createTrackButton(3),
          createTrackButton(4)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row2",
          margin = 0,
          mode = "justify",
          createTrackButton(5),
          createTrackButton(6),
          createTrackButton(7),
          createTrackButton(8)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row3",
          margin = 0,
          mode = "justify",
          createTrackButton(9),
          createTrackButton(10),
          createTrackButton(11),
          createTrackButton(12)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row4",
          margin = 0,
          mode = "justify",
          createTrackButton(13),
          createTrackButton(14),
          createTrackButton(15),
          createTrackButton(16)
        },
      },
      vbp:column {
        id = "fill_container",
        margin = 0,
        style = "plain",
        vbp:button {
          id = "fill_button",
          text = "Fill",
          width = buttonSize,
          height = buttonSize,
          pressed = trigger_fill,
          color = {1, 1, 1}
        },
        vbp:button {
          width = buttonSize,
          height = buttonSize,
          text = "-",
          active = false,
          color = {1, 1, 1}
        },
        vbp:button {
          width = buttonSize,
          height = buttonSize,
          text = "-",
          active = false,
          color = {1, 1, 1}
        },
        vbp:button {
          width = buttonSize,
          height = buttonSize,
          text = "-",
          active = false,
          color = {1, 1, 1}
        },
      }
    },
    vbp:row {
      id = "transport_container",
      margin = 0,
      style = "plain",
      vbp:horizontal_aligner {
        margin = 0,
        mode = "justify",
        playButton,
        vbp:button {
          width = buttonSize,
          height = buttonSize,
          text = "-",
          active = false,
          color = {1, 1, 1}
        },
        vbp:button {
          text = "Prev",
          width = buttonSize,
          height = buttonSize,
          color = {1, 1, 1},
          pressed = queue_previous_pattern
        },
        patternIndicatorView,
        vbp:button {
          text = "Next",
          width = buttonSize,
          height = buttonSize,
          color = {1, 1, 1},
          pressed = queue_next_pattern
        }
      }
    }
  }
  
  return dialog
end

-- Setup pattern, this is called every time a new pattern begins
setupPattern = function()
  local dst = song:pattern(1)
  if nextPattern.value ~= currPattern.value and (patternPlayCount + 1) % patternSetCount == 0 then
    -- Prepare a new pattern
    local src = song:pattern(nextPattern.value + 1)
    dst.number_of_lines = src.number_of_lines
    dst:copy_from(src)

    -- Reset some stuff:
    patternPlayCount = 0
    patternSetCount = 1
    userInitiatedFill = false
    vbp.views.fill_button.color = {1, 1, 1}
    
    for t=1, #dst.tracks do
      -- Only for note tracks
      if song.tracks[t].type == 1 then
        trackLengths[t] = getPatternTrackLength(dst:track(t))
      end
    end
    
    currPattern.value = nextPattern.value

    updatePattern()
    updatePatternIndicator()
  else
    -- Update play count
    patternPlayCount = patternPlayCount + 1
    
    -- If we're back at the start, the user initiated fill needs to be reset:
    if patternPlayCount % patternSetCount == 0 then
      userInitiatedFill = false
      vbp.views.fill_button.color = {1, 1, 1}
    end
    
    -- Update pattern
    updatePattern()
    if patternSetCount > 1 then
      updatePatternIndicator()
    end
  end
end

-- Get the length of an individual track (based on it's cutoff point)
getPatternTrackLength = function(patternTrack)
  local dst = song:pattern(1)
  local number_of_lines = dst.number_of_lines
  for l=1, number_of_lines do
    local line = patternTrack:line(l)
    local effect = line:effect_column(1)
    if effect.number_string == "ZC" then
      -- Cut!
      return l - 1
    end
  end
  return number_of_lines
end

-- Check for transition fills. These are triggered when a transition is going to happen from one pattern to the other
updatePattern = function()
  -- Benchmark
  local time
  if benchmark == true then
    time = os.clock()
  end

  -- TODO: refactor this whole function in multiple - testable functions
  local dst = song:pattern(1)
  local src = song:pattern(currPattern + 1)
  dst:copy_from(src)

  local trackPlayCount = get_track_play_count(patternPlayCount, dst.number_of_lines, trackLengths)

  for t=1, #dst.tracks do
    -- Only for note tracks
    local track = song:track(t)
    if track.type == 1 then
      -- Do a separate iteration for the "ZC" effect.
      if not process_cutoff_points(t, dst, src, song, trackLengths, patternPlayCount) then
        -- Usual filtering:
        for l=1, dst.number_of_lines do
          -- Check for filter
          local line = dst:track(t):line(l)
  
          -- Check for track effect (these apply to the whole line):
          local effect = line:effect_column(1)
  
          -- Fill:
          if effect.number_string == "ZF" then
            if not is_fill(currPattern.value, nextPattern.value, patternPlayCount, patternSetCount, effect.amount_string, userInitiatedFill) then
              line:clear()
            end
            
          -- Auto-queue next pattern:
          elseif effect.number_string == "ZN" then
            if nextPattern.value == currPattern.value then
              nextPattern.value = tonumber(effect.amount_value)
            end
          
          -- Trigger:
          elseif effect.number_string == "ZR" then
            if not is_trig_active(effect.amount_string, patternPlayCount) then
              line:clear()
            end
          -- Inversed Trigger:
          elseif effect.number_string == "ZI" then
            if is_trig_active(effect.amount_string, patternPlayCount) then
              line:clear()
            end        
          -- Start track muted, and provide functionality for auto-unmute:
          elseif effect.number_string == "ZM" then
            if patternPlayCount == 0 then
              track:mute()
              trackState[t].muted.value = true
            end
            if effect.amount_string ~= "00" then
              local amount = tonumber(effect.amount_string)
              if patternPlayCount == amount then
                track:unmute()
                trackState[t].muted.value = false
                trackState[t].unmuteCounter.value = 0
              elseif track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
                -- Update unmute counter
                trackState[t].unmuteCounter.value = amount - (patternPlayCount % amount)
              end
            end
          elseif effect.number_string == "ZP" then
            patternSetCount = tonumber(effect.amount_string)
          end
  
          -- Check for column effects (they apply to a single column):
          local columns = line.note_columns
          for c=1, #columns do
            local column = line:note_column(c)
            local effect_number = column.effect_number_string
            local effect_amount = column.effect_amount_string
            -- Fill:
            if effect_number == "ZF" then
              if not is_fill(currPattern.value, nextPattern.value, patternPlayCount, patternSetCount, effect_amount, userInitiatedFill) then
                column:clear()
              end
            
            -- Trigger:
            elseif effect_number == "ZR" then
              if not is_trig_active(effect_amount, patternPlayCount) then
                column:clear()
              end
            -- Inversed Trigger:
            elseif effect_number == "ZI" then
              if is_trig_active(effect_amount, patternPlayCount) then
                column:clear()
              end          
            -- Start column muted, and provide functionality for auto-unmute:
            elseif effect_number == "ZM" then
              if patternPlayCount == 0 then
                track:set_column_is_muted(c, true)
                trackState[t].mutedColumnCount.value = trackState[t].mutedColumnCount.value + 1
              end
              if effect_amount ~= "00" then
                if patternPlayCount == tonumber(effect_amount) then
                  track:set_column_is_muted(c, false)
                  trackState[t].mutedColumnCount.value = trackState[t].mutedColumnCount.value - 1
                end
              end
            end -- end if
            
          end -- end for#columns        
        end -- end for#lines
      end -- end normal filtering
    end -- end if
  end -- end for#tracks

  -- Benchmark:
  if benchmark == true then
    -- For reference:
    -- At 140 BPM, 1 step (1/16th note) is approximately 107.14 milliseconds.
    -- So if this script performs well under that it's ok
    print(string.format("updatePattern() - function elapsed time: %.4f\n", os.clock() - time))
  end
end

local resetTriggerLights = false

local function hasNote(line)
  for _, note_column in ipairs(line.note_columns) do
    if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE then
      return true
    end
  end
  
  return false
end

-- Add notifier each time the loop ends:
local function stepNotifier()
  -- Benchmark
  local time
  if benchmark == true then
    time = os.clock()
  end

  -- Check for pattern change:
  if currLine == song.patterns[1].number_of_lines - 1 then
    if currPattern.value ~= nextPattern.value then
      -- Add a "ZB00" the the last line of the master track, so the next pattern will start at 0
    end
  elseif currLine == song.patterns[1].number_of_lines then
    -- Change patterns:
    setupPattern()
  end
  
  -- Show trig indicator:
  -- TODO: Performance check on RPI:
  for key in pairs(trackState) do
    local trackData = trackState[key]
    if trackData.track ~= nil then
      local line = song:pattern(1):track(trackData.track):line(currLine)
      trackState[key].trigged.value = hasNote(line)
    end
  end
  resetTriggerLights = true

  if benchmark == true then
    -- For reference:
    -- At 140 BPM, 1 step (1/16th note) is approximately 107.14 milliseconds.
    -- So if this script performs well under that it's ok
    print(string.format("stepNotifier() - total elapsed time: %.4f\n", os.clock() - time))
  end
end

-- Idle observer
local function idleObserver()
  if song ~= nil then
    currLine = song.transport.playback_pos.line
    if song.transport.playing and currLine ~= prevLine then
      stepNotifier()
      prevLine = currLine
    elseif resetTriggerLights == true then
      for key in pairs(trackState) do
        local trackData = trackState[key]
        if trackData.track ~= nil then
          local line = song:pattern(1):track(trackData.track):line(currLine)
          trackState[key].trigged.value = false
        end
      end
      resetTriggerLights = false
    end
  end
end

-- Function to handle key presses
local function key_handler(dialog, key)
  if key.name == "left" then
   queue_previous_pattern()
  elseif key.name == "right" then
    queue_next_pattern()
  elseif key.name == "f" then
    trigger_fill()
  elseif key.name == "esc" then
    dialog:close()
  elseif key.name == "1" then
    toggleMute(1)
  elseif key.name == "2" then
    toggleMute(2)
  elseif key.name == "3" then
    toggleMute(3)
  elseif key.name == "4" then
    toggleMute(4)
  elseif key.name == "5" then
    toggleMute(5)
  elseif key.name == "6" then
    toggleMute(6)
  elseif key.name == "7" then
    toggleMute(7)
  elseif key.name == "8" then
    toggleMute(8)
  elseif key.name == "q" then
    toggleMute(9)
  elseif key.name == "w" then
    toggleMute(10)
  elseif key.name == "e" then
    toggleMute(11)
  elseif key.name == "r" then
    toggleMute(12)
  elseif key.name == "t" then
    toggleMute(13)
  elseif key.name == "y" then
    toggleMute(14)
  elseif key.name == "u" then
    toggleMute(15)
  elseif key.name == "i" then
    toggleMute(16)
  end
end

local dialog = nil
local dialog_content = nil

function showDialog()
  if not dialog or not dialog.visible then
    -- create, or re-create if hidden
    if not dialog_content then
      dialog_content = createDialog() -- run only once
    end
    for trackIndex = 1, 16 do
      updateTrackButton(trackIndex)
    end
    dialog = app:show_custom_dialog("Live", dialog_content, key_handler)
  else
    -- bring existing/visible dialog to front
    dialog:show()
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
  showDialog()
  
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

