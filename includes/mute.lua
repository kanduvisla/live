-- Determine if the muted-flag should be true or false, or unchanged (null)
isMuted = function(effectAmount, trackPlayCount)
  if patternPlayCount == 0 then
    return true
  end

  if effectAmount == 0 then
    return nil
  end

  if patternPlayCount == effectAmount then
    return false
  end

  return nil
end
