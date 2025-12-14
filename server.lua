-- Drone Taxi Server
-- Flow: pickup player -> go home -> teleport to dest (unless dest=home) -> drop off

local CHANNEL_FILE = ".taxi_channel"
local CHUNK_SIZE = 16
local SAVE_FILE = ".taxi_server"
local CACHE_FILE = ".taxi_cache"
local MIN_PRESSURE = 1.0
local ACTION_TIMEOUT = 30
local PICKUP_TIMEOUT = 90   -- Longer for slow entity ticks
local IMPORT_TIMEOUT = 45   -- Increased for slow entity ticks
local HOME_TIMEOUT = 45     -- Increased for slow entity ticks

local discoveryCount = 0
local orderCount = 0

local drone, modem, CHANNEL
local SERVER_ID, DIMENSION, HOME_X, HOME_Y, HOME_Z
local hasPressureAPI = false

local function parseF3C(input)
    local dim = input:match("in ([%w_:-]+) run")
    local x, y, z = input:match("@s ([%-%.%d]+) ([%-%.%d]+) ([%-%.%d]+)")
    if x and y and z then
        return dim, math.floor(tonumber(x)), math.floor(tonumber(y)), math.floor(tonumber(z))
    end
    return dim, nil, nil, nil
end

local function saveConfig(id, dim, hx, hy, hz)
    local f = fs.open(SAVE_FILE, "w")
    f.write(id .. "\n" .. dim .. "\n" .. hx .. "," .. hy .. "," .. hz)
    f.close()
end

local function loadConfig()
    if not fs.exists(SAVE_FILE) then
        return nil, nil, nil, nil, nil
    end
    local f = fs.open(SAVE_FILE, "r")
    local id = f.readLine()
    local dim = f.readLine()
    local homeStr = f.readLine()
    f.close()
    
    local hx, hy, hz = nil, nil, nil
    if homeStr then
        hx, hy, hz = homeStr:match("([%-%.%d]+),([%-%.%d]+),([%-%.%d]+)")
        if hx then
            hx, hy, hz = tonumber(hx), tonumber(hy), tonumber(hz)
        end
    end
    
    return tonumber(id), dim, hx, hy, hz
end

local function saveCache(destX, destY, destZ, radius, ring, dirIdx)
    local f = fs.open(CACHE_FILE, "w")
    f.write(textutils.serialize({
        dest = {x = destX, y = destY, z = destZ},
        radius = radius,
        ring = ring,
        dirIdx = dirIdx
    }))
    f.close()
end

local function loadCache()
    if not fs.exists(CACHE_FILE) then
        return nil
    end
    local f = fs.open(CACHE_FILE, "r")
    local data = f.readAll()
    f.close()
    return textutils.unserialize(data)
end

local function clearCache()
    if fs.exists(CACHE_FILE) then
        fs.delete(CACHE_FILE)
    end
end

local function checkDrone()
    if not drone.isConnectedToDrone() then
        print("    !!! DRONE DISCONNECTED !!!")
        return false
    end
    return true
end

local function getPressure()
    if hasPressureAPI and checkDrone() then
        return drone.getDronePressure()
    end
    return nil
end

local function sendStatus(token, message)
    modem.transmit(CHANNEL, CHANNEL, {
        type = "taxi_status",
        token = token,
        message = message
    })
end

local function sendError(token, message)
    modem.transmit(CHANNEL, CHANNEL, {
        type = "taxi_error",
        token = token,
        error = message
    })
end

local function waitForAction(actionName, timeout)
    timeout = timeout or ACTION_TIMEOUT
    local startTime = os.clock()
    local lastDot = 0
    
    while true do
        if not checkDrone() then
            return false, "disconnected"
        end
        
        if drone.isActionDone() then
            return true, nil
        end
        
        sleep(0.1)
        local elapsed = os.clock() - startTime
        
        if math.floor(elapsed / 5) > lastDot then
            lastDot = math.floor(elapsed / 5)
            write(".")
        end
        
        if elapsed > timeout then
            print("")
            print("    TIMEOUT: " .. actionName)
            return false, "timeout"
        end
    end
end

local function goHome()
    print("    exitPiece...")
    drone.abortAction()
    drone.exitPiece()
    sleep(2)
    
    local waitStart = os.clock()
    while not drone.isConnectedToDrone() do
        sleep(0.5)
        if os.clock() - waitStart > HOME_TIMEOUT then
            print("    Reconnect timeout!")
            return false
        end
    end
    sleep(1)
    print("    Home")
    return true
