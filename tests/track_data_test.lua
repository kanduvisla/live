local TrackData = require("../includes/track_data")
require("../dev/var_dump")

local data = TrackData:new(1, 16)

assert(data:getSrcLineNumber(1) == 1)
assert(data:getSrcLineNumber(2) == 2)
assert(data:getSrcLineNumber(16) == 16)
assert(data:getSrcLineNumber(17) == 1)

-- Add a nudge:
data.nudge = 1
assert(data:getSrcLineNumber(1) == 2)
assert(data:getSrcLineNumber(2) == 3)
assert(data:getSrcLineNumber(15) == 16)
assert(data:getSrcLineNumber(16) == 1)

-- Subtract a nudge:
data.nudge = -3
assert(data:getSrcLineNumber(1) == 14)
assert(data:getSrcLineNumber(2) == 15)
assert(data:getSrcLineNumber(3) == 16)
assert(data:getSrcLineNumber(4) == 1)
assert(data:getSrcLineNumber(15) == 12)
assert(data:getSrcLineNumber(16) == 13)

-- Different speed:
data.nudge = 0
data.trackSpeedDivider = 2

assert(data:getSrcLineNumber(1) == 1)
assert(data:getSrcLineNumber(2) == nil)
assert(data:getSrcLineNumber(3) == 2)
assert(data:getSrcLineNumber(4) == nil)
assert(data:getSrcLineNumber(5) == 3)
assert(data:getSrcLineNumber(7) == 4)
assert(data:getSrcLineNumber(9) == 5)
assert(data:getSrcLineNumber(11) == 6)
assert(data:getSrcLineNumber(13) == 7)
assert(data:getSrcLineNumber(15) == 8)
assert(data:getSrcLineNumber(16) == nil)
assert(data:getSrcLineNumber(17) == 9)
assert(data:getSrcLineNumber(29) == 15)
assert(data:getSrcLineNumber(30) == nil)
assert(data:getSrcLineNumber(31) == 16)
assert(data:getSrcLineNumber(32) == nil)
assert(data:getSrcLineNumber(33) == 1)

-- Add a nudge:
data.nudge = 1
assert(data:getSrcLineNumber(1) == 2)
assert(data:getSrcLineNumber(2) == nil)
assert(data:getSrcLineNumber(3) == 3)
assert(data:getSrcLineNumber(4) == nil)
assert(data:getSrcLineNumber(5) == 4)
assert(data:getSrcLineNumber(29) == 16)
assert(data:getSrcLineNumber(30) == nil)
assert(data:getSrcLineNumber(31) == 1)
assert(data:getSrcLineNumber(32) == nil)
assert(data:getSrcLineNumber(33) == 2)

-- Subtract a nudge:
data.nudge = -3
assert(data:getSrcLineNumber(1) == 14)
assert(data:getSrcLineNumber(2) == nil)
assert(data:getSrcLineNumber(3) == 15)
assert(data:getSrcLineNumber(4) == nil)
assert(data:getSrcLineNumber(15) == 5)
assert(data:getSrcLineNumber(16) == nil)

-- Different speed:
data.nudge = 0
data.trackSpeedDivider = 3

assert(data:getSrcLineNumber(1) == 1)
assert(data:getSrcLineNumber(2) == nil)
assert(data:getSrcLineNumber(3) == nil)
assert(data:getSrcLineNumber(4) == 2)
assert(data:getSrcLineNumber(34) == 12)
assert(data:getSrcLineNumber(35) == nil)
assert(data:getSrcLineNumber(46) == 16)
assert(data:getSrcLineNumber(47) == nil)
assert(data:getSrcLineNumber(48) == nil)
assert(data:getSrcLineNumber(49) == 1)
