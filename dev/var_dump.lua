var_dump = function(value, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    
    if type(value) == "table" then
        print(indent .. "{")
        for k, v in pairs(value) do
            io.write(indent .. "  [" .. tostring(k) .. "] = ")
            var_dump(v, depth + 1)
        end
        print(indent .. "}")
    else
        print(indent .. tostring(value))
    end
end