local Dialog = {}
Dialog.__index = Dialog

-- Private properties
local doc = renoise.Document
local app = renoise.app()
local vbp = renoise.ViewBuilder()
local buttonSize = 80
local trackState = {}
local dialog = nil
local dialogContent = nil
local isDebugEnabled = true

-- New instance to create an operate the dialog
function Dialog:new(
  song,
  onTrackButtonPressed,
  onFillButtonPressed,
  onStartStopButtonPressed,
  onPrevButtonPressed,
  onNextButtonPressed,
  onMuteQueuePressed
)
  local instance = setmetatable({}, Dialog)

  instance.song = song
  instance.trackState = trackState
  instance.onTrackButtonPressed = onTrackButtonPressed
  instance.onFillButtonPressed = onFillButtonPressed
  instance.onStartStopButtonPressed = onStartStopButtonPressed
  instance.onPrevButtonPressed = onPrevButtonPressed
  instance.onNextButtonPressed = onNextButtonPressed
  instance.onMuteQueuePressed = onMuteQueuePressed

  return instance
end

-- Create Track button
function Dialog:createTrackButton(trackIndex)
  local button = vbp:button {
    id = "track_button_" .. trackIndex,
    text = "-",
    color = {0, 0, 0},
    width = buttonSize,
    height = buttonSize,
    active = false,
    pressed = function()
      -- rprint(self.onTrackButtonPressed)
      self:onTrackButtonPressed(trackIndex)
    end
  }

  -- Prepare track state:
  self.trackState[trackIndex] = {
    track = nil,
    trackName = "-",
    trackColor = {0, 0, 0},
    muted = doc.ObservableBoolean(false),
    unmuteCounter = doc.ObservableNumber(0),
    trigged = doc.ObservableBoolean(false),
    mutedColumnCount = doc.ObservableNumber(0)
  }

  local function setButtonText()
    local trackName = self.trackState[trackIndex].trackName
    
    if self.trackState[trackIndex].unmuteCounter.value > 0 then
      button.text = string.format(
        "%s\n%s\n(M:%s)", 
        trackIndex, 
        trackName, 
        self.trackState[trackIndex].unmuteCounter.value
      )  
    elseif self.trackState[trackIndex].muted.value == true then
      button.text = string.format("%s\n%s\n(M)", trackIndex, trackName)
    elseif self.trackState[trackIndex].mutedColumnCount.value > 0 then
      button.text = string.format(
        "%s\n%s\n(MC:%s)", 
        trackIndex, 
        trackName,
        self.trackState[trackIndex].mutedColumnCount.value
      )
    else        
      button.text = string.format("%s\n%s", trackIndex, trackName)
    end
  end
  
  -- Observer for the mute button change color behavior
  self.trackState[trackIndex].unmuteCounter:add_notifier(setButtonText)
  self.trackState[trackIndex].muted:add_notifier(setButtonText)
  self.trackState[trackIndex].mutedColumnCount:add_notifier(setButtonText)
    
  -- Observer for the blinking Indicator
  self.trackState[trackIndex].trigged:add_notifier(function()
    self:updateTrackButtonColor(trackIndex)
  end)
  
  return button
end

-- Update the Track Button Color according to it's state
function Dialog:updateTrackButtonColor(trackIndex)
  local button = vbp.views["track_button_" .. trackIndex]
  
  if self.trackState[trackIndex].trigged.value == true then
    if self.trackState[trackIndex].muted.value == true then
      button.color = {255, 0, 0}
    else 
      button.color = {128, 200, 0}
    end
  elseif self.trackState[trackIndex].mutedQueue == true then
    if self.trackState[trackIndex].muted.value == true then
      button.color = {255, 120, 0}
    else 
      button.color = {200, 200, 0}
    end
  elseif self.trackState[trackIndex].muted.value == true then
    button.color = {200, 0, 0}
  else 
    button.color = self.trackState[trackIndex].trackColor
  end
end

