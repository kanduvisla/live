local Dialog = require("ui/dialog")
local TrackData = require("includes/track_data")

local Live = {}
Live.__index = Live

-- Private properties
local benchmark = false
local doc = renoise.Document
local currLine = 0
local prevLine = -1
local patternPlayCount = 0
local patternSetCount = 1
local currPattern = doc.ObservableNumber(1)
local nextPattern = doc.ObservableNumber(1)
local userInitiatedFill = false
local resetTriggerLights = false
local stepCount = 0
local masterTrackLength = 0
local srcPattern
local trackData = {}

-- Initialize
function Live:new(song)
  local instance = setmetatable({}, Live)

  instance.song = song
  -- Prepare dialog:
  instance.dialog = Dialog:new(
    song,
    function(_, trackIndex) instance:onTrackButtonPressed(trackIndex) end,
    function() instance:onFillButtonPressed() end,
    function() instance:onStartStopButtonPressed() end,
    function() instance:onPrevButtonPressed() end,
    function() instance:onNextButtonPressed() end
  )
  
  -- Set observers:
  renoise.tool().app_idle_observable:add_notifier(instance.idleObserver)
  nextPattern:add_notifier(instance.updatePatternIndicator)

  return instance
end

-- Called when a new song is loaded, or when the dialog is re-opened
function Live:reset(song)
  currLine = 0
  prevLine = -1
  currPattern.value = 0
  nextPattern.value = 1
  patternPlayCount = 0
  patternSetCount = 1
  -- trackLengths = {}
  userInitiatedFill = false
  resetTriggerLights = false
  stepCount = 0
  masterTrackLength = 0
  trackData = {}
  -- stepCount = 0

  self.song = song
  self.dialog:reset(song)
end

-- Setup pattern, this is called when the dialog opens, and every time a new pattern begins.
function Live:setupPattern()
  local dst = self.song:pattern(1)

  if nextPattern.value ~= currPattern.value and (patternPlayCount + 1) % patternSetCount == 0 then
    -- Prepare a new pattern
    srcPattern = self.song:pattern(nextPattern.value + 1)
    masterTrackLength = srcPattern.number_of_lines
    
    -- Pattern 0 is always 16 steps. The script always pastes new data to the next line
    dst.number_of_lines = 16

    -- Reset some stuff:
    patternPlayCount = 0
    patternSetCount = 1
    userInitiatedFill = false
    self.dialog:setFillButtonState(false)

    -- Get track data of individual tracks:
    for trackIndex=1, #dst.tracks do
      if self.song.tracks[trackIndex].type == renoise.Track.TRACK_TYPE_SEQUENCER or self.song.tracks[trackIndex].type == renoise.Track.TRACK_TYPE_MASTER then
        trackData[trackIndex] = TrackData:new(
          trackIndex,
          self:getPatternTrackLength(srcPattern, trackIndex),
          srcPattern
        )
      end
    end
    
    currPattern.value = nextPattern.value

    self:updatePatternIndicator()
  else
    -- Update play count
    patternPlayCount = patternPlayCount + 1
    
    -- If we're back at the start, the user initiated fill needs to be reset:
    if patternPlayCount % patternSetCount == 0 then
      userInitiatedFill = false
      self.dialog:setFillButtonState(false)
    end
    
    if patternSetCount > 1 then
      self:updatePatternIndicator()
    end
  end
end

-- Get the length of an individual track (based on it's cutoff point)
function Live:getPatternTrackLength(srcPattern, trackIndex)
  patternTrack = srcPattern:track(trackIndex)
  local number_of_lines = srcPattern.number_of_lines
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

-- Idle observer
function Live:idleObserver()
  if self ~= nil and self.song ~= nil then
    currLine = song.transport.playback_pos.line
    if song.transport.playing and currLine ~= prevLine then
      -- currLine has just played, prepare the following line
      self:stepNotifier()
      prevLine = currLine
    elseif resetTriggerLights == true then
      self.dialog:resetTriggerLights()
      resetTriggerLights = false
    end
  end
end

-- This method is called every step
function Live:stepNotifier()
  -- Benchmark
  local time
  if benchmark == true then
    time = os.clock()
  end

  -- Process the next line:
  --[[
  if src ~= nil then
    -- TODO: Move to separate object    
    processLine(
      song,
      (currLine % masterTrackLength) + 1, -- dst line
      src,                                 
      trackState, 
      trackLengths,
      stepCount, 
      currPattern.value ~= nextPattern.value
    )
  end
  ]]--

  -- Increase step
  stepCount = stepCount + 1

  -- Check for pattern change:
  if currLine == masterTrackLength then
    self:setupPattern()
  end

  -- Show trig indicator:
  -- TODO: Performance check on RPI:
  for key in pairs(trackData) do
    local trackIndex = trackData[key].trackIndex
    local line = self.song:pattern(1):track(trackIndex):line(currLine)
    self.dialog:setTriggerLight(trackIndex, self:hasNote(line))
  end
  resetTriggerLights = true

  if benchmark == true then
    -- For reference:
    -- At 140 BPM, 1 step (1/16th note) is approximately 107.14 milliseconds.
    -- So if this script performs well under that it's ok
    print(string.format("stepNotifier() - total elapsed time: %.4f\n", os.clock() - time))
  end
end

-- A little helper method to determine if a TrackLine has a note
function Live:hasNote(line)
  for _, note_column in ipairs(line.note_columns) do
    if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE then
      return true
    end
  end
  
  return false
end

-- Shortcut to update the pattern indicator in the dialog
function Live:updatePatternIndicator()
  self.dialog:updatePatternIndicator(currPattern, nextPattern, patternPlayCount, patternSetCount, userInitiatedFill)
end

-- Show the dialog
function Live:showDialog()
  self:setupPattern()
  self.dialog:show()
  self:reset(self.song)
  self:updatePatternIndicator()
end

-- Queue the next pattern
function Live:queueNextPattern()
  if nextPattern.value < song.transport.song_length.sequence - 1 then
    nextPattern.value = nextPattern.value + 1
  end
end

-- Queue the previous pattern
function Live:queuePrevPattern()
  if nextPattern.value > 1 then
    nextPattern.value = nextPattern.value - 1
  end
end

-- Toggle the mute state for a specific track
function Live:toggleMute(trackIndex)
  local track = self.song.tracks[trackIndex]

  if track == nil or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    return
  end
  
  if track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
    track:mute()
    self.dialog:setMutedStatus(trackIndex, true)
  else
    track:unmute()
    self.dialog:setMutedStatus(trackIndex, false)
    -- Unmute all columns?
  end

  self.dialog:updateTrackButtonColor(trackIndex)
end

-- Called when a track button is pressed
function Live:onTrackButtonPressed(trackIndex)
  -- Mute track:
  self:toggleMute(trackIndex)
end

-- Called when the fill button is pressed
function Live:onFillButtonPressed()
  userInitiatedFill = true
  self.dialog:setFillButtonState(true)
  self:updatePatternIndicator()
end

-- Called when the start/stop button is pressed
function Live:onStartStopButtonPressed()

end

-- Called when the prev-button is pressed
function Live:onPrevButtonPressed()
  self:queuePrevPattern()
end

-- Called when the next-button is pressed
function Live:onNextButtonPressed()
  self:queueNextPattern()
end

return Live
