require("includes/note_triggers")
require("includes/fill")
require("includes/mute")

-- Private properties:

-- The amount of times the pattern plays before the transition to another pattern is done
local patternPlayCount = 1

-- Process muted state for the track
processMutedTrack = function(effectAmount, trackPlayCount, track, trackState, t)
  local result = isMuted(tonumber(effectAmount), trackPlayCount)
  
  if result == true then
    track:mute()
    trackState[t].muted.value = true
  elseif result == false then
    track:unmute()
    trackState[t].muted.value = false
    trackState[t].unmuteCounter.value = 0
  elseif track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
    -- nil is returned, meaning: no change
    trackState[t].unmuteCounter.value = effectAmount - (trackPlayCount % effectAmount) - 1
  end

  return result
end

-- Process muted state for a column
processMutedColumn = function(effectAmount, trackPlayCount, c, track, trackState, t)
  local result = isMuted(tonumber(effectAmount), trackPlayCount)

  if result == true then
    track:set_column_is_muted(c, true)
    trackState[t].mutedColumnCount.value = trackState[t].mutedColumnCount.value + 1
  elseif result == false then
    track:set_column_is_muted(c, false)
    trackState[t].mutedColumnCount.value = trackState[t].mutedColumnCount.value - 1
  end

  return result
end

-- Process a single line
processLine = function(song, dstLine, src, trackState, trackLengths, stepCount, isTransitioning)
  local dst = song:pattern(1)
  -- Iterate over every sequencer track:
  for trackIndex=1, #dst.tracks do
    local track = song:track(trackIndex)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER or track.type == renoise.Track.TRACK_TYPE_MASTER then
      processTrackLine(
        song, 
        track, 
        trackIndex, 
        stepCount,
        dstLine, 
        dst, 
        src, 
        trackState, 
        trackLengths,
        isTransitioning
      )
    end
  end
end

-- Process a single line of a track
processTrackLine = function(
  song, 
  track, 
  trackIndex, 
  stepCount, 
  dstLineNumber, 
  dst, 
  src, 
  trackState, 
  trackLengths,
  isTransitioning
)
  -- source is the next step, that's why +1
  local srcLineNumber = ((stepCount + 1) % trackLengths[trackIndex]) + 1
  local line = src:track(trackIndex):line(srcLineNumber)

  if track.type == renoise.Track.TRACK_TYPE_MASTER then
    -- TODO: Master track only accepts `ZN` and `ZP`
    local effect = line:effect_column(1)
    if effect.number_string == "ZP" then
      -- Set pattern play count
      patternPlayCount = tonumber(effect.amount_string)
    elseif effect.number_string == "ZN" then
      -- TODO: Set next track

    end
  elseif track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    local trackPlayCount = math.floor(stepCount / trackLengths[trackIndex])
    local effect = line:effect_column(1)
    local processColumns = true

    -- Check if we need to mute or unmute this track now, otherwise: muted tracks are ignored from processing
    if effect.number_string == "ZM" then
      processColumns = processMutedTrack(tonumber(effect.amount_string), trackPlayCount, track, trackState, trackIndex) == false
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
      processColumns = isFillActive(isTransitioning, trackPlayCount, patternPlayCount, effect.amount_string, false)
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
          -- Fill
          processNote = isFillActive(isTransitioning, trackPlayCount, patternPlayCount, effect_amount, false)
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