end

local function teleportTo(x, y, z, timeout)
    if not checkDrone() then return false, "disconnected" end
    
    print("    teleport " .. x .. "," .. y .. "," .. z)
    
    drone.clearArea()
    drone.addArea(x, y, z)
    drone.setAction("teleport")
    
    local ok, err = waitForAction("teleport", timeout)
    if ok then drone.abortAction() end
    return ok, err
end

local function teleportToArea(x1, y1, z1, x2, y2, z2, timeout)
    if not checkDrone() then return false, "disconnected" end
    
    print("    teleport area")
    
    drone.clearArea()
    drone.addArea(x1, y1, z1, x2, y2, z2, "filled")
    drone.setAction("teleport")
    
    local ok, err = waitForAction("teleport", timeout)
    if ok then drone.abortAction() end
    return ok, err
end

local function importEntity()
    if not checkDrone() then return false, "disconnected" end
    print("    entity_import...")
    drone.setAction("entity_import")
    return waitForAction("entity_import", IMPORT_TIMEOUT)
end

local function exportEntity()
    if not checkDrone() then return false, "disconnected" end
    print("    dropping player...")
    drone.abortAction()
    sleep(1)
    return true
end

local function isHome(x, y, z)
    return math.floor(x) == math.floor(HOME_X) and math.floor(y) == math.floor(HOME_Y) and math.floor(z) == math.floor(HOME_Z)
end

-- Initialize
print("=== Drone Taxi Server ===")
print("")
print("Reset: rm " .. CHANNEL_FILE .. " " .. SAVE_FILE)
print("")

-- Load or ask for channel
if fs.exists(CHANNEL_FILE) then
    local f = fs.open(CHANNEL_FILE, "r")
    CHANNEL = tonumber(f.readAll())
    f.close()
end

if not CHANNEL then
    print("Enter channel (0-65535):")
    print("(make it unique)")
    local input = read()
    CHANNEL = tonumber(input)
    if not CHANNEL or CHANNEL < 0 or CHANNEL > 65535 then
        printError("Invalid channel")
        return
    end
    local f = fs.open(CHANNEL_FILE, "w")
    f.write(tostring(CHANNEL))
    f.close()
    print("Channel saved!")
    print("")
end

SERVER_ID, DIMENSION, HOME_X, HOME_Y, HOME_Z = loadConfig()

if not SERVER_ID then
    SERVER_ID = math.random(10000, 65535)
end

print("ID: " .. SERVER_ID)
print("")

if DIMENSION and HOME_X then
    print("Dimension: " .. DIMENSION)
    print("Home: " .. HOME_X .. ", " .. HOME_Y .. ", " .. HOME_Z)
    print("")
    print("Enter to continue, or F3+C to change:")
    local input = read()
    if input ~= "" then
        local newDim, nx, ny, nz = parseF3C(input)
        if newDim and nx then
            DIMENSION = newDim
            HOME_X, HOME_Y, HOME_Z = nx, ny, nz
            saveConfig(SERVER_ID, DIMENSION, HOME_X, HOME_Y, HOME_Z)
            print("Updated!")
        end
    end
else
    print("Paste F3+C at charging station:")
    local input = read()
    local dim, hx, hy, hz = parseF3C(input)
    
    if not dim or not hx then
        printError("Couldn't parse F3+C!")
        return
    end
    
    DIMENSION = dim
    HOME_X, HOME_Y, HOME_Z = hx, hy, hz
    saveConfig(SERVER_ID, DIMENSION, HOME_X, HOME_Y, HOME_Z)
    print("Dimension: " .. DIMENSION)
    print("Home: " .. HOME_X .. ", " .. HOME_Y .. ", " .. HOME_Z)
end

print("")

drone = peripheral.find("drone_interface")
modem = peripheral.find("modem")

if not drone then
    printError("No Drone Interface!")
    return
end

if not modem then
    printError("No modem!")
    return
end

hasPressureAPI = type(drone.getDronePressure) == "function"

local isOnline = drone.isConnectedToDrone()
if isOnline then
    print("Drone: ONLINE")
else
    print("Drone: OFFLINE")
end

modem.open(CHANNEL)
print("")

