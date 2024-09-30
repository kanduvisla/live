getPatternDetails = function(input) 
    local result = {}
    for index, text in input:gmatch("#(%d+)%s*(.-)%s*(?=#%d+|$)") do
        result[tonumber(index)] = text:match("^%s*(.-)%s*$")  -- Trim leading and trailing whitespace
    end
    return result
end