print("--- main.lua started reading ---")

--[[------------------------------------------------------------
     Basic 2D Tower Defense (LÖVE) - Single File Version
     Handles initialization in love.load, basic game loops,
     and draws tower image.
---------------------------------------------------------------]]

-- Global variables for game state and configuration
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

-- Static game data
towerData = {
  { name = "Basic Tower", cost = 50, range = 120, damage = 8, fireRate = 0.7 } -- Fixed damage format (integer)
}
enemyData = {
  { name = "Basic Enemy", speed = 60, health = 30, value = 10 }
}
projectileSpeed = 300 -- Pixels per second for projectiles

-- Global table to hold loaded assets
_G.LoadedAssets = _G.LoadedAssets or {}

-- =========================================================================
-- LÖVE Callbacks
-- =========================================================================

function love.load()
    print("--- love.load started ---")

    local current_w, current_h -- Declare variables outside the pcall scope

    -- *** More Detailed Window Check ***
    if love.window then
        print("Step 1: love.window EXISTS.")
        if type(love.window.getDimensions) == "function" then
             print("Step 2: love.window.getDimensions is a function.")
             print("Step 3: Attempting pcall(love.window.getDimensions)...")
             local success, w, h = pcall(love.window.getDimensions)
             if success then
                 print("Step 4: pcall SUCCESS calling getDimensions.")
                 current_w, current_h = w, h
                 print("Window dimensions from pcall:", current_w, "x", current_h)
                 gridWidth = math.floor(current_w / gridSize)
                 gridHeight = math.floor(current_h / gridSize)
                 print("Calculated Grid dimensions:", gridWidth, "x", gridHeight)
             else
                 print("Step 4: pcall FAILED calling getDimensions! Error:", w)
                 gridWidth = 32; gridHeight = 24
                 print("Using fallback Grid dimensions:", gridWidth, "x", gridHeight)
             end
        else
             print("Step 2: ERROR - love.window.getDimensions is NOT a function! Type:", type(love.window.getDimensions))
             gridWidth = 32; gridHeight = 24
             print("Using fallback Grid dimensions:", gridWidth, "x", gridHeight)
        end
    else
         print("Step 1: ERROR - love.window is NIL inside love.load!")
         gridWidth = 32; gridHeight = 24
         print("Using fallback Grid dimensions:", gridWidth, "x", gridHeight)
    end

    -- Create font AFTER window checks
    print("Step 5: Attempting to create font...")
    font = love.graphics.newFont(16)
    if font then print("Font created successfully.") else print("ERROR: Failed to load font!") end

    -- *** Load Assets ***
    print("Loading assets...")
    -- Ensure the path is correct relative to your main.lua file
    local imagePath = "assets/images/buildings/basic_tower.png"
    _G.LoadedAssets.towerImageBasic = love.graphics.newImage(imagePath) -- Load the image
    if not _G.LoadedAssets.towerImageBasic then
        print("ERROR: Failed to load " .. imagePath .. "! Check path and file.")
    else
        print("Loaded " .. imagePath .." successfully.")
    end
    print("Assets loading finished.")

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
       pathY = math.max(1, math.min(gridHeight, pathY))
       if grid[pathY] then
           for x = 1, gridWidth do
               if grid[pathY][x] ~= nil then grid[pathY][x] = 1 end
           end
           print("Path created on row " .. pathY)
       else print("Warning: Calculated path Y ["..pathY.."] is out of grid bounds during grid setup.") end
       print("Grid initialized.")
    else print("ERROR: Cannot initialize grid due to invalid dimensions (" .. tostring(gridWidth) .. "x" .. tostring(gridHeight) .. ").") end

     print("--- love.load finished ---")
end -- End of love.load

