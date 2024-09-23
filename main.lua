-- Some basic vars for reuse:
local app = renoise.app()
local tool = renoise.tool()
local song = renoise.song()
local doc = renoise.Document

-- View Builder for preferences and set scale
local vbp = renoise.ViewBuilder()
local vbc = renoise.ViewBuilder
local vbwp = vbp.views

-- Variables used:
local currLine = 0
local prevLine = -1

-- Main window
showMainWindow = function()

end

-- Setup pattern, this is called every time a new pattern begins
setupPattern = function()

end

-- Add notifier each time the loop ends:
local function stepNotifier()  
  -- Check for pattern change:
  if currLine == song.patterns[1].number_of_lines then
    -- Change patterns:
    setupPattern()
  end
  
  -- Show trig indicator:
  for key in pairs(data) do
    local trackData = data[key]
    local line = song.patterns[1].tracks[trackData.track].lines[currLine]
    data[key].trigged.value = line.is_empty == false
  end
end

-- Step notifier:
renoise.tool().app_idle_observable:add_notifier(function()
  currLine = song.transport.playback_pos.line
  if song.transport.playing and currLine ~= prevLine then
    stepNotifier()
    prevLine = currLine
  end
end)

-- Add menu entry:
tool:add_menu_entry {
  name = "Main Menu:Tools:Live",
  invoke = function()
    showMainWindow()
  end
}
