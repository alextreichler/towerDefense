print("--- main.lua started reading ---")

--[[------------------------------------------------------------
     Basic 2D Tower Defense (LÖVE) - Corrected Code
     Handles initialization in love.load, basic game loops.
---------------------------------------------------------------]]

-- Global variables for game state and configuration
-- Initialize globals that don't depend on LÖVE modules here
gridSize = 32       -- Size of each grid cell in pixels
gridWidth = nil     -- To be calculated in love.load based on window size
gridHeight = nil    -- To be calculated in love.load based on window size
grid = {}           -- The game board grid (0=empty, 1=path, 2=tower)
enemies = {}        -- Table to hold active enemies
towers = {}         -- Table to hold placed towers
projectiles = {}    -- Table to hold active projectiles
money = 150         -- Starting money
wave = 1            -- Current wave number
timeSinceLastSpawn = 0 -- Timer for enemy spawning
spawnInterval = 2   -- Seconds between enemy spawns
font = nil          -- Font resource, created in love.load

-- Static game data (can be defined globally)
towerData = {
  { name = "Basic Tower", cost = 50, range = 120, damage = 08, fireRate = 0.5 } -- Added fireRate
}
enemyData = {
  { name = "Basic Enemy", speed = 60, health = 30, value = 10 }
}
projectileSpeed = 300 -- Pixels per second for projectiles


-- =========================================================================
-- LÖVE Callbacks
-- =========================================================================

-- love.load: Called once at the start of the game for setup.
function love.load()
    print("--- love.load started ---")

    local current_w, current_h -- Declare variables outside the pcall scope

    -- *** More Detailed Window Check ***
    if love.window then
        print("Step 1: love.window EXISTS.")
        -- Check if getDimensions itself exists and is a function
        if type(love.window.getDimensions) == "function" then
             print("Step 2: love.window.getDimensions is a function.")
             -- Try calling it safely using pcall
             -- pcall returns: success_status, result1, result2, ... (or error message)
             print("Step 3: Attempting pcall(love.window.getDimensions)...")
             local success, w, h = pcall(love.window.getDimensions)
             if success then
                 print("Step 4: pcall SUCCESS calling getDimensions.")
                 current_w, current_h = w, h -- Assign results from the protected call
                 print("Window dimensions from pcall:", current_w, "x", current_h)
                 -- Proceed with calculations only if successful
                 gridWidth = math.floor(current_w / gridSize)
                 gridHeight = math.floor(current_h / gridSize)
                 print("Calculated Grid dimensions:", gridWidth, "x", gridHeight)
             else
                 -- If pcall failed, 'w' will contain the error message
                 print("Step 4: pcall FAILED calling getDimensions! Error:", w)
                 -- Fallback dimensions needed
                 gridWidth = 32; gridHeight = 24
                 print("Using fallback Grid dimensions:", gridWidth, "x", gridHeight)
             end
        else
             print("Step 2: ERROR - love.window.getDimensions is NOT a function! Type:", type(love.window.getDimensions))
             -- Fallback dimensions needed
             gridWidth = 32; gridHeight = 24
             print("Using fallback Grid dimensions:", gridWidth, "x", gridHeight)
        end
    else
         print("Step 1: ERROR - love.window is NIL inside love.load!")
         -- Fallback dimensions needed
         gridWidth = 32; gridHeight = 24
         print("Using fallback Grid dimensions:", gridWidth, "x", gridHeight)
    end

    -- Create font AFTER window checks
    print("Step 5: Attempting to create font...")
    font = love.graphics.newFont(16)
    if font then
       print("Font created successfully.")
    else
       print("ERROR: Failed to load font!")
    end

    -- Initialize the grid table structure (only if dimensions are valid)
    print("Step 6: Checking grid dimensions before grid init...")
    if gridWidth and gridHeight and gridWidth > 0 and gridHeight > 0 then
       print("Initializing grid...")
       for y = 1, gridHeight do
         grid[y] = {} -- Create row
         for x = 1, gridWidth do
           grid[y][x] = 0 -- Set cell to empty
         end
       end

       -- Define a simple horizontal path in the middle
       local pathY = math.floor(gridHeight / 2)
       pathY = math.max(1, math.min(gridHeight, pathY)) -- Clamp pathY within grid bounds
       if grid[pathY] then
           for x = 1, gridWidth do
               if grid[pathY][x] ~= nil then -- Check cell exists before writing
                  grid[pathY][x] = 1 -- Mark as path
               end
           end
           print("Path created on row " .. pathY)
       else
           print("Warning: Calculated path Y ["..pathY.."] is out of grid bounds during grid setup.")
       end
       print("Grid initialized.")
    else
       print("ERROR: Cannot initialize grid due to invalid dimensions (" .. tostring(gridWidth) .. "x" .. tostring(gridHeight) .. ").")
    end

    -- Initialize tower cooldowns (if needed later)

     print("--- love.load finished ---")
