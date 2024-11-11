local doc = renoise.Document

-- Create Track button
createTrackButton = function(vbp, buttonSize, trackState, trackIndex)
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

-- Update Track Button
updateTrackButton = function(vbp, trackIndex)
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

-- Pattern indicator
createPatternIndicator = function(vbp, buttonSize)
  return vbp:text {
    id = "pattern_indicator",
    text =  "-",
    align = "center",
    font = "big",
    style = "strong",
    width = buttonSize,
    height = buttonSize
  }
end

-- Update Pattern Indicator
updatePatternIndicator = function(vbp, currPattern, nextPattern)
  local patternIndicatorView = vbp.views.pattern_indicator
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
createDialog = function(vbp, buttonSize, trackState)
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
          createTrackButton(vbp, buttonSize, trackState, 1),
          createTrackButton(vbp, buttonSize, trackState, 2),
          createTrackButton(vbp, buttonSize, trackState, 3),
          createTrackButton(vbp, buttonSize, trackState, 4)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row2",
          margin = 0,
          mode = "justify",
          createTrackButton(vbp, buttonSize, trackState, 5),
          createTrackButton(vbp, buttonSize, trackState, 6),
          createTrackButton(vbp, buttonSize, trackState, 7),
          createTrackButton(vbp, buttonSize, trackState, 8)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row3",
          margin = 0,
          mode = "justify",
          createTrackButton(vbp, buttonSize, trackState, 9),
          createTrackButton(vbp, buttonSize, trackState, 10),
          createTrackButton(vbp, buttonSize, trackState, 11),
          createTrackButton(vbp, buttonSize, trackState, 12)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row4",
          margin = 0,
          mode = "justify",
          createTrackButton(vbp, buttonSize, trackState, 13),
          createTrackButton(vbp, buttonSize, trackState, 14),
          createTrackButton(vbp, buttonSize, trackState, 15),
          createTrackButton(vbp, buttonSize, trackState, 16)
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
        createPatternIndicator(),
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
  
