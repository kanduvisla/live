-- Update the track play count
-- This is calculated using:
--
--  patternPlayCount:   total count of patterns
--  patternLength:      the length of the pattern
--  trackLengths:       dictionary of total lengths of individual tracks
--
-- Returns a dictionary of track play counts
get_track_play_count = function(patternPlayCount, patternLength, trackLengths)
    local result = {}
    local totalPlays = patternLength * patternPlayCount
    for t, length in pairs(trackLengths) do
        result[t] = math.floor((patternLength * patternPlayCount) / length)
    end
    return result
end