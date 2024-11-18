-- Determine if there is a fill
-- Returns true if the note is to be kept, false if the note is to be cleared
is_fill = function(currPattern, nextPattern, patternPlayCount, patternSetCount, amountString, userInitiatedFill)
  -- Remove the not playing ones:
  if nextPattern ~= currPattern or userInitiatedFill == true then
    -- Transition to another pattern
    -- Check if we're in the last run of the set:
    if (patternPlayCount + 1) % patternSetCount == 0 then
      -- We're in a transition, filter out "00"
      if amountString == "00" then
        return false
      end
    else
      -- We're not yet in the last part of the set, filter out "01"
      if amountString == "01" then
        return false
      end
    end
  else
    -- No transition to another pattern, filter out "01"
    if amountString == "01" then
      return false
    end
  end
  
  return true
end

-- Determine if there is a fill
-- Returns true if the note is to be kept, false if the note is to be cleared
isFillActive = function(isFillApplicable, amountString)
  -- Only "ZF01" is allowed to play ...
  if isFillApplicable and amountString == "01" then
    return true
  end
  
  -- ... and nothing else: 
  return false
  --[[
    -- Manual fill or transition to another pattern
    -- Check if we're in the last run of the set:
    if (trackPlayCount + 1) % trackSetCount == 0 then
      -- We're in a the last pattern play of the transition, filter out "00"
      if amountString == "00" then
        return false
      end
    else
      -- We're not yet in the last pattern of the transition yet, filter out "01"
      if amountString == "01" then
        return false
      end
    end
  else
    -- No manual fill or transition to another pattern, filter out "01"
    if amountString == "01" then
      return false
    end
  end
  
  return true
  ]]--
end