-- Main loop
while true do
    local event, p1, p2, p3, msg = os.pullEvent("modem_message")
    
    if p2 == CHANNEL and type(msg) == "table" then
        if msg.type == "taxi_discover" then
            discoveryCount = discoveryCount + 1
            isOnline = drone.isConnectedToDrone()
            if isOnline then
                modem.transmit(CHANNEL, CHANNEL, {
                    type = "taxi_server",
                    id = SERVER_ID,
                    dimension = DIMENSION,
                    home = {x = HOME_X, y = HOME_Y, z = HOME_Z}
                })
            end
        
        elseif msg.type == "taxi_request" then
            -- Check drone status
            local wasOnline = isOnline
            isOnline = drone.isConnectedToDrone()
            
            if isOnline and not wasOnline then
                print("[" .. SERVER_ID .. "] ONLINE")
            elseif not isOnline and wasOnline then
                print("[" .. SERVER_ID .. "] OFFLINE")
            end
            
            if not isOnline then
                -- Silently ignore request
            elseif msg.dimension ~= DIMENSION then
                print("[" .. SERVER_ID .. "] Wrong dim: " .. (msg.dimension or "nil"))
            else
                orderCount = orderCount + 1
                local dest = msg.dest
                local pickup = msg.pickup
                local token = msg.token
                local radius = msg.radius or 0
                
                local destIsHome = isHome(dest[1], dest[2], dest[3])
                
                print("")
                print("======== ORDER #" .. orderCount .. " ========")
                print("Pickup: " .. pickup[1] .. "," .. pickup[2] .. "," .. pickup[3])
                print("Dest:   " .. dest[1] .. "," .. dest[2] .. "," .. dest[3] .. (destIsHome and " (HOME)" or ""))
                print("Radius: " .. radius)
                print("")
                
                local pressure = getPressure()
                local pStr = pressure and string.format("%.1f", pressure) or "?"
                
                if pressure and pressure < MIN_PRESSURE then
                    print("NOT ENOUGH PRESSURE! (" .. pStr .. ")")
                    sendError(token, "Low pressure! (" .. pStr .. "/" .. MIN_PRESSURE .. ")")
                else
                    local success = true
                    local ok, err
                    
                    -- STEP 1: Teleport to pickup
                    print("STEP 1: Teleport to pickup")
                    sendStatus(token, "Coming to you...")
                    
                    -- Teleport above player (1.8 blocks)
                    ok, err = teleportTo(pickup[1], pickup[2] + 1.8, pickup[3], PICKUP_TIMEOUT)
                    
                    if not ok then
                        print("FAILED: " .. (err or "unknown"))
                        sendError(token, "Pickup failed!")
                        success = false
                    end
                    
                    -- STEP 2: Pick up player (4 attempts, 2s apart)
                    if success then
                        print("STEP 2: Pick up player")
                        modem.transmit(CHANNEL, CHANNEL, {type = "taxi_pickup", token = token})
                        sendStatus(token, "Board the drone!")
                        
                        local boarded = false
                        for attempt = 1, 4 do
                            print("    Attempt " .. attempt .. "/4...")
                            ok, err = importEntity()
                            if ok then
                                boarded = true
                                print("    Player on board!")
                                break
                            end
                            if attempt < 4 then
                                sleep(2)
                            end
                        end
                        
                        if not boarded then
                            print("FAILED: no player after 4 attempts")
                            sendError(token, "Boarding failed!")
                            success = false
                        end
                    end
                    
                    -- STEP 3: Go home
                    if success then
                        print("STEP 3: Return home")
                        sendStatus(token, "Going to charger...")
                        
                        ok = goHome()
                        if not ok then
                            print("FAILED: return home")
                            sendError(token, "Return home failed!")
                            success = false
                        end
                    end
                    
                    -- STEP 4: Teleport to destination (skip if dest is home)
                    if success and destIsHome then
                        print("STEP 4: Already at home!")
                        print("STEP 5: Drop off")
                        exportEntity()
                        modem.transmit(CHANNEL, CHANNEL, {type = "taxi_complete", token = token})
                        print("DELIVERED!")
                    elseif success then
                        print("STEP 4: Teleport to dest")
                        
                        local foundX, foundY, foundZ = nil, nil, nil
                        local testNum = 0
                        
                        testNum = testNum + 1
                        pressure = getPressure()
                        pStr = pressure and string.format("%.1f", pressure) or "?"
                        
                        if pressure and pressure < MIN_PRESSURE then
                            print("  [" .. testNum .. "] LOW PRESSURE!")
                            sendError(token, "Low pressure!")
                            exportEntity()
                            success = false
                        else
                            print("  [" .. testNum .. "] " .. dest[1] .. "," .. dest[2] .. "," .. dest[3])
                            sendStatus(token, "Test " .. testNum)
                            
                            local startTime = os.clock()
                            ok, err = teleportTo(dest[1], dest[2], dest[3])
                            local elapsed = os.clock() - startTime
                            
                            if not ok then
                                print("    ERROR: " .. (err or "?"))
                                sendError(token, "Teleport error!")
                                exportEntity()
                                success = false
                            elseif elapsed < 1 then
                                print("    " .. string.format("%.1f", elapsed) .. "s = NOT loaded")
                            else
                                print("    " .. string.format("%.1f", elapsed) .. "s = LOADED!")
                                foundX, foundY, foundZ = dest[1], dest[2], dest[3]
                            end
                        end
                        
                        -- Test radius
                        if success and not foundX and radius > 0 then
                            local directions = {
                                {0, -1}, {1, -1}, {1, 0}, {1, 1},
                                {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}
                            }
                            
                            -- Check for cached progress
                            local startRing = 1
                            local startDir = 1
                            local cache = loadCache()
                            if cache and cache.dest.x == dest[1] and cache.dest.y == dest[2] and cache.dest.z == dest[3] then
                                startRing = cache.ring
                                startDir = cache.dirIdx
                                print("    Resuming from R" .. startRing .. " D" .. startDir)
                                clearCache()
                            else
                                clearCache()
                            end
                            
                            for r = startRing, radius do
                                if foundX or not success then break end
                                
                                local offset = r * CHUNK_SIZE
                                local dirStart = (r == startRing) and startDir or 1
                                
                                for d = dirStart, #directions do
                                    if foundX or not success then break end
                                    
                                    local dir = directions[d]
                                    
                                    print("    Home...")
                                    ok = goHome()
                                    if not ok then
                                        success = false
                                        break
                                    end
                                    
                                    testNum = testNum + 1
                                    local testX = dest[1] + (dir[1] * offset)
                                    local testZ = dest[3] + (dir[2] * offset)
                                    
                                    pressure = getPressure()
                                    pStr = pressure and string.format("%.1f", pressure) or "?"
                                    
                                    if pressure and pressure < MIN_PRESSURE then
                                        print("  [" .. testNum .. "] LOW PRESSURE - SAVING")
                                        -- Save progress: next position to test
                                        local nextD = d + 1
                                        local nextR = r
                                        if nextD > #directions then
                                            nextD = 1
                                            nextR = r + 1
                                        end
                                        if nextR <= radius then
                                            saveCache(dest[1], dest[2], dest[3], radius, nextR, nextD)
                                            sendError(token, "Low pressure! Progress saved.")
                                        else
                                            sendError(token, "Low pressure!")
                                        end
                                        exportEntity()
                                        success = false
                                        break
                                    end
                                    
                                    print("  [" .. testNum .. "] " .. testX .. "," .. dest[2] .. "," .. testZ)
                                    sendStatus(token, "Test " .. testNum .. " R" .. r)
                                    
                                    local startTime = os.clock()
                                    ok, err = teleportTo(testX, dest[2], testZ)
                                    local elapsed = os.clock() - startTime
                                    
                                    if not ok then
                                        print("    ERROR: " .. (err or "?"))
                                        success = false
                                        break
                                    elseif elapsed < 1 then
                                        print("    " .. string.format("%.1f", elapsed) .. "s = NOT loaded")
                                    else
                                        print("    " .. string.format("%.1f", elapsed) .. "s = LOADED!")
                                        foundX, foundY, foundZ = testX, dest[2], testZ
                                        clearCache()
                                    end
                                end
                            end
                        end
                        
                        if success and not foundX then
                            print("    No loaded chunk!")
                            sendError(token, "No loaded chunk!")
                            goHome()
                            exportEntity()
                            success = false
                        end
                        
                        -- STEP 5: Drop off
                        if success and foundX then
                            print("STEP 5: Drop off")
                            exportEntity()
                            modem.transmit(CHANNEL, CHANNEL, {type = "taxi_complete", token = token})
                            print("DELIVERED!")
                        end
                    end
                    
                    print("Returning drone...")
                    goHome()
                end
                
                print("======== END ========")
                print("")
            end
        end
    end
end
