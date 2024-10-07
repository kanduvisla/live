getPatternDetails = function(text)
    local result = {}
    local index = 0
    for line in text:gmatch("([^\n]+)") do
        if line:sub(1,1) == "#" then
            index = tonumber(line:sub(2))
            result[index] = ""
        else 
            result[index] = result[index] .. line .. "\n"
        end
    end
    return result
end