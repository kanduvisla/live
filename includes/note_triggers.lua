-- Is this trig active?
-- Is determined by the amount string and the total times this section has played
is_trig_active = function(amount_string, play_count)
  if amount_string == "00" then 
    return play_count ~= 0
  end

  if amount_string == "01" then 
    return play_count == 0
  end
  
  local length = tonumber(amount_string:sub(1, 1))
  local modulo = tonumber(amount_string:sub(2, 2))

  if modulo == 0 then
    return play_count == length - 1
  end

  return play_count % length == modulo - 1
end