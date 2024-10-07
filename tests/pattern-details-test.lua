require("../includes/pattern-details")
require("../dev/var_dump")
require("../dev/table_length")

local function testGetPatternDetails()
    -- Setup:
    local input = [[
#1
Lorem ipsum
Line 2
#2
Dolar sit amet
#4
Foo Bar
]]

    local output = getPatternDetails(input)
    print(tableLength(output))
    var_dump(output)
end

testGetPatternDetails()