function love.update(dt)
  if not gridWidth or gridWidth <= 0 then return end -- Grid check

  -- 1. Spawning Logic -- (Same as before)
  timeSinceLastSpawn = timeSinceLastSpawn + dt
  if timeSinceLastSpawn >= spawnInterval then
      local pathY = math.floor(gridHeight / 2); pathY = math.max(1, math.min(gridHeight, pathY))
      local spawnPixelY = (pathY - 1) * gridSize + gridSize / 2
      local enemyType = enemyData[1]
      local newEnemy = { x = -gridSize, y = spawnPixelY, pathIndex = 1, data = enemyType, health = enemyType.health, maxHealth = enemyType.health }
      table.insert(enemies, newEnemy)
      timeSinceLastSpawn = 0
      -- print("Spawned enemy at Y:", spawnPixelY) -- Reduce print frequency
  end

  -- 2. Enemy Movement -- (Same as before)
  local pathY = math.floor(gridHeight / 2); pathY = math.max(1, math.min(gridHeight, pathY))
  for i = #enemies, 1, -1 do
    local enemy = enemies[i]
    local targetX = (enemy.pathIndex - 1) * gridSize + gridSize / 2
    local targetY = (pathY - 1) * gridSize + gridSize / 2
    local dx = targetX - enemy.x; local dy = targetY - enemy.y
    local distSq = dx*dx + dy*dy; local moveDist = enemy.data.speed * dt
    if distSq > moveDist * moveDist and distSq > 0.1 then
         local dist = math.sqrt(distSq); local normX = dx / dist; local normY = dy / dist
         enemy.x = enemy.x + normX * moveDist; enemy.y = enemy.y + normY * moveDist
    else
         enemy.x = targetX; enemy.y = targetY
         enemy.pathIndex = enemy.pathIndex + 1
         if enemy.pathIndex > gridWidth then
             print("Enemy reached end"); table.remove(enemies, i) -- TODO: Lose life
         end
    end
  end

  -- 3. Tower Attack Logic -- (Same as before)
  for i, tower in ipairs(towers) do
      tower.cooldown = (tower.cooldown or 0) - dt
      if tower.cooldown <= 0 then
          local targetAcquired = nil; local closestDistSq = tower.data.range * tower.data.range
          for j, enemy in ipairs(enemies) do
              local dx = tower.x - enemy.x; local dy = tower.y - enemy.y; local distSq = dx*dx + dy*dy
              if distSq <= closestDistSq then closestDistSq = distSq; targetAcquired = enemy end
          end
          if targetAcquired then
              local projectile = { x = tower.x, y = tower.y, target = targetAcquired, damage = tower.data.damage, speed = projectileSpeed }
              table.insert(projectiles, projectile)
              tower.cooldown = 1 / tower.data.fireRate
          end
      end
  end

  -- 4. Projectile Movement & Collision -- (Same as before, including enemy removal on death)
  for i = #projectiles, 1, -1 do
    local proj = projectiles[i]
    local targetIsValid = false
    if proj.target and proj.target.health and proj.target.health > 0 then
        for _, activeEnemy in ipairs(enemies) do if activeEnemy == proj.target then targetIsValid = true; break end end
    end
    if not targetIsValid then table.remove(projectiles, i)
    else
        local dx = proj.target.x - proj.x; local dy = proj.target.y - proj.y; local distSq = dx*dx + dy*dy
        local moveDist = proj.speed * dt
        if distSq > moveDist * moveDist and distSq > 0.1 then
             local dist = math.sqrt(distSq); local normX = dx / dist; local normY = dy / dist
             proj.x = proj.x + normX * moveDist; proj.y = proj.y + normY * moveDist
        else
             proj.target.health = proj.target.health - proj.damage
             -- print("Enemy health:", proj.target.health) -- Reduce print frequency
             if proj.target.health <= 0 then
                 money = money + proj.target.data.value; print("Enemy died! Money:", money)
                 for j = #enemies, 1, -1 do if enemies[j] == proj.target then table.remove(enemies, j); break end end
             end
             table.remove(projectiles, i)
        end
    end
  end

end -- End of love.update

