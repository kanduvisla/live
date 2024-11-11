require("includes/note_triggers")
require("includes/fill")
require("includes/mute")

-- Process muted state for the track
processMutedTrack = function(effectAmount, trackPlayCount, track, trackState, t)
  local result = isMuted(tonumber(effect.amount_string), trackPlayCount)
  
  if result == true then
    track:mute()
    trackState[t].muted.value = true
  elseif result == false then
    track:unmute()
    trackState[t].muted.value = false
    trackState[t].unmuteCounter.value = 0
  elseif track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
    -- nil is returned, meaning: no change
    trackState[t].unmuteCounter.value = effectAmount - (trackPlayCount % effectAmount)
  end

  return result
end

-- Process a single line
processLine = function(song, dstLine, src, trackState, trackLengths, stepCount)
  local dst = song:pattern(1)
  -- print("srcLine: " .. ((stepCount + 1) % 16) + 1)
  -- print("dstLine: " .. dstLine)
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
        trackLengths
      )
    end
  end
end

--[[
-- tmp
processTrackLine2 = function(song, track, trackIndex, stepCount, dstLine, src, trackState, trackLengths)
  local dst = song:pattern(1)
  -- source is the next step, that's why +1
  local srcLineNumber = ((stepCount + 1) % trackLengths[trackIndex]) + 1
  local line = src:track(trackIndex):line(srcLineNumber)
  print("copy line " .. srcLineNumber .. " to line " .. dstLine)
  dst:track(trackIndex):line(dstLine):copy_from(line)
end
]]--

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
  trackLengths
)
  -- source is the next step, that's why +1
  local srcLineNumber = ((stepCount + 1) % trackLengths[trackIndex]) + 1
  local line = src:track(trackIndex):line(srcLineNumber)

  if track.type == renoise.Track.TRACK_TYPE_MASTER then
    -- TODO: Master track only accepts `ZN` and `ZP`
    local effect = line:effect_column(1)
  elseif track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    local trackPlayCount = math.floor(stepCount / trackLengths[trackIndex])
    local effect = line:effect_column(1)
    local processColumns = true

    -- Check for the ZC column, because that would imply we need to update the trackLengths:
    if effect.number_string == "ZC" then
      -- Update tracklength
      trackLengths[trackIndex] = dstLineNumber - 1
      -- Reset line and effect properties:
      dstLineNumber = stepCount % trackLengths[trackIndex]
      line = src:track(trackIndex):line(dstLineNumber)
      effect = line:effect_column(1)
    end

    -- Check if we need to mute or unmute this track now, otherwise: muted tracks are ignored from processing
    if effect.number_string == "ZM" then
      processMutedTrack(tonumber(effect.amount_string), trackPlayCount, track, trackState, trackIndex)
    elseif effect.number_string == "ZR" then
      -- If there is no trig on track-level, there is no need for column processing:
      -- TODO: trackPlayCount might be affected by `ZC`-effect:
      processColumns = is_trig_active(effect.amount_string, trackPlayCount)
    elseif effect.number_string == "ZI" then
      -- Same as above, but inversed:
      processColumns = is_trig_active(effect.amount_string, trackPlayCount) == false
    end

    -- Don't do an "else" here, because the previous step might have flipped this flag:
    if track.mute_state ~= renoise.Track.MUTE_STATE_MUTED and processColumns == true then
      -- TODO: Process `ZC` effect
      
      -- Iterate over columns to process triggs & fills:
      local columns = line.note_columns
      for c=1, #columns do
        local column = line:note_column(c)
        local effect_number = column.effect_number_string
        local effect_amount = column.effect_amount_string
        -- TODO      
      end
      
      -- If no Live effect is processed, simply copy as-is:
      dst:track(trackIndex):line(dstLineNumber):copy_from(line)
    else
      -- Otherwise clear destination line:
      dst:track(trackIndex):line(dstLineNumber):clear()
    end
  end
end
