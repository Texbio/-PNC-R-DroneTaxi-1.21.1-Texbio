-- Drone Taxi Client
-- Usage: taxi, taxi me, taxi go <n>, taxi save, taxi rm, taxi list, taxi help

local CHANNEL_FILE = ".taxi_channel"
local SAVE_FILE = ".taxi_pos"
local WAYPOINT_FILE = ".taxi_waypoints"
local TIMEOUT = 300

-- Load or ask for channel
local CHANNEL
if fs.exists(CHANNEL_FILE) then
    local f = fs.open(CHANNEL_FILE, "r")
    CHANNEL = tonumber(f.readAll())
    f.close()
end

if not CHANNEL then
    print("=== Taxi Setup ===")
    print("")
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

local modem = peripheral.find("modem")
if not modem then
    printError("No modem found!")
    return
end
modem.open(CHANNEL)

local RESERVED = {home = true, me = true, save = true, list = true, help = true, go = true, rm = true}

-- Detect pocket computer
local isPocket = pocket ~= nil

-- Test GPS availability (quick 2 second test)
local hasGPS = false
local function testGPS()
    local x, y, z = gps.locate(2)
    return x ~= nil
end

local function getGPSPosition()
    local x, y, z = gps.locate(5)
    if x then
        -- Adjust for pocket computer (modem at chest height)
        if isPocket then
            y = y - 1
        end
        return math.floor(x), math.floor(y), math.floor(z)
    end
    return nil
end

