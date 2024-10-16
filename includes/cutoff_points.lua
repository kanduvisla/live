-- Process cutoff points ("LC" effect)
-- If no cutoff points were found / processed, this funtion returns false
process_cutoff_points = function(t, dstPattern, srcPattern, song, trackLengths, patternPlayCount)
  local dstTrack = dstPattern:track(t)
  local numberOfLines = dstPattern.number_of_lines
  for l=1, numberOfLines do
    -- Check for "LC" filter
    if dstTrack:line(l):effect_column(1).number_string == "LC" then
      -- A cutoff point indicates a place in the track where a selection needs to be copy/pasted.
      -- This means we "fill" the pattern with everything that is above the LC, and keep track of how many
      -- times it has already copied to keep the remainder in mind.
      
      -- How many times does this pattern "fit" in this track:
      local duplicationCount = math.ceil(numberOfLines / trackLengths[t])
      
      -- Copy from first line up until the line with the "LC" effectL
      for fl=1, l - 1 do
        -- Offset from the previous iteration:
        local offset = (patternPlayCount * numberOfLines) % trackLengths[t]
        for d=1, duplicationCount do
          local dstLine = fl + (trackLengths[t] * (d - 1)) - offset
          if dstLine <= numberOfLines and dstLine > 0 then
            -- print("duplicate line " .. fl .. " to " .. dstLine)
            -- Check for trigs:

            -- A virtual count to see how many times this track has played
            -- This is used to determine if trigs need to be added:
            local virtualTrackPlayCount = math.floor(((patternPlayCount * numberOfLines) + dstLine - 1) / trackLengths[t])
            -- print("virtual track play count: " .. virtualTrackPlayCount)
            
            local srcLine = srcPattern:track(t):line(fl)
            local lineEffect = srcLine:effect_column(1)
            -- print("line effect on line " .. fl .. ": " .. lineEffect.amount_string)
            
            -- Fill:
            if lineEffect.number_string == "LF" then
              -- TODO, how to do fills with polyrhythm?
            elseif lineEffect.number_string == "LT" then
              -- Trigger:
              if is_trig_active(lineEffect.amount_string, virtualTrackPlayCount) then
                dstTrack:line(dstLine):copy_from(srcLine)
                print("trig is true for line " .. dstLine)
              else
                print("trig is false for line " .. dstLine)
                dstTrack:line(dstLine):clear()
              end
              print("pattern play count: " .. patternPlayCount)
              print("virtual track play count: " .. virtualTrackPlayCount)
            elseif lineEffect.number_string == "LI" then
              -- Inverse Trigger:
              if not is_trig_active(lineEffect.amount_string, virtualTrackPlayCount) then
                print("trig is true for line " .. dstLine)
                print("pattern play count: " .. patternPlayCount)
                print("virtual track play count: " .. virtualTrackPlayCount)
                
                dstTrack:line(dstLine):copy_from(srcLine)                
              else
                dstTrack:line(dstLine):clear()
              end
            else
              -- No Live effect, just copy the line:
              dstTrack:line(dstLine):copy_from(srcLine)
            end

            -- TODO: columns
          end -- end if#line<>
        end -- end for#duplicationCount
      end -- end for#fl
      
      return true
    end -- end if#"LC"
  end -- end for#numberOfLines
  
  return false
end
