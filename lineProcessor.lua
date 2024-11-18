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
  onChangePatternPlayCount,
  onSetNextPattern
)
  local instance = setmetatable({}, LineProcessor)

  dst = song:pattern(1)

  instance.song = song
  instance.trackData = trackData
  instance.onSetTrackMuted = onSetTrackMuted
  instance.onSetTrackColumnMuted = onSetTrackColumnMuted
  instance.onUpdateUnmuteCounter = onUpdateUnmuteCounter
  instance.onChangePatternPlayCount = onChangePatternPlayCount
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
function LineProcessor:process(dstLineNumber, isTransitioning)
  -- Iterate over every sequencer track:
  for trackIndex=1, #dst.tracks do
    local track = self.song:track(trackIndex)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER or track.type == renoise.Track.TRACK_TYPE_MASTER then
      self:processTrackLine(track, trackIndex, dstLineNumber, isTransitioning)
    end
  end
end

-- Process a single track line
function LineProcessor:processTrackLine(track, trackIndex, dstLineNumber, isTransitioning)
  -- Track data can be nil due to the idle processor:
  if self.trackData[trackIndex] == nil then
    return
  end

  local trackLength = self.trackData[trackIndex].trackLength
  local src = self.trackData[trackIndex].srcPattern
  local srcLineNumber = self.trackData[trackIndex]:getSrcLineNumber(stepCount)
  local line = src:track(trackIndex):line(srcLineNumber)
  local effect = line:effect_column(1)

  if track.type == renoise.Track.TRACK_TYPE_MASTER then
    -- TODO: Master track only accepts `ZN` and `ZP`
    if effect.number_string == "ZP" then
      -- Set pattern play count
      self:onChangePatternPlayCount(tonumber(effect.amount_string))
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
      -- TODO: Add user initiated fills
      -- TODO: Track Set Count (how many times does a pattern "loop" inside a set) (now it's limited to the entire pattern length)
      -- processColumns = isFillActive(isTransitioning, trackPlayCount, patternPlayCount, effect.amount_string, false)
      -- TODO
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
          processNote = processMutedColumn(tonumber(effect_amount), trackPlayCount, c, track, trackState, trackIndex) == false
        elseif effect_number == "ZF" then
          -- Fill (TODO)
          -- processNote = isFillActive(isTransitioning, trackPlayCount, patternPlayCount, effect_amount, false)
        end
      end
      
      --[[
      if trackIndex == 1 then
        print(stepCount)
        print(srcLineNumber)
        rprint(src:track(trackIndex):line(1))
      end
      ]]--
      
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
  print(trackPlayCount)
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
    self:onUpdateUnmuteCounter(trackIndex, effectAmount - (trackPlayCount % effectAmount))
  end

  return result
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