-- Get dimension from server (GPS doesn't provide dimension)
local function getDimensionFromServers(servers)
    -- If only one server, use that dimension
    local dims = {}
    for dim, _ in pairs(servers) do
        table.insert(dims, dim)
    end
    
    if #dims == 1 then
        return dims[1]
    elseif #dims > 1 then
        print("Select dimension:")
        for i, dim in ipairs(dims) do
            print("  " .. (i-1) .. ") " .. dim)
        end
        local sel = tonumber(read())
        if sel and dims[sel + 1] then
            return dims[sel + 1]
        end
    end
    return nil
end

local function parseCoords(input, currentY)
    local function resolveCoord(val, current)
        if val == "~" then
            return current
        end
        return tonumber(val)
    end
    
    local x, y, z = input:match("@s ([%-%.%d]+) ([%-%.%d]+) ([%-%.%d]+)")
    if x and y and z then
        return math.floor(tonumber(x)), math.floor(tonumber(y)), math.floor(tonumber(z))
    end
    
    x, y, z = input:match("([%-%.%d~]+)%s*,%s*([%-%.%d~]+)%s*,%s*([%-%.%d~]+)")
    if not x then
        x, y, z = input:match("([%-%.%d~]+)%s+([%-%.%d~]+)%s+([%-%.%d~]+)")
    end
    
    if x and y and z then
        local nx = resolveCoord(x, nil)
        local ny = resolveCoord(y, currentY)
        local nz = resolveCoord(z, nil)
        
        if nx and ny and nz then
            return math.floor(nx), math.floor(ny), math.floor(nz)
        end
    end
    return nil
end

local function parseF3C(input)
    local dim = input:match("in ([%w_:-]+) run")
    local x, y, z = input:match("@s ([%-%.%d]+) ([%-%.%d]+) ([%-%.%d]+)")
    
    if dim and x and y and z then
        return math.floor(tonumber(x)), math.floor(tonumber(y)), math.floor(tonumber(z)), dim
    end
    return nil
end

local function savePosition(x, y, z, dim)
    local f = fs.open(SAVE_FILE, "w")
    f.write(dim .. "\n" .. x .. "," .. y .. "," .. z)
    f.close()
end

local function loadPosition()
    if not fs.exists(SAVE_FILE) then
        return nil
    end
    local f = fs.open(SAVE_FILE, "r")
    local dim = f.readLine()
    local coords = f.readLine()
    f.close()
    
    if not dim or not coords then
        return nil
    end
    
    local x, y, z = parseCoords(coords, nil)
    if x then
        return x, y, z, dim
    end
    return nil
end

local function loadWaypoints()
    if not fs.exists(WAYPOINT_FILE) then
        return {}
    end
    local f = fs.open(WAYPOINT_FILE, "r")
    local data = f.readAll()
    f.close()
    local loaded = textutils.unserialize(data) or {}
    
    if loaded[1] == nil then
        local migrated = {}
        for name, coords in pairs(loaded) do
            table.insert(migrated, {name = name, x = coords.x, y = coords.y, z = coords.z})
        end
        return migrated
    end
    
    return loaded
end

local function saveWaypoints(waypoints)
    local f = fs.open(WAYPOINT_FILE, "w")
    f.write(textutils.serialize(waypoints))
    f.close()
end

local function findMatchingWaypoints(waypoints, partial)
    partial = partial:lower()
    local matches = {}
    
    for i, wp in ipairs(waypoints) do
        if wp.name:lower():sub(1, #partial) == partial then
            table.insert(matches, {wp = wp, idx = i})
        end
    end
    
    return matches
end

local function selectWaypoint(waypoints, input)
    input = input:lower()
    
    for _, wp in ipairs(waypoints) do
        if wp.name:lower() == input then
            return wp
        end
    end
    
    local matches = findMatchingWaypoints(waypoints, input)
    
    if #matches == 0 then
        return nil
    elseif #matches == 1 then
        return matches[1].wp
    else
        print("Multiple matches:")
        for i, match in ipairs(matches) do
            print("  " .. (i-1) .. ") " .. match.wp.name .. ": " .. match.wp.x .. "," .. match.wp.y .. "," .. match.wp.z)
        end
        print("Select:")
        local sel = tonumber(read())
        if sel and matches[sel + 1] then
            return matches[sel + 1].wp
        end
        return nil
    end
end

local function discoverServers()
    modem.transmit(CHANNEL, CHANNEL, {type = "taxi_discover"})
    
    local servers = {}
    local timeout = os.startTimer(2)
    
    while true do
        local event, p1, p2, p3, msg = os.pullEvent()
        if event == "modem_message" and p2 == CHANNEL then
            if type(msg) == "table" and msg.type == "taxi_server" then
                servers[msg.dimension] = {
                    id = msg.id,
                    home = msg.home
                }
            end
        elseif event == "timer" and p1 == timeout then
            break
        end
    end
    
    return servers
end

local function showHelp()
    print("=== Drone Taxi Help ===")
    print("")
    print("> taxi")
    print("    - Interactive mode")
    print("> taxi me")
    print("    - Reuse last position")
    print("> taxi go <n>")
    print("    - Go to waypoint or home")
    print("> taxi radius [n]")
    print("    - Search radius 1-10")
    print("> taxi save")
    print("    - Save a waypoint")
    print("> taxi rm")
    print("    - Remove a waypoint")
    print("> taxi list")
    print("    - List waypoints")
    print("")
    print("Destinations:")
    print("  ~ = your Y, home, <waypoint>")
    print("")
    if hasGPS then
        print("GPS: Available")
    else
        print("GPS: Not available")
    end
end

local function doSaveWaypoint()
    print("=== Save Waypoint ===")
    print("")
    print("Waypoint name:")
    local name = read():lower()
    
    if name == "" then
        printError("Name can't be empty")
        return
    end
    
    if RESERVED[name] then
        printError("'" .. name .. "' is reserved!")
        return
    end
    
    local waypoints = loadWaypoints()
    for _, wp in ipairs(waypoints) do
        if wp.name == name then
            printError("'" .. name .. "' already exists!")
            return
        end
    end
    
    print("")
    
    local x, y, z
    
    -- Test GPS fresh and offer if available
    local gpsX, gpsY, gpsZ = getGPSPosition()
    if gpsX then
        print("GPS found: " .. gpsX .. "," .. gpsY .. "," .. gpsZ)
        print("Use this? (Y/n):")
        local choice = read():lower()
        if choice ~= "n" and choice ~= "no" then
            x, y, z = gpsX, gpsY, gpsZ
        end
    end
    
    if not x then
        print("Coordinates (x y z or F3+C):")
        local input = read()
        x, y, z = parseCoords(input, nil)
        
        if not x then
            printError("Invalid coordinates")
            return
        end
    end
    
    table.insert(waypoints, {name = name, x = x, y = y, z = z})
    saveWaypoints(waypoints)
    print("")
    print("Saved '" .. name .. "': " .. x .. "," .. y .. "," .. z)
end

local function doRemoveWaypoint()
    local waypoints = loadWaypoints()
    
    if #waypoints == 0 then
        print("No waypoints to remove")
        return
    end
    
    print("=== Remove Waypoint ===")
    print("")
    
    for i = #waypoints, 1, -1 do
        local wp = waypoints[i]
        local idx = #waypoints - i
        print("  " .. idx .. ") " .. wp.name .. ": " .. wp.x .. "," .. wp.y .. "," .. wp.z)
    end
    
    print("")
    print("Select number to remove:")
    local input = read()
    local selection = tonumber(input)
    
    if not selection then
        printError("Invalid selection")
        return
    end
    
    local arrayIdx = #waypoints - selection
    
    if arrayIdx < 1 or arrayIdx > #waypoints then
        printError("Invalid selection")
        return
    end
    
    local removed = waypoints[arrayIdx]
    table.remove(waypoints, arrayIdx)
    saveWaypoints(waypoints)
    print("Removed '" .. removed.name .. "'")
end

local function doListWaypoints()
    print("=== Waypoints ===")
    print("")
    local waypoints = loadWaypoints()
    
    if #waypoints == 0 then
        print("  (none)")
        return
    end
    
    for i = #waypoints, 1, -1 do
        local wp = waypoints[i]
        print("  " .. wp.name .. ": " .. wp.x .. "," .. wp.y .. "," .. wp.z)
    end
end

local function getPosition(servers)
    local myX, myY, myZ, dimension
    
    -- Try GPS first if available
    if hasGPS then
        print("Getting GPS position...")
        myX, myY, myZ = getGPSPosition()
        if myX then
            dimension = getDimensionFromServers(servers)
            if dimension and servers[dimension] then
                print("GPS: " .. myX .. "," .. myY .. "," .. myZ)
                print("Dimension: " .. dimension)
                return myX, myY, myZ, dimension
            end
        end
        print("GPS failed, use F3+C")
    end
    
    -- Fall back to F3+C
    print("Your position (F3+C):")
    local input = read()
    myX, myY, myZ, dimension = parseF3C(input)
    
    if not myX then
        printError("Try again:")
        input = read()
        myX, myY, myZ, dimension = parseF3C(input)
    end
    
    return myX, myY, myZ, dimension
end

local function requestTaxi(myX, myY, myZ, dimension, destX, destY, destZ, radius)
    local token = tostring(math.random(10000, 65535))
    
    modem.transmit(CHANNEL, CHANNEL, {
        type = "taxi_request",
        dest = {destX, destY, destZ},
        pickup = {myX, myY, myZ},
        dimension = dimension,
        radius = radius,
        token = token
    })
    
    print("")
    if radius > 0 then
        print("Waiting (radius " .. radius .. ")...")
    else
        print("Waiting...")
    end
    
    local timeout = os.startTimer(TIMEOUT)
    
    while true do
        local event, p1, p2, p3, msg = os.pullEvent()
        if event == "modem_message" and p2 == CHANNEL then
            if type(msg) == "table" and msg.token == token then
                if msg.type == "taxi_error" then
                    printError(msg.error or "Unknown error")
                    return
                elseif msg.type == "taxi_status" then
                    print(msg.message)
                elseif msg.type == "taxi_pickup" then
                    print("Drone arrived! Boarding...")
                    sleep(2)
                    modem.transmit(CHANNEL, CHANNEL, {type = "taxi_boarded", token = token})
                elseif msg.type == "taxi_complete" then
                    print("Arrived! Safe travels!")
                    return
                end
            end
        elseif event == "timer" and p1 == timeout then
            printError("Timeout")
            return
        end
    end
end

-- Main
local args = {...}

-- Test GPS on startup
hasGPS = testGPS()

if args[1] == "help" then
    showHelp()
    return
end

if args[1] == "save" then
    doSaveWaypoint()
    return
end

if args[1] == "rm" then
    doRemoveWaypoint()
    return
end

if args[1] == "list" then
    doListWaypoints()
    return
end

-- Handle "taxi radius [n]"
if args[1] == "radius" then
    local radiusVal = tonumber(args[2])
    
    if not radiusVal then
        print("Enter radius (1-10):")
        radiusVal = tonumber(read())
    end
    
    if not radiusVal or radiusVal < 1 or radiusVal > 10 then
        printError("Invalid radius (1-10)")
        return
    end
    
    -- Get servers
    local servers = discoverServers()
    local count = 0
    for _ in pairs(servers) do count = count + 1 end
    if count == 0 then
        printError("No servers found!")
        return
    end
    
    -- Get position
    local myX, myY, myZ, dimension = getPosition(servers)
    if not myX then
        printError("Invalid position")
        return
    end
    
    if not servers[dimension] then
        printError("No server for " .. dimension)
        return
    end
    
    savePosition(myX, myY, myZ, dimension)
    
    -- Get destination coords
    print("")
    print("Enter DESTINATION coords:")
    local destInput = read()
    local destX, destY, destZ = parseCoords(destInput, myY)
    
    if not destX then
        printError("Invalid coordinates")
        return
    end
    
    print("Dest: " .. destX .. "," .. destY .. "," .. destZ)
    print("Radius: " .. radiusVal)
    
    requestTaxi(myX, myY, myZ, dimension, destX, destY, destZ, radiusVal)
    return
end

-- For commands that need servers
local servers = discoverServers()

local count = 0
for dim, info in pairs(servers) do
    count = count + 1
end

if count == 0 then
    printError("No servers found!")
    return
end

local myX, myY, myZ, dimension
local destX, destY, destZ, radius

-- Handle "taxi go <waypoint>"
if args[1] == "go" then
    local wpName = args[2]
    if not wpName then
        printError("Usage: taxi go <waypoint>")
        return
    end
    
    wpName = wpName:lower()
    
    -- Get position (GPS or F3+C)
    myX, myY, myZ, dimension = getPosition(servers)
    if not myX then
        printError("Invalid position")
        return
    end
    
    if not servers[dimension] then
        printError("No server for " .. dimension)
        return
    end
    
    savePosition(myX, myY, myZ, dimension)
    
    -- Check if "home" (exact or partial)
    if wpName == "home" or ("home"):sub(1, #wpName) == wpName then
        local home = servers[dimension].home
        if home then
            destX, destY, destZ = home.x, home.y, home.z
            print("To: home (" .. destX .. "," .. destY .. "," .. destZ .. ")")
        else
            printError("Server didn't provide home")
            return
        end
    else
        local waypoints = loadWaypoints()
        local wp = selectWaypoint(waypoints, wpName)
        if not wp then
            printError("Waypoint not found")
            return
        end
        destX, destY, destZ = wp.x, wp.y, wp.z
        print("To: " .. wp.name .. " (" .. destX .. "," .. destY .. "," .. destZ .. ")")
    end
    
    radius = 0
    
    requestTaxi(myX, myY, myZ, dimension, destX, destY, destZ, radius)
    return
end

-- Interactive mode
print("=== Drone Taxi ===")
if hasGPS then
    print("GPS: Available")
end
print("")

-- Handle "taxi me" or "taxi"
if args[1] == "me" then
    -- Try GPS first for "taxi me"
    if hasGPS then
        print("Getting GPS position...")
        myX, myY, myZ = getGPSPosition()
        if myX then
            dimension = getDimensionFromServers(servers)
            if dimension and servers[dimension] then
                print("GPS: " .. myX .. "," .. myY .. "," .. myZ)
                savePosition(myX, myY, myZ, dimension)
            else
                myX = nil -- reset, will fall back
            end
        end
    end
    
    if not myX then
        myX, myY, myZ, dimension = loadPosition()
        if not myX then
            printError("No saved position!")
            printError("Run 'taxi' first.")
            return
        end
        print("Saved position:")
        print(dimension)
        print(myX .. ", " .. myY .. ", " .. myZ)
    end
    
    if not servers[dimension] then
        printError("No server for " .. dimension)
        return
    end
else
    -- Try GPS first
    if hasGPS then
        print("Getting GPS position...")
        myX, myY, myZ = getGPSPosition()
        if myX then
            dimension = getDimensionFromServers(servers)
            if dimension and servers[dimension] then
                print("GPS: " .. myX .. "," .. myY .. "," .. myZ)
                print("Dimension: " .. dimension)
                savePosition(myX, myY, myZ, dimension)
            else
                myX = nil
            end
        else
            print("GPS failed")
        end
    end
    
    -- Fall back to F3+C if no GPS
    if not myX then
        print("Enter YOUR POSITION")
        print("(F3+C required):")
        local myInput = read()
        myX, myY, myZ, dimension = parseF3C(myInput)

        if not myX then
            printError("Try again (use F3+C):")
            myInput = read()
            myX, myY, myZ, dimension = parseF3C(myInput)
            if not myX then
                printError("Invalid F3+C input")
                return
            end
        end
        
        if not servers[dimension] then
            printError("No server for " .. dimension)
            return
        end
        
        savePosition(myX, myY, myZ, dimension)
        print("Dimension: " .. dimension)
        print("Server: " .. servers[dimension].id)
    end
end

print("")
print("Enter DESTINATION")
print("(coords, F3+C, home, waypoint):")
local destInput = read()
local destInputLower = destInput:lower()

-- Check for "home" (exact or partial)
if destInputLower == "home" or ("home"):sub(1, #destInputLower) == destInputLower then
    local home = servers[dimension].home
    if home then
        destX, destY, destZ = home.x, home.y, home.z
        print("Dest: home (" .. destX .. "," .. destY .. "," .. destZ .. ")")
    else
        printError("Server didn't provide home location")
        return
    end
else
    local waypoints = loadWaypoints()
    local wp = selectWaypoint(waypoints, destInputLower)
    
    if wp then
        destX, destY, destZ = wp.x, wp.y, wp.z
        print("Dest: " .. wp.name .. " (" .. destX .. "," .. destY .. "," .. destZ .. ")")
    else
        destX, destY, destZ = parseCoords(destInput, myY)
        
        if not destX then
            printError("Try again:")
            destInput = read()
            destX, destY, destZ = parseCoords(destInput, myY)
            if not destX then
                printError("Invalid destination")
                return
            end
        end
        print("Dest: " .. destX .. ", " .. destY .. ", " .. destZ)
    end
end

radius = 0

requestTaxi(myX, myY, myZ, dimension, destX, destY, destZ, radius)
