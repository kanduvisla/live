-- Determine if there is a fill
-- Returns true if the note is to be kept, false if the note is to be cleared
is_fill = function(currPattern, nextPattern, patternPlayCount, patternSetCount, amountString)
  -- Remove the not playing ones:
  if nextPattern ~= currPattern then
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

