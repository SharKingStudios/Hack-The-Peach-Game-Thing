-- Hack the Peach stuff. Dont really know if I have much developing time lol.

-- Hold the current state of the game
local state = {}

-- Load libraries
local CScreen = require("Libraries/cscreen")

-- Define the load function
function love.load()
    -- Load window values
    love.window.setFullscreen(true)

    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setMode(love.graphics.getWidth()/3, love.graphics.getHeight()/3) -- Set to 1920 x 1080 on launch

    love.window.setFullscreen(true)
    -- love.window.setMode(1200, 800)
    

    -- love.window.setMode(2340/2, 1080/2) -- Set to custom w / h for debug
    love.math.setRandomSeed(os.time())

    -- Load scaling
    -- CScreen.init(1920, 1080, true)

    -- Load the menu state
    state.current = require("Scenes/game")
    state.current.load()
end

function love.update(dt) -- Runs every frame.
    -- Update the current state

    -- print("FPS: " .. love.timer.getFPS())

    local nextState = state.current.update(dt)
    if nextState == "startGame" then
        -- Switch to the game scene
        print("Switching to the arcade game scene")
        state.current = require("Scenes/game")
        state.current.load()
    elseif nextState == "mainMenu" then
        -- Switch to the main menu scene
        print("Switching to the main menu scene")
        state.current = require("Scenes/mainMenu")
        state.current.load()
    end
end

function love.draw() -- Draws every frame / Runs directly after love.update()
    
    love.graphics.clear(27/255, 26/255, 50/255)
    -- Set the scaling
    -- CScreen.apply()
    -- Draw the current state
    state.current.draw()
    -- CScreen.cease()
end

function love.keypressed(key)
    if key == "]" then
        local dg = string.format("%s %s $", entity, 'quit')
        udp:send(dg)
    elseif key == "=" then
        love.event.quit()
    end 
end


-- Scaling Function
function love.resize(width, height)
	CScreen.update(width, height)
end