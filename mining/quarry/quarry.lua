os.loadAPI("inv")
os.loadAPI("t")

local x = 0
local y = 0
local z = 0
local max = 16
local deep = 64
local facingfw = true
local STATE_FILE = "quarry.state"

local OK = 0
local ERROR = 1
local LAYERCOMPLETE = 2
local OUTOFFUEL = 3
local FULLINV = 4
local BLOCKEDMOV = 5
local USRINTERRUPT = 6

local CHARCOALONLY = false
local USEMODEM = false
local RESETSTATE = false
local WAITSTART = false
local FLEET_PROTOCOL = "quarryFleet"
local FLEET_GROUP = "quarry"

function saveState()
	local file = fs.open(STATE_FILE, "w")
	if file == nil then
		printError("Could not save quarry state")
		return false
	end

	file.write(textutils.serialize({
		x = x,
		y = y,
		z = z,
		max = max,
		deep = deep,
		facingfw = facingfw,
		charcoalOnly = CHARCOALONLY,
		useModem = USEMODEM,
	}))
	file.close()
	return true
end

function loadState()
	if not fs.exists(STATE_FILE) then
		return false
	end

	local file = fs.open(STATE_FILE, "r")
	if file == nil then
		printError("Could not read quarry state")
		return false
	end

	local data = textutils.unserialize(file.readAll())
	file.close()

	if type(data) ~= "table" then
		printError("Ignoring invalid quarry state")
		return false
	end

	x = data.x or 0
	y = data.y or 0
	z = data.z or 0
	max = data.max or max
	deep = data.deep or deep
	CHARCOALONLY = data.charcoalOnly or CHARCOALONLY
	USEMODEM = data.useModem or USEMODEM
	facingfw = data.facingfw
	if facingfw == nil then
		facingfw = true
	end
	return true
end

function clearState()
	if fs.exists(STATE_FILE) then
		fs.delete(STATE_FILE)
	end
end


-- Arguments
local tArgs = {...}
for i=1,#tArgs do
	local arg = tArgs[i]
	if string.find(arg, "-") == 1 then
		for c=2,string.len(arg) do
			local ch = string.sub(arg,c,c)
			if ch == 'c' then
				CHARCOALONLY = true
			elseif ch == 'm' then
				USEMODEM = true
			elseif ch == 'r' then
				RESETSTATE = true
			elseif ch == 'w' then
				WAITSTART = true
				USEMODEM = true
			else
				write("Invalid flag '")
				write(ch)
				print("'")
			end
		end
	end
end


function out(s)

	local s2 = s .. " @ [" .. x .. ", " .. y .. ", " .. z .. "]"
			
	print(s2)
	if USEMODEM then
		rednet.broadcast(s2, "miningTurtle")
	end  
end

function fleetReport(event, detail)
	if not USEMODEM then
		return
	end

	rednet.broadcast({
		type = "quarryStatus",
		group = FLEET_GROUP,
		id = os.getComputerID(),
		label = os.getComputerLabel and os.getComputerLabel() or nil,
		event = event,
		detail = detail,
		x = x,
		y = y,
		z = z,
		facingfw = facingfw,
		fuel = turtle.getFuelLevel(),
		kept = inv.getKeptCounts(),
	}, FLEET_PROTOCOL)
end

function isFleetCommand(msg, command)
	return type(msg) == "table" and
			msg.type == "quarryCommand" and
			msg.group == FLEET_GROUP and
			msg.command == command
end

function waitForFleetStart()
	out("Waiting for fleet start")
	fleetReport("waiting", "Waiting for fleet start")

	while true do
		local _, msg = rednet.receive(FLEET_PROTOCOL)
		if isFleetCommand(msg, "start") then
			fleetReport("started", "Fleet start received")
			return
		elseif isFleetCommand(msg, "reset") then
			clearState()
			saveState()
			fleetReport("reset", "State reset from fleet")
		end
	end
end

function isHomeChest(name)
	return name == "minecraft:chest" or string.match(name, ":chest$") ~= nil
end

function selectHomeChest()
	return inv.selectItemWhere(function(item)
		return isHomeChest(item.name) and item.name ~= "minecraft:trapped_chest"
	end)
end

function ensureHomeChest()
	turtle.turnLeft()
	
	local success, data = turtle.inspect()
	
	if not success and selectHomeChest() and turtle.place() then
		success, data = turtle.inspect()
	end

	turtle.turnRight()

	return success and isHomeChest(data.name)
end

function dropInChest()
	turtle.turnLeft()
	
	local success, data = turtle.inspect()
	
	if success then
		if isHomeChest(data.name) then
		
			out("Dropping items in chest")
			
			for i=1, 16 do
				turtle.select(i)
				
				local item = turtle.getItemDetail()
				
				if item ~= nil and not isFuelToKeep(item) then

					turtle.drop()
				end
			end
		end
	end
	
	turtle.turnRight()
	
end

function isFuelToKeep(item)
	if item.name == "minecraft:charcoal" then
		return true
	end

	if item.name == "minecraft:coal" then
		if CHARCOALONLY then
			return item.damage == 1
		end
		return true
	end

	return false
end

function goDown()
	while true do
		if turtle.getFuelLevel() <= fuelNeededToGoBack() then
			if not refuel() then
				return OUTOFFUEL
			end
		end
	
		if not turtle.down() then
			return OK
		end
		z = z-1
		saveState()
	end