-- Update Track Button
function Dialog:updateTrackButton(trackIndex)
  if self.trackState[trackIndex] == nil then
    return
  end

  local track = self.song.tracks[trackIndex]
  local button = vbp.views["track_button_" .. trackIndex]

  if track == nil or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    self.trackState[trackIndex].track = nil
    
    button.text = "-"
    button.color = {0, 0, 0}
    button.active = false
  else
    local trackName = track.name
    local trackColor = track.color
    
    self.trackState[trackIndex].track = trackIndex
    self.trackState[trackIndex].trackName = trackName
    self.trackState[trackIndex].trackColor = trackColor
    self.trackState[trackIndex].muted.value = track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE
    self.trackState[trackIndex].unmuteCounter.value = 0
    self.trackState[trackIndex].trigged.value = false
    self.trackState[trackIndex].mutedColumnCount.value = 0
    self.trackState[trackIndex].mutedQueue = false
  
    button.color = trackColor
    button.active = true
    button.text = string.format("%s\n%s", trackIndex, trackName)

    self:updateTrackButtonColor(trackIndex)
  end
end

-- Create the play/stop button
function Dialog:createPlayButton()
  local button = vbp:button {
    id = "transport_button",
    text = "Play",
    width = buttonSize,
    height = buttonSize,
    color = {0, 128, 0},
    pressed = function()
      self:onStartStopButtonPressed()
    end
  }

  return button
end

-- Update the playbutton
function Dialog:updatePlayButton(playing)
  local button = vbp.views.transport_button
  
  if button ~= nil then
    if playing == true then
      vbp.views.transport_button.text = "Stop"
      button.color = {128, 0, 0}
    else
      vbp.views.transport_button.text = "Play"
      button.color = {0, 128, 0}
    end
  end
end

-- Pattern indicator
function Dialog:createPatternIndicator()
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
function Dialog:updatePatternIndicator(
  currPattern, 
  nextPattern, 
  patternPlayCount, 
  patternSetCount, 
  userInitiatedFill,
  currentStep,
  totalSteps
)
  local patternIndicatorView = vbp.views.pattern_indicator
  if patternIndicatorView == nil then
    return
  end

  if currPattern.value ~= nextPattern.value then
    patternIndicatorView.text = string.format(
      "%s → %s (%s/%s)\n\n%s/%s", 
      currPattern.value,
      nextPattern.value,
      (patternPlayCount % patternSetCount) + 1,
      patternSetCount,
      currentStep,
      totalSteps
    )
  else 
    patternIndicatorView.text = string.format(
      "%s (%s/%s)%s\n\n%s/%s", 
      currPattern.value,
      (patternPlayCount % patternSetCount) + 1,
      patternSetCount,
      userInitiatedFill and " (F)" or "",
      currentStep,
      totalSteps
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
--     (debug)
function Dialog:createDialog()
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
          self:createTrackButton(1),
          self:createTrackButton(2),
          self:createTrackButton(3),
          self:createTrackButton(4)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row2",
          margin = 0,
          mode = "justify",
          self:createTrackButton(5),
          self:createTrackButton(6),
          self:createTrackButton(7),
          self:createTrackButton(8)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row3",
          margin = 0,
          mode = "justify",
          self:createTrackButton(9),
          self:createTrackButton(10),
          self:createTrackButton(11),
          self:createTrackButton(12)
        },
        vbp:horizontal_aligner {
          id = "track_buttons_row4",
          margin = 0,
          mode = "justify",
          self:createTrackButton(13),
          self:createTrackButton(14),
          self:createTrackButton(15),
          self:createTrackButton(16)
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
          pressed = self.onFillButtonPressed,
          color = {1, 1, 1}
        },
        vbp:button {
          id = "mute_queue_button",
          text = "Mute Queue",
          width = buttonSize,
          height = buttonSize,
          pressed = self.onMuteQueuePressed,
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
        self:createPlayButton(),
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
          pressed = self.onPrevButtonPressed
        },
        self:createPatternIndicator(),
        vbp:button {
          text = "Next",
          width = buttonSize,
          height = buttonSize,
          color = {1, 1, 1},
          pressed = self.onNextButtonPressed
        }
      }
    }
  }
  
  if isDebugEnabled then
    dialog:add_child(
      vbp:text {
        id = "debug_info",
        text = "(debug information)"
      }
    )
  end
  
  return dialog
end

