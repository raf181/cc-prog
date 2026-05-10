local files = {
	{ path = "inv", paste = "8htSEHES" },
	{ path = "t", paste = "VkgXTNu1" },
	{ path = "quarry", paste = "7MVGF4k9" },
	{ path = "farmTrees", paste = "GfTNHgrY" },
}

local function request(url)
	local response, reason = http.get(url)
	if not response then
		error("Failed to download " .. url .. ": " .. tostring(reason), 0)
	end

	if response.getResponseCode and response.getResponseCode() ~= 200 then
		local status = response.getResponseCode()
		local body = response.readAll()
		response.close()
		error("Failed to download " .. url .. ": HTTP " .. status .. " " .. tostring(body), 0)
	end

	return response
end

local function download(path, paste)
	local url = "https://pastebin.com/raw/" .. paste
	print("Downloading " .. path)

	local response = request(url)
	local data = response.readAll()
	response.close()

	local handle = fs.open(path, "w")
	if not handle then
		error("Failed to open " .. path .. " for writing", 0)
	end

	handle.write(data)
	handle.close()
end

if not http then
	error("HTTP API is disabled. Enable http in ComputerCraft config.", 0)
end

for i=1, #files do
	download(files[i].path, files[i].paste)
end

print("Installed quarry. Run 'quarry' to start mining.")
