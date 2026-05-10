local PROTOCOL = "quarryFleet"
local GROUP = "quarry"
local turtles = {}
local running = true

local function openModem()
	for _, side in ipairs(peripheral.getNames()) do
		if peripheral.getType(side) == "modem" then
			if not rednet.isOpen(side) then
				rednet.open(side)
			end
			return side
		end
	end
	error("Attach a modem to this computer", 0)
end

local function sortedIds()
	local ids = {}
	for id in pairs(turtles) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

local function addCounts(target, source)
	for name, count in pairs(source or {}) do
		target[name] = (target[name] or 0) + count
	end
end

local function shortName(name)
	return string.gsub(name, "^minecraft:", "")
end

local function redraw()
	term.clear()
	term.setCursorPos(1, 1)
	print("Quarry Fleet [" .. GROUP .. "]")
	print("Commands: start | return | stop | reset | clear | quit")
	print("")
	print("ID   Z    Fuel   Event")
	print("-------------------------------")

	local totals = {}
	for _, id in ipairs(sortedIds()) do
		local t = turtles[id]
		addCounts(totals, t.kept)
		print(string.format("%-4s %-4s %-6s %s",
			tostring(id),
			tostring(t.z or "?"),
			tostring(t.fuel or "?"),
			tostring(t.event or "?")))
	end

	print("")
	print("Kept item totals:")
	local any = false
	for name, count in pairs(totals) do
		any = true
		print(string.format("%-24s %d", shortName(name), count))
	end
	if not any then
		print("(none reported yet)")
	end
	print("")
	write("> ")
end

local function send(command)
	rednet.broadcast({
		type = "quarryCommand",
		group = GROUP,
		command = command,
	}, PROTOCOL)
end

local function receiveLoop()
	while running do
		local sender, msg = rednet.receive(PROTOCOL, 1)
		if type(msg) == "table" and msg.type == "quarryStatus" and msg.group == GROUP then
			msg.sender = sender
			turtles[msg.id or sender] = msg
			redraw()
		end
	end
end

local function inputLoop()
	redraw()
	while running do
		local command = read()
		if command == "start" or command == "return" or command == "stop" or command == "reset" then
			send(command)
		elseif command == "clear" then
			turtles = {}
		elseif command == "quit" or command == "exit" then
			running = false
		else
			print("Unknown command")
			sleep(1)
		end
		redraw()
	end
end

openModem()
parallel.waitForAny(receiveLoop, inputLoop)