end

function fuelNeededToGoBack()
	return -z + x + y + 2
end

function refuel()
	for i=1, 16 do
		-- Only run on Charcoal
		turtle.select(i)
		
		local item = turtle.getItemDetail()
		if item and
				(item.name == "minecraft:charcoal" or (item.name == "minecraft:coal" and
				(CHARCOALONLY == false or item.damage == 1))) and
				turtle.refuel(1) then
			return true
		end
	end
	
	return false
end

function moveH()
	if inv.isInventoryFull() then
		out("Dropping thrash")
		inv.dropThrash()
		
		if inv.isInventoryFull() then
			out ("Stacking items")
			inv.stackItems()
		end
		
		if inv.isInventoryFull() then
			out("Full inventory!")
			fleetReport("full", "Inventory full")
			return FULLINV  
		end
	end
	
	if turtle.getFuelLevel() <= fuelNeededToGoBack() then
		if not refuel() then
			out("Out of fuel!")
			fleetReport("fuel", "Out of fuel")
			return OUTOFFUEL
		end
	end
	
	if facingfw and y<max-1 then
	-- Going one way
		local dugFw = t.dig()
		if dugFw == false then
			out("Hit bedrock, can't keep going")
			fleetReport("blocked", "Hit bedrock forward")
			return BLOCKEDMOV
		end
		t.digUp()
		t.digDown()
	
		if t.fw() == false then
			return BLOCKEDMOV
		end
		
		y = y+1
		saveState()
		fleetReport("progress", "Moved forward")
	
	elseif not facingfw and y>0 then
	-- Going the other way
		t.dig()
		t.digUp()
		t.digDown()
		
		if t.fw() == false then
			return BLOCKEDMOV
		end
		
		y = y-1
		saveState()
		fleetReport("progress", "Moved back across row")
		
	else
		if x+1 >= max then
			t.digUp()
			t.digDown()
			return LAYERCOMPLETE -- Done with this Y level
		end
		
		-- If not done, turn around
		if facingfw then
			turtle.turnRight()
		else
			turtle.turnLeft()
		end
		
		t.dig()
		t.digUp()
		t.digDown()
		
		if t.fw() == false then
			return BLOCKEDMOV
		end
		
		x = x+1
		
		if facingfw then
			turtle.turnRight()
		else
			turtle.turnLeft()
		end
		
		facingfw = not facingfw
		saveState()
		fleetReport("progress", "Started next row")
	end
	
	return OK
end

function digLayer()
	
	local errorcode = OK

	while errorcode == OK do
		if USEMODEM then
			local _, msg = rednet.receive(FLEET_PROTOCOL, 1)
			if type(msg) == "string" and string.find(msg, "return") ~= nil then
				return USRINTERRUPT
			elseif isFleetCommand(msg, "return") or isFleetCommand(msg, "stop") then
				fleetReport("returning", "Fleet return received")
				return USRINTERRUPT
			end
		end
		errorcode = moveH()
	end
	
	if errorcode == LAYERCOMPLETE then
		return OK
	end
	
	return errorcode  
end

function goToOrigin()
	
	if facingfw then
		
		turtle.turnLeft()
		
		while x > 0 do
			t.fw()
			x = x-1
			saveState()
		end
		
		turtle.turnLeft()
		
		while y > 0 do
			t.fw()
			y = y-1
			saveState()
		end
		
		turtle.turnRight()
		turtle.turnRight()
		
	else
		
		turtle.turnRight()
		
		while x > 0 do
			t.fw()
			x = x-1
			saveState()
		end
		
		turtle.turnLeft()
		
		while y > 0 do
			t.fw()
			y = y-1
			saveState()
		end
		
		turtle.turnRight()
		turtle.turnRight()
		
	end
	
	x = 0
	y = 0
	facingfw = true
	saveState()
	
end

function goUp()

	while z < 0 do
		
		t.up()
		
		z = z+1
		saveState()
		
	end
	
	goToOrigin()
	
end

function mainloop()

	while true do

		local errorcode = digLayer()
	
		if errorcode ~= OK then
			goUp()
			return errorcode
		end
		
		goToOrigin()
		
		for i=1, 3 do
			t.digDown()
			local success = t.down()
		
			if not success then
				goUp()
				return BLOCKEDMOV
			end

			z = z-1
			out("Z: " .. z)
			saveState()

		end
	end
end

if RESETSTATE then
	clearState()
end

local resumed = loadState()

if USEMODEM then
	rednet.open("right")
end

out("\n\n\n-- WELCOME TO THE MINING TURTLE --\n\n")
	if resumed then
		out("Loaded saved quarry state")
		fleetReport("resumed", "Loaded saved quarry state")
	else
		saveState()
		fleetReport("ready", "New quarry state saved")
	end

if not ensureHomeChest() then
	out("No home chest on the left")
	fleetReport("warning", "No home chest on the left")
else
	fleetReport("chest", "Home chest ready")
end

if WAITSTART then
	waitForFleetStart()
end

while true do

	local errorcode = goDown()
	if errorcode ~= OK then
		break
	end

	errorcode = mainloop()
	dropInChest()
	fleetReport("drop", "Dropped items in chest")
	
	if errorcode ~= FULLINV then
		fleetReport("stopped", "Quarry stopped")
		break
	end
end

if USEMODEM then
	rednet.close("right")
end
