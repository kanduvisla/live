require("../includes/note-triggers")
require("../dev/var_dump")

createEffectColumn() = function()
    return {
        number_string = "L0",
        amount_string = "00"
    }
end

createLine = function()
    return {

    }
end

createTrack = function()
    return {
        type = 1,
        lines = {

        }
    }
end

local song = {
    tracks = {
        createTrack(),
        createTrack(),
        createTrack(),
    }    
}

var_dump(setNoteTriggers(song))