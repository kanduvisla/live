require("includes/note_triggers")
require("includes/fill")
require("includes/mute")

local LineProcessor = {}
LineProcessor.__index = LineProcessor

local stepCount = 0
local dst

-- Create a new line processor
function LineProcessor:new(
  song,
  trackData,
  onSetTrackMuted,
  onSetTrackColumnMuted,
  onUpdateUnmuteCounter,
  onChangePatternSetCount,
  onSetNextPattern
)
  local instance = setmetatable({}, LineProcessor)

  dst = song:pattern(1)

  instance.song = song
  instance.trackData = trackData
  instance.onSetTrackMuted = onSetTrackMuted
  instance.onSetTrackColumnMuted = onSetTrackColumnMuted
  instance.onUpdateUnmuteCounter = onUpdateUnmuteCounter
  instance.onChangePatternSetCount = onChangePatternSetCount
  instance.onSetNextPattern = onSetNextPattern

  return instance
end

-- Reset the line processor
function LineProcessor:reset(song, trackData)
  self.song = song
  dst = song:pattern(1)
  self.trackData = {}
  stepCount = 1
end

-- Only reset the step counter
function LineProcessor:resetStepCounter()
  stepCount = 1
end

-- Set the track data
function LineProcessor:setTrackData(trackData)
  self.trackData = trackData
end

-- Take a single step
function LineProcessor:step()
  stepCount = stepCount + 1
end

-- Process a single line
function LineProcessor:process(dstLineNumber, isFillApplicable)
  -- Iterate over every sequencer track:
  for trackIndex=1, #dst.tracks do
    local track = self.song:track(trackIndex)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER or track.type == renoise.Track.TRACK_TYPE_MASTER then
      self:processTrackLine(track, trackIndex, dstLineNumber, isFillApplicable)
    end
  end
end

-- Process a single track line
function LineProcessor:processTrackLine(track, trackIndex, dstLineNumber, isFillApplicable)
  -- Track data can be nil due to the idle processor:
  if self.trackData[trackIndex] == nil then
    return
  end

  local trackLength = self.trackData[trackIndex].trackLength
  local src = self.trackData[trackIndex].srcPattern
  local srcLineNumber = self.trackData[trackIndex]:getSrcLineNumber(stepCount)
  
  -- if srcLineNumber is nil, then it means we're dealing with a time-divided track and no action is required for this step. However, it needs to be cleared:
  if srcLineNumber == nil then
    dst:track(trackIndex):line(dstLineNumber):clear()
    return
  end
  
  local line = src:track(trackIndex):line(srcLineNumber)
  local effect = line:effect_column(1)

  if track.type == renoise.Track.TRACK_TYPE_MASTER then
    if effect.number_string == "ZP" then
      -- Set pattern set count
      self:onChangePatternSetCount(tonumber(effect.amount_string))
    elseif effect.number_string == "ZN" then
      -- Set next track
      self:onSetNextPattern(tonumber(effect.amount_string))
    end
  elseif track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    local trackPlayCount = math.floor(stepCount / trackLength)
    local processColumns = true

    -- Check if we need to mute or unmute this track now, otherwise: muted tracks are ignored from processing
    if effect.number_string == "ZM" then
      processColumns = self:processMutedTrack(tonumber(effect.amount_string), trackPlayCount, track, trackIndex) == false
    elseif effect.number_string == "ZR" then
      -- If there is no trig on track-level, there is no need for column processing:
      -- TODO: trackPlayCount might be affected by `ZC`-effect:
      processColumns = is_trig_active(effect.amount_string, trackPlayCount)
    elseif effect.number_string == "ZI" then
      -- Same as above, but inversed:
      processColumns = is_trig_active(effect.amount_string, trackPlayCount) == false
    elseif effect.number_string == "ZF" then
      -- Fill:
      processColumns = isFillActive(isFillApplicable, effect.amount_string)
    elseif effect.number_string == "ZV" then
      local amount = tonumber(effect.amount_string)
      if self.trackData[trackIndex].trackSpeedDivider ~= amount and amount > 0 then
        self.trackData[trackIndex].trackSpeedDivider = amount
        -- Re-load the line:
        srcLineNumber = self.trackData[trackIndex]:getSrcLineNumber(stepCount)
        line = src:track(trackIndex):line(srcLineNumber)
      end
    end

    -- Don't do an "else" here, because the previous step might have flipped this flag:
    if track.mute_state ~= renoise.Track.MUTE_STATE_MUTED and processColumns == true then
      -- Iterate over columns to process triggs & fills:
      local processNote = true
      local columns = line.note_columns

      for c=1, #columns do
        local column = line:note_column(c)
        local effect_number = column.effect_number_string
        local effect_amount = column.effect_amount_string

        if effect_number == "ZR" then
          -- Trig:
          processNote = is_trig_active(effect_amount, trackPlayCount)
        elseif effect_number == "ZI" then
          -- Inversed Trig:
          processNote = is_trig_active(effect_amount, trackPlayCount) == false
        elseif effect_number == "ZM" then
          -- Mute
          processNote = self:processMutedColumn(tonumber(effect_amount), trackPlayCount, c, track, trackIndex) == false
        elseif effect_number == "ZF" then
          -- Fill:
          processNote = isFillActive(isFillApplicable, effect_amount)
        end
      end
      
      if processNote then
        -- If no Live effect is processed, simply copy as-is:
        dst:track(trackIndex):line(dstLineNumber):copy_from(line)
      else
        -- Otherwise clear destination line:
        dst:track(trackIndex):line(dstLineNumber):clear()
      end
    else
      -- Otherwise clear destination line:
      dst:track(trackIndex):line(dstLineNumber):clear()
    end
  end
end

-- Process muted state for the track
function LineProcessor:processMutedTrack(effectAmount, trackPlayCount, track, trackIndex)
  -- print(trackPlayCount)
  local result = isMuted(tonumber(effectAmount), trackPlayCount)

  if result == true then
    track:mute()
    self:onSetTrackMuted(trackIndex, true)
    self:onUpdateUnmuteCounter(trackIndex, effectAmount - (trackPlayCount % effectAmount))
  elseif result == false then
    track:unmute()
    self:onSetTrackMuted(trackIndex, false)
  elseif track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
    -- nil is returned, meaning: no change
    if trackPlayCount < effectAmount then
      self:onUpdateUnmuteCounter(trackIndex, effectAmount - (trackPlayCount % effectAmount))
    end
    return nil
  end

  -- return default state
  return track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE
end

-- Process muted state for a column
function LineProcessor:processMutedColumn(effectAmount, trackPlayCount, columnIndex, track, trackIndex)
  local result = isMuted(tonumber(effectAmount), trackPlayCount)

  if result == true then
    track:set_column_is_muted(columnIndex, true)
    self:onSetTrackColumnMuted(trackIndex, columnIndex, true)
  elseif result == false then
    track:set_column_is_muted(columnIndex, false)
    self:onSetTrackColumnMuted(trackIndex, columnIndex, false)
  end

  return result
end

return LineProcessor
