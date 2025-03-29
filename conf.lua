-- conf.lua
-- Configures the LÖVE application before it starts.

function love.conf(t)
    -- Window Settings
    t.window.title = "Basic Tower Defense (Corrected)"  -- The text that appears in the window's title bar
    t.window.width = 1024                   -- Initial width of the game window in pixels (e.g., 32 columns * 32px/col)
    t.window.height = 768                   -- Initial height of the game window in pixels (e.g., 24 rows * 32px/row)
    t.window.resizable = false              -- Set to true if you want the user to be able to resize the window
    t.window.vsync = 1                      -- 1 enables VSync (recommended), 0 disables it.

    -- Modules (Ensuring necessary modules are enabled - these are defaults anyway)
    -- This section isn't strictly needed unless you want to disable unused modules,
    -- but we ensure 'window' is definitely considered enabled here.
    t.modules.window = true    -- Make sure window module is enabled
    t.modules.graphics = true  -- Need graphics
    t.modules.timer = true     -- Need timer for dt
    t.modules.keyboard = true  -- Might need later
    t.modules.mouse = true     -- Need mouse for input
    t.modules.event = true     -- Needed for callbacks
    t.modules.math = true      -- Good to have

    -- Console (Useful for seeing 'print' output on Windows)
    t.console = true                      -- Show the output console alongside the game window on Windows.
end
