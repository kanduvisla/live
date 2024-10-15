assert_dictionary = function (actual, expected)
    for key, value in pairs(actual) do
        assert(value == expected[key], "Expected " .. expected[key] .. ", got: " .. value)
    end
end