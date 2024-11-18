local Live = require("live")
local tool = renoise.tool()
local live

-- Reset when a new project is loaded:
tool.app_release_document_observable:add_notifier(function()
  if live ~= nil then
    live:reset(renoise.song())
  end
end)

-- Add menu entry:
tool:add_menu_entry {
  name = "Main Menu:Tools:Live",
  invoke = function()
    if live == nil then
      live = Live:new(renoise.song())
    end
    
    live:showDialog(renoise.song())
  end
}
