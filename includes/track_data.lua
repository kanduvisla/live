local TrackData = {}
TrackData.__index = TrackData

-- Create new TrackData instance
--  trackIndex          : The index of this individual track
--  trackLength         : The length of this individual track
--  srcPattern          : The source pattern to copy the track from (not used)
--  trackSpeedDivider   : A number to divide this speed in
function TrackData:new(trackIndex, trackLength, srcPattern, trackSpeedDivider)
    local instance = setmetatable({}, TrackData)
    instance.trackIndex = trackIndex
    instance.trackLength = trackLength
    instance.srcPattern = srcPattern
    instance.trackSpeedDivider = trackSpeedDivider or 1
    instance.nudge = 0
    return instance
end

-- Get the line number of the source track to copy the step from, or nil of no copy is needed
function TrackData:getSrcLineNumber(step)
    if self.trackSpeedDivider == 1 then
        return 1 + ((step - 1 + self.nudge) % self.trackLength)
    elseif (step - 1) % self.trackSpeedDivider == 0 then
        return 1 + (((step - 1 + (self.nudge * self.trackSpeedDivider)) / self.trackSpeedDivider) % self.trackLength)
    end

    return nil
end

return TrackData