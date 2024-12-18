local Dialog = require("ui/dialog")
local TrackData = require("includes/track_data")
local LineProcessor = require("lineProcessor")

local Live = {}
Live.__index = Live

-- Private properties
local benchmark = false
local doc = renoise.Document
local currLine = 1
local prevLine = 1
-- local patternPlayCount = 0
local patternSetCount = 1
local currPattern = doc.ObservableNumber(0)
local nextPattern = doc.ObservableNumber(1)
local userInitiatedFill = false
local resetTriggerLights = false
-- local masterTrackLength = 0
local trackData = {}
local isMuteQueueActive = false
local muteQueue = {}
local idleNotifier = nil

-- Total length, this is the number of lines of pattern 0. Min 2, otherwise you get wEiRdNeSs!
local totalLength = 16

-- This is a counter that counts how many times pattern 0 has looped.
-- This number is used in conjunction with currLine and totalLength to determine the current step
local totalIterations = 0

-- This is the length per pattern. It's used to to determine how many times the pattern
-- has already looped in the totalLength. The totalLength divided by the patternLength
-- is the max of pattern loops that is possible before it resets (e.g. 512/16=32)
local patternLength = 16

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
    function() instance:onNextButtonPressed() end,
    function() instance:onMuteQueuePressed() end
  )
  
  -- Create line processor
  instance.lineProcessor = LineProcessor:new(
    song,
    {},
    function(_, trackIndex, muted) instance:onSetTrackMuted(trackIndex, muted) end,
    function(_, trackIndex, trackColumnIndex, muted) instance:onSetTrackColumnMuted(trackIndex, trackColumnIndex, muted) end,
    function(_, trackIndex, unmuteCounter) instance:onUpdateUnmuteCounter(trackIndex, unmuteCounter) end,
    function(_, newPatternSetCount) instance:onUpdatePatternSetCount(newPatternSetCount) end,
    function(_, nextPatternValue) nextPattern.value = nextPatternValue end
  )

  -- Set observers:
  idleNotifier = function() instance:idleObserver() end
  nextPattern:add_notifier(function() instance:updatePatternIndicator() end)

  return instance
end

-- Called when a new song is loaded, or when the dialog is re-opened
function Live:reset(song)
  currLine = 0
  prevLine = 0
  currPattern.value = 1
  nextPattern.value = 1
  -- patternPlayCount = 0
  patternSetCount = 1
  userInitiatedFill = false
  resetTriggerLights = false
  -- masterTrackLength = 0
  trackData = {}

  self.song = song
  self.dialog:reset(song)
  self.lineProcessor:reset(song)
end

function Live:getPatternPlayCount()
  return totalIterations + math.floor((currLine - 1) / patternLength)  
end

-- Setup pattern, this is called when the dialog opens, and every time a new pattern begins.
function Live:setupPattern()
  local dst = self.song:pattern(1)
  local patternPlayCount = self:getPatternPlayCount()
  
  if nextPattern.value ~= currPattern.value and (patternPlayCount + 1) % patternSetCount == 0 then
    -- Prepare a new pattern
    local srcPattern = self.song:pattern(nextPattern.value + 1)
    
    -- Process mute queue
    for trackIndex, process in pairs(muteQueue) do
      if process then
        self:toggleMute(trackIndex)
      end
      muteQueue = {}
    end

    -- masterTrackLength = srcPattern.number_of_lines
    
    -- Pattern 0 is always 16 steps. The script always pastes new data to the next line
    -- TODO: Investigate if it makes more sense with a single pattern of 512 steps
    dst.number_of_lines = totalLength

    -- Reset some stuff:
    -- patternPlayCount = 0
    patternSetCount = 1
    totalIterations = 0
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
    
    self.lineProcessor:setTrackData(trackData)
    -- self.lineProcessor:resetStepCounter()

    currPattern.value = nextPattern.value
    
    -- self:updatePatternIndicator()
  else
    -- Update play count
    -- patternPlayCount = patternPlayCount + 1
    
    totalIterations = totalIterations + 1
    
    -- If we're back at the start, the user initiated fill needs to be reset:
    if patternPlayCount % patternSetCount == 0 then
      userInitiatedFill = false
      self.dialog:setFillButtonState(false)
    end
    
    --if patternSetCount > 1 then
    --  self:updatePatternIndicator()
    --end
  end
end