-- Set the proper muted status for the UI
function Dialog:setMutedStatus(trackIndex, status, isQueued)
  local isQueued = isQueued or false
  if isQueued == false then
    trackState[trackIndex].muted.value = status
    if status == false then
      trackState[trackIndex].unmuteCounter.value = 0
      trackState[trackIndex].mutedColumnCount.value = 0
    end
    trackState[trackIndex].mutedQueue = false
  else
    trackState[trackIndex].mutedQueue = status
  end
  self:updateTrackButtonColor(trackIndex)
end

-- Set proper fill button color
function Dialog:setFillButtonState(active)
  local button = vbp.views.fill_button

  if button ~= nil then
    if active == true then
      button.color = {255, 255, 255}
    else
      button.color = {1, 1, 1}
    end  
  end
end

-- Set proper fill button color
function Dialog:setMuteQueueButtonState(active)
  local button = vbp.views.mute_queue_button

  if button ~= nil then
    if active == true then
      button.color = {255, 255, 255}
    else
      button.color = {1, 1, 1}
    end  
  end
end

-- Update unmute counter
function Dialog:setUnmuteCounter(trackIndex, value)
  trackState[trackIndex].unmuteCounter.value = value
  -- self:updateTrackButton(trackIndex)
end

-- Update the muted column count
function Dialog:updateMutedColumnCount(trackIndex, delta)
  trackState[trackIndex].mutedColumnCount.value = trackState[trackIndex].mutedColumnCount.value + 1
end

-- Reset the dialog
function Dialog:reset(song)
  self.song = song
  self:updatePlayButton(false)
  for trackIndex = 1, 16 do
    self:updateTrackButton(trackIndex)
  end
  self:resetTriggerLights()
end

-- Handler for key presses on the dialog
function Dialog:keyHandler(key)
  if key.name == "left" then
    self:onPrevButtonPressed()
  elseif key.name == "right" then
    self:onNextButtonPressed()
  elseif key.name == "esc" then
    dialog:close()
  elseif key.name == "1" then
    self:onTrackButtonPressed(1)
  elseif key.name == "2" then
    self:onTrackButtonPressed(2)
  elseif key.name == "3" then
    self:onTrackButtonPressed(3)
  elseif key.name == "4" then
    self:onTrackButtonPressed(4)
  elseif key.name == "5" then
    self:onTrackButtonPressed(5)
  elseif key.name == "6" then
    self:onTrackButtonPressed(6)
  elseif key.name == "7" then
    self:onTrackButtonPressed(7)
  elseif key.name == "8" then
    self:onTrackButtonPressed(8)
  elseif key.name == "q" then
    self:onTrackButtonPressed(9)
  elseif key.name == "w" then
    self:onTrackButtonPressed(10)
  elseif key.name == "e" then
    self:onTrackButtonPressed(11)
  elseif key.name == "r" then
    self:onTrackButtonPressed(12)
  elseif key.name == "t" then
    self:onTrackButtonPressed(13)
  elseif key.name == "y" then
    self:onTrackButtonPressed(14)
  elseif key.name == "u" then
    self:onTrackButtonPressed(15)
  elseif key.name == "i" then
    self:onTrackButtonPressed(16)
  elseif key.name == "f" then
    self:onFillButtonPressed()
  end
end

-- Set the trigger light of a specific track index
function Dialog:setTriggerLight(trackIndex, isEnabled)
  trackState[trackIndex].trigged.value = isEnabled
end

-- Reset the trigger lights
function Dialog:resetTriggerLights()
  for key in pairs(trackState) do
    local trackData = trackState[key]
    if trackData.track ~= nil then
      trackState[key].trigged.value = false
    end
  end
end

-- Show the dialog
function Dialog:show()
  if not dialog or not dialog.visible then
    -- create, or re-create if hidden
    if not dialogContent then
      dialogContent = self:createDialog() -- run only once
    end

    -- Update the buttons
    for trackIndex = 1, 16 do
      self:updateTrackButton(trackIndex)
    end
    
    self:updatePlayButton(false)
    self:setFillButtonState(false)

    dialog = app:show_custom_dialog("Live", dialogContent, function(d, key)
      self:keyHandler(key)
    end)
  else
    -- bring existing/visible dialog to front
    dialog:show()
  end
end

-- Check if the dialog is visible
function Dialog:isVisible()
  if not dialog or not dialog.visible then
    return false
  else 
    return dialog.visible
  end
end

return Dialog