end -- End of love.load
function love.update(dt)
  -- If grid wasn't initialized, don't run game logic
  if not gridWidth or gridWidth <= 0 then return end

  -- 1. Spawning Logic ----------------------------------------------------
  timeSinceLastSpawn = timeSinceLastSpawn + dt
  if timeSinceLastSpawn >= spawnInterval then
    local pathY = math.floor(gridHeight / 2)
    pathY = math.max(1, math.min(gridHeight, pathY))
    local spawnPixelY = (pathY - 1) * gridSize + gridSize / 2 -- Center of the path row

    local enemyType = enemyData[1] -- Get first enemy type for now
    local newEnemy = {
      x = -gridSize, -- Start off-screen left
      y = spawnPixelY,
      pathIndex = 1, -- Target the center of the first cell (index 1)
      data = enemyType,
      health = enemyType.health,
      maxHealth = enemyType.health -- Store max health for drawing health bar
    }
    table.insert(enemies, newEnemy)
    timeSinceLastSpawn = 0 -- Reset timer
    print("Spawned enemy at Y:", spawnPixelY)
  end

  -- 2. Enemy Movement -----------------------------------------------------
  local pathY = math.floor(gridHeight / 2) -- Path row index
  pathY = math.max(1, math.min(gridHeight, pathY))

  for i = #enemies, 1, -1 do -- Iterate backwards for safe removal
    local enemy = enemies[i]

    -- Calculate target position (center of the cell at enemy.pathIndex)
    local targetX = (enemy.pathIndex - 1) * gridSize + gridSize / 2
    local targetY = (pathY - 1) * gridSize + gridSize / 2

    -- Calculate vector and distance to target
    local dx = targetX - enemy.x
    local dy = targetY - enemy.y
    local distSq = dx*dx + dy*dy -- Use squared distance for comparison
    local moveDist = enemy.data.speed * dt

    if distSq > moveDist * moveDist and distSq > 0.1 then -- If not close enough and dist > 0
         local dist = math.sqrt(distSq)
         local normX = dx / dist
         local normY = dy / dist
         enemy.x = enemy.x + normX * moveDist
         enemy.y = enemy.y + normY * moveDist
    else -- Close enough or reached target
         enemy.x = targetX -- Snap to target
         enemy.y = targetY
         enemy.pathIndex = enemy.pathIndex + 1 -- Advance to next path cell index

         -- Check if enemy reached the end
         if enemy.pathIndex > gridWidth then
             print("Enemy reached end")
             -- TODO: Handle player losing a life here
             table.remove(enemies, i) -- Remove enemy
         end
    end
  end

  -- 3. Tower Attack Logic -------------------------------------------------
  for i, tower in ipairs(towers) do
      -- Cooldown timer logic
      tower.cooldown = (tower.cooldown or 0) - dt

      if tower.cooldown <= 0 then
          local targetAcquired = nil
          local closestDistSq = tower.data.range * tower.data.range -- Use squared range

          -- Find the closest valid enemy in range
          for j, enemy in ipairs(enemies) do
              local dx = tower.x - enemy.x
              local dy = tower.y - enemy.y
              local distSq = dx*dx + dy*dy
              if distSq <= closestDistSq then
                  closestDistSq = distSq
                  targetAcquired = enemy -- Target the closest one
              end
          end

          -- If a target was found, fire a projectile
          if targetAcquired then
              local projectile = {
                x = tower.x,
                y = tower.y,
                target = targetAcquired, -- Reference to the enemy object
                damage = tower.data.damage,
                speed = projectileSpeed
              }
              table.insert(projectiles, projectile)
              tower.cooldown = 1 / tower.data.fireRate -- Reset cooldown based on fire rate
              -- print("Tower fired at enemy!") -- Optional debug print
          end
      end
  end

  -- 4. Projectile Movement & Collision ------------------------------------
  for i = #projectiles, 1, -1 do -- Iterate backwards for safe removal
    local proj = projectiles[i]

    -- Check if target still exists and is valid
    local targetIsValid = false
    if proj.target and proj.target.health and proj.target.health > 0 then
        -- Check if target is still in the 'enemies' table (might have been removed)
        for _, activeEnemy in ipairs(enemies) do
            if activeEnemy == proj.target then
                targetIsValid = true
                break
            end
        end
    end

    if not targetIsValid then
        table.remove(projectiles, i) -- Remove projectile if target is gone or dead
    else
        -- Move towards target
        local dx = proj.target.x - proj.x
        local dy = proj.target.y - proj.y
        local distSq = dx*dx + dy*dy
        local moveDist = proj.speed * dt

        if distSq > moveDist * moveDist and distSq > 0.1 then
             local dist = math.sqrt(distSq)
             local normX = dx / dist
             local normY = dy / dist
             proj.x = proj.x + normX * moveDist
             proj.y = proj.y + normY * moveDist
        else -- Reached target or close enough
             -- Deal damage
             proj.target.health = proj.target.health - proj.damage
             print("Enemy health:", proj.target.health)

             -- Check if enemy died
             if proj.target.health <= 0 then
                 money = money + proj.target.data.value -- Award money
                 print("Enemy died! Money:", money)
                 -- Find and remove the dead enemy (need to iterate again, or mark for removal)
                 for j = #enemies, 1, -1 do
                     if enemies[j] == proj.target then
                         table.remove(enemies, j)
                         break -- Assume only one instance
                     end
                 end
             end
             table.remove(projectiles, i) -- Remove projectile after hitting
        end
    end
  end

