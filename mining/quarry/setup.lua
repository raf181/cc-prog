local files = {
	{ source = "setup.lua", target = "setup" },
	{ source = "inv.lua", target = "inv" },
	{ source = "t.lua", target = "t" },
	{ source = "quarry.lua", target = "quarry" },
	{ source = "farmTrees.lua", target = "farmTrees" },
	{ source = "fleet.lua", target = "fleet" },
}

local owner = "raf181"
local repo = "cc-prog"
local branch = "fleet-beta"
local basePath = "mining/quarry/"

local function download(source, target)
	local url = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/" .. basePath .. source
	print("Downloading " .. target)

	local response, reason = http.get(url)
	if not response then
		error("Failed to download " .. source .. ": " .. tostring(reason), 0)
	end

	local data = response.readAll()
	response.close()

	local handle = fs.open(target, "w")
	if not handle then
		error("Failed to open " .. target .. " for writing", 0)
	end

	handle.write(data)
	handle.close()
end

if not http then
	error("HTTP API is disabled. Enable http in ComputerCraft config.", 0)
end

for i=1, #files do
	download(files[i].source, files[i].target)
end

print("Installed quarry. Run 'quarry' to start mining.")