-- Get the length of an individual track (based on it's cutoff point)
function Live:getPatternTrackLength(srcPattern, trackIndex)
  local patternTrack = srcPattern:track(trackIndex)
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
  if self ~= nil and self.song ~= nil and self.dialog:isVisible() then
    currLine = self.song.transport.playback_pos.line
    if self.song.transport.playing and currLine ~= prevLine then
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

  -- Check for pattern change:
  if currLine % patternLength == 0 then
    -- We have just played the last note in this pattern
    -- Setup (potentialy) next pattern:
    self:setupPattern()
  end

  -- Process the next line:
  local patternPlayCount = self:getPatternPlayCount()
  local isLastPattern = (patternPlayCount + 1) % patternSetCount == 0
  
  -- Prepare the next line:
  local nextLine = currLine + 1
  if nextLine > totalLength then
    nextLine = nextLine - totalLength
  end

  --[[
  -- Detect frame drop:
  if currLine ~= prevLine + 1 and (currLine + prevLine ~= 0) and (prevLine - currLine ~= totalLength - 1) then
    -- We detected a frame drop.
    -- This means that nextLine can be < totalLength, but we still need to increase an iteration
    if nextLine > totalLength then
      nextLine = nextLine - totalLength
      -- Increase iteration:
      -- print("increase iteration due to frame drop")
      -- totalIterations = totalIterations + 1
    else
      -- Check with prevLine if we need to increase the iteration:
      -- If a frame has dropped, prevLine will still be in the old state (currLine + nextLine won't be)
      if nextLine < prevLine then 
        -- Increase iteration:
        -- print("increase iteration because nextline < prevLine #1")
        -- totalIterations = totalIterations + 1
      end
    end
  elseif nextLine > totalLength then
    nextLine = nextLine - totalLength
    -- Increase iteration:
    -- print("increase iteration because nextline < prevLine #2")
    -- totalIterations = totalIterations + 1
  end
  ]]--
  
  self.lineProcessor:setStep((totalLength * totalIterations) + nextLine)
  self.lineProcessor:process(
    nextLine,
    isLastPattern and (currPattern.value ~= nextPattern.value or userInitiatedFill)
  )

  self:updatePatternIndicator()
  
  -- Increase step
  -- self.lineProcessor:step()

  -- Show trig indicator:
  -- TODO: Performance check on RPI:
  if currLine > 0 then
    for key in pairs(trackData) do
      local trackIndex = trackData[key].trackIndex
      local line = self.song:pattern(1):track(trackIndex):line(currLine)
      self.dialog:setTriggerLight(trackIndex, self:hasNote(line))
    end
    resetTriggerLights = true
  end

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
  local patternPlayCount = self:getPatternPlayCount()
  self.dialog:updatePatternIndicator(
    currPattern, 
    nextPattern, 
    patternPlayCount, 
    patternSetCount, 
    userInitiatedFill,
    currLine,
    patternLength
  )
end

-- Update the pattern set count
function Live:onUpdatePatternSetCount(newPatternSetCount)
  patternSetCount = newPatternSetCount
  -- self:updatePatternIndicator()
end

-- Show the dialog
function Live:showDialog(song)
  self:reset(song)
  self:setupPattern()
  self.dialog:show()
  
  -- Process first step:
  -- currLine = 1
  -- self:stepNotifier()
  -- patternPlayCount = 0
  self:updatePatternIndicator()
end

-- Queue the next pattern
function Live:queueNextPattern()
  if nextPattern.value < self.song.transport.song_length.sequence - 1 then
    nextPattern.value = nextPattern.value + 1
  end
  if self.song.transport.playing  == false then
    currPattern.value = nextPattern.value
    self:updatePatternIndicator()
  end
end

-- Queue the previous pattern
function Live:queuePrevPattern()
  if nextPattern.value > 1 then
    nextPattern.value = nextPattern.value - 1
  end
  if self.song.transport.playing  == false then
    currPattern.value = nextPattern.value
    self:updatePatternIndicator()
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
  if isMuteQueueActive == false then
    self:toggleMute(trackIndex)
  else
    if muteQueue[trackIndex] == nil then
      muteQueue[trackIndex] = true      
    else
      muteQueue[trackIndex] = muteQueue[trackIndex] == false
    end
    print(muteQueue[trackIndex])
    self.dialog:setMutedStatus(trackIndex, muteQueue[trackIndex], true)
  end
end

-- Called when the fill button is pressed
function Live:onFillButtonPressed()
  userInitiatedFill = true
  self.dialog:setFillButtonState(true)
  -- self:updatePatternIndicator()
end

-- Called when the start/stop button is pressed
function Live:onStartStopButtonPressed()
  if self.song.transport.playing then
    -- Somehow we need to hard reset this before we stop it, otherwise steps get missed and everything is a step off somehow...
    local song_pos = renoise.SongPos(1, 1)
    self.song.transport:start_at(song_pos)
    self.song.transport:stop()
    self.dialog:updatePlayButton(false)
    if renoise.tool().app_idle_observable:has_notifier(idleNotifier) then
      renoise.tool().app_idle_observable:remove_notifier(idleNotifier)
    end
  else
    self.lineProcessor:resetStepCounter()
    -- patternPlayCount = 0
    patternSetCount = 1
    -- Do the first step so the first line gets populated
    -- Make sure that the pattern gets initialized:
    currLine = 0
    totalIterations = 0
    currPattern.value = 0
    nextPattern.value = 1
    self:stepNotifier()
    currLine = 1
    totalIterations = 0
    self:stepNotifier()

    -- Reset pattern play count, so it always starts at 0
    -- patternPlayCount = 0
    
    self.song.transport.loop_pattern = true
    local song_pos = renoise.SongPos(1, 1)
    self.song.transport:start_at(song_pos)

    -- self:stepNotifier()
    self:updatePatternIndicator()      
    self.dialog:updatePlayButton(true)
    
    if renoise.tool().app_idle_observable:has_notifier(idleNotifier) == false then
      renoise.tool().app_idle_observable:add_notifier(idleNotifier)
    end
  end
end

-- Called when the prev-button is pressed
function Live:onPrevButtonPressed()
  self:queuePrevPattern()
end

-- Called when the next-button is pressed
function Live:onNextButtonPressed()
  self:queueNextPattern()
end

-- Called when the "Mute Queue" button is pressed
function Live:onMuteQueuePressed()
  isMuteQueueActive = isMuteQueueActive == false
  self.dialog:setMuteQueueButtonState(isMuteQueueActive)
end

-- Called when a track is muted from the lineProcessor
function Live:onSetTrackMuted(trackIndex, muted)
  self.dialog:setMutedStatus(trackIndex, muted)
end

-- Called when a muted column has played a loop again
function Live:onUpdateUnmuteCounter(trackIndex, value)
  self.dialog:setUnmuteCounter(trackIndex, value)  
end

-- Called when a track column is muted from the lineProcessor
function Live:onSetTrackColumnMuted(trackIndex, columnIndex, muted)
  if muted == true then
    self.dialog:updateMutedColumnCount(trackIndex, 1)
  else
    self.dialog:updateMutedColumnCount(trackIndex, -1)
  end
end

return Live