end -- End of love.update

-- love.draw: Called repeatedly to draw everything to the screen.
function love.draw()
  -- If grid wasn't initialized, draw error message
  if not gridWidth or gridWidth <= 0 then
      if font then love.graphics.setFont(font) end
      love.graphics.setColor(1,0,0)
      love.graphics.print("ERROR: Grid failed to initialize!", 10, 10)
      return
  end

  -- 1. Draw Grid and Path -----------------------------------------------
  for y = 1, gridHeight do
    for x = 1, gridWidth do
      if grid[y] and grid[y][x] then -- Check if cell exists
          if grid[y][x] == 1 then -- Path tile
            love.graphics.setColor(0.6, 0.6, 0.6) -- Grey for path
          else -- Empty or Tower tile (draw background)
             love.graphics.setColor(0.2, 0.8, 0.2) -- Green for grass
          end
          love.graphics.rectangle("fill", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
      end
      -- Optional: Draw grid lines
      love.graphics.setColor(0, 0, 0, 0.2) -- Faint black lines
      love.graphics.rectangle("line", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
    end
  end

  -- 2. Draw Towers -------------------------------------------------------
  love.graphics.setColor(0.3, 0.3, 1) -- Blueish for towers
  for _, tower in ipairs(towers) do
    -- Draw base
    love.graphics.rectangle("fill", tower.x - gridSize * 0.4, tower.y - gridSize * 0.4, gridSize * 0.8, gridSize * 0.8)
     -- Optional: Draw tower range when placing or selected? (Could add later)
     -- love.graphics.setColor(1, 1, 1, 0.1) -- Faint white circle
     -- love.graphics.circle("line", tower.x, tower.y, tower.data.range)
  end

  -- 3. Draw Enemies ------------------------------------------------------
  love.graphics.setColor(1, 0, 0) -- Red for enemies
  for _, enemy in ipairs(enemies) do
    -- Draw body
    love.graphics.circle("fill", enemy.x, enemy.y, gridSize * 0.3)
    -- Draw health bar
    if enemy.health < enemy.maxHealth then
        local barWidth = gridSize * 0.6
        local barHeight = 5
        local barX = enemy.x - barWidth / 2
        local barY = enemy.y - gridSize * 0.5
        local healthRatio = math.max(0, enemy.health / enemy.maxHealth)
        -- Background (red)
        love.graphics.setColor(0.8, 0, 0)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        -- Foreground (green)
        love.graphics.setColor(0, 0.8, 0)
        love.graphics.rectangle("fill", barX, barY, barWidth * healthRatio, barHeight)
    end
  end

  -- 4. Draw Projectiles -------------------------------------------------
  love.graphics.setColor(1, 1, 0) -- Yellow for projectiles
  for _, projectile in ipairs(projectiles) do
    love.graphics.circle("fill", projectile.x, projectile.y, 4)
  end

  -- 5. Draw UI ----------------------------------------------------------
  if font then
      love.graphics.setFont(font)
      love.graphics.setColor(1, 1, 1) -- White for UI text
      love.graphics.print("Money: " .. money, 10, 10)
      love.graphics.print("Wave: " .. wave, 10, 30)
      -- Display simple tower info for placement
      local buildTower = towerData[1]
      love.graphics.print("Click to build: " .. buildTower.name .. " (Cost: " .. buildTower.cost .. ")", 10, 50)

      -- Optional: Display FPS
      -- love.graphics.print("FPS: " .. love.timer.getFPS(), love.graphics.getWidth() - 80, 10)
  else
      love.graphics.setColor(1,0,0)
      love.graphics.print("Font not loaded!", 10, 10)
  end

end -- End of love.draw

-- love.mousepressed: Called when a mouse button is pressed.
function love.mousepressed(x, y, button)
  if button == 1 then -- Left click
    -- Convert pixel coordinates to grid coordinates
    local gridX = math.floor(x / gridSize) + 1
    local gridY = math.floor(y / gridSize) + 1

    print("Mouse clicked at grid coords: X="..gridX, "Y="..gridY)

    -- Check if click is within grid bounds
    if gridY >= 1 and gridY <= gridHeight and gridX >= 1 and gridX <= gridWidth then
        -- Check if cell is valid for building (not path and not already tower)
        if grid[gridY] and grid[gridY][gridX] == 0 then
            local towerToBuild = towerData[1] -- Select first tower type for now
            -- Check if enough money
            if money >= towerToBuild.cost then
                 -- Calculate center of the grid cell for tower position
                 local towerXCenter = (gridX - 1) * gridSize + gridSize / 2
                 local towerYCenter = (gridY - 1) * gridSize + gridSize / 2

                 -- Create and place the tower
                 local newTower = {
                   x = towerXCenter,
                   y = towerYCenter,
                   data = towerToBuild,
                   cooldown = 0 -- Start ready to fire
                 }
                 table.insert(towers, newTower)
                 grid[gridY][gridX] = 2 -- Mark cell as occupied by tower
                 money = money - towerToBuild.cost -- Deduct cost
                 print("Placed tower at", gridX, gridY, ". Money left:", money)
            else
                 print("Not enough money. Need", towerToBuild.cost, "have", money)
            end
        elseif grid[gridY] and grid[gridY][gridX] == 1 then
             print("Cannot build on the path.")
        elseif grid[gridY] and grid[gridY][gridX] == 2 then
             print("Cell already occupied by a tower.")
        else
             print("Clicked on invalid grid cell state:", grid[gridY] and grid[gridY][x])
        end
    else
        print("Clicked outside grid bounds.")
    end
  end -- End if button == 1
end -- End of love.mousepressed


print("--- main.lua finished reading ---")