function love.draw()
  if not gridWidth or gridWidth <= 0 then -- Grid check
      if font then love.graphics.setFont(font); love.graphics.setColor(1,0,0); love.graphics.print("ERROR: Grid failed to initialize!", 10, 10) end
      return
  end

  -- 1. Draw Grid and Path -- (Same as before)
  for y = 1, gridHeight do
    for x = 1, gridWidth do
      if grid[y] and grid[y][x] then
          if grid[y][x] == 1 then love.graphics.setColor(0.6, 0.6, 0.6) -- Path
          else love.graphics.setColor(0.2, 0.8, 0.2) end -- Grass
          love.graphics.rectangle("fill", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
      end
      love.graphics.setColor(0, 0, 0, 0.2) -- Grid lines
      love.graphics.rectangle("line", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
    end
  end

  -- *** 2. Draw Towers (Modified) *** --------------------------------------
  for _, tower in ipairs(towers) do
      if tower.image then
          -- Draw the loaded image
          love.graphics.setColor(1, 1, 1) -- Use white color for no tint
          love.graphics.draw(
              tower.image,    -- The Image object stored on the tower
              tower.x,        -- Tower's center X
              tower.y,        -- Tower's center Y
              0,              -- Rotation
              1,              -- Scale X
              1,              -- Scale Y
              tower.offsetX,  -- Image horizontal offset (calculated on creation)
              tower.offsetY   -- Image vertical offset (calculated on creation)
          )
      else
          -- Fallback: Draw a rectangle if image is missing
          love.graphics.setColor(0.3, 0.3, 1) -- Blueish
          local fallbackSize = gridSize * 0.8
          love.graphics.rectangle("fill", tower.x - fallbackSize/2, tower.y - fallbackSize/2, fallbackSize, fallbackSize)
          if font then love.graphics.print("!", tower.x - 4, tower.y - 8) end -- Indicate missing image
      end
       -- Optional: Draw tower range when placing or selected? (Could add later)
       -- love.graphics.setColor(1, 1, 1, 0.1) -- Faint white circle
       -- love.graphics.circle("line", tower.x, tower.y, tower.data.range)
  end

  -- 3. Draw Enemies -- (Same as before)
  love.graphics.setColor(1, 0, 0) -- Red for enemies
  for _, enemy in ipairs(enemies) do
    love.graphics.circle("fill", enemy.x, enemy.y, gridSize * 0.3)
    if enemy.health < enemy.maxHealth then -- Health bar
        local barWidth = gridSize*0.6; local barHeight = 5; local barX = enemy.x - barWidth/2; local barY = enemy.y - gridSize*0.5
        local healthRatio = math.max(0, enemy.health / enemy.maxHealth)
        love.graphics.setColor(0.8, 0, 0); love.graphics.rectangle("fill", barX, barY, barWidth, barHeight) -- Background
        love.graphics.setColor(0, 0.8, 0); love.graphics.rectangle("fill", barX, barY, barWidth * healthRatio, barHeight) -- Foreground
    end
  end

  -- 4. Draw Projectiles -- (Same as before)
  love.graphics.setColor(1, 1, 0) -- Yellow for projectiles
  for _, projectile in ipairs(projectiles) do
    love.graphics.circle("fill", projectile.x, projectile.y, 4)
  end

  -- 5. Draw UI -- (Same as before)
  if font then
      love.graphics.setFont(font); love.graphics.setColor(1, 1, 1)
      love.graphics.print("Money: " .. money, 10, 10)
      love.graphics.print("Wave: " .. wave, 10, 30)
      local buildTower = towerData[1]
      love.graphics.print("Click to build: " .. buildTower.name .. " (Cost: " .. buildTower.cost .. ")", 10, 50)
      -- love.graphics.print("FPS: " .. love.timer.getFPS(), love.graphics.getWidth() - 80, 10) -- Optional FPS
  else love.graphics.setColor(1,0,0); love.graphics.print("Font not loaded!", 10, 10) end

end -- End of love.draw

-- *** love.mousepressed (Modified) ***
function love.mousepressed(x, y, button)
     if button == 1 then -- Left click
        -- Convert pixel coordinates to grid coordinates directly
        local gridX = math.floor(x / gridSize) + 1
        local gridY = math.floor(y / gridSize) + 1

        print("Mouse clicked at grid coords: X="..gridX, "Y="..gridY)

        -- Get tower data directly
        local towerTypeIndex = 1 -- Assuming basic tower is type 1
        local buildData = towerData[towerTypeIndex]
        local towerCost = buildData.cost

        -- Perform checks directly
        local buildable = false
        if gridY >= 1 and gridY <= gridHeight and gridX >= 1 and gridX <= gridWidth then -- Check bounds
             if grid[gridY] and grid[gridY][gridX] == 0 then -- Check if cell exists and is empty (0)
                 buildable = true
             elseif grid[gridY] and grid[gridY][gridX] == 1 then
                 print("Cannot build on the path.")
             elseif grid[gridY] and grid[gridY][gridX] == 2 then
                 print("Cell already occupied by a tower.")
             end
        else
             print("Clicked outside grid bounds.")
        end

        -- If buildable and enough money
        if buildable and money >= towerCost then
            -- Calculate center of the grid cell for tower position
            local towerXCenter = (gridX - 1) * gridSize + gridSize / 2
            local towerYCenter = (gridY - 1) * gridSize + gridSize / 2

            -- Get the loaded image object
            local towerImage = _G.LoadedAssets.towerImageBasic -- Assuming this key matches the loaded asset

            -- Create the new tower table with image info
            local newTower = {
               x = towerXCenter,
               y = towerYCenter,
               data = buildData, -- Reference the static tower data
               typeIndex = towerTypeIndex,
               cooldown = 0, -- Start ready to fire
               image = towerImage, -- Store the LÖVE Image object
               -- Store dimensions and offsets needed for drawing
               imgWidth = towerImage and towerImage:getWidth() or (gridSize * 0.8), -- Use image width or fallback
               imgHeight = towerImage and towerImage:getHeight() or (gridSize * 0.8), -- Use image height or fallback
            }
            -- Calculate offsets (center point relative to top-left of image)
            newTower.offsetX = newTower.imgWidth / 2
            newTower.offsetY = newTower.imgHeight / 2

            -- Add tower to list, update grid, spend money
            table.insert(towers, newTower)
            grid[gridY][gridX] = 2 -- Mark cell as occupied by tower
            money = money - towerCost -- Deduct cost
            print("Placed tower at", gridX, gridY, ". Money left:", money)

        elseif buildable and money < towerCost then
             print("Not enough money. Need", towerCost, "have", money)
        end
     end -- End if button == 1
end -- End of love.mousepressed


print("--- main.lua finished reading ---")
