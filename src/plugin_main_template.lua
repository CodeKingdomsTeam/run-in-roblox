local portValue = game:FindFirstChild("RUN_IN_ROBLOX_PORT")

while portValue == nil do
	game.ChildAdded:Wait()
	portValue = game:FindFirstChild("RUN_IN_ROBLOX_PORT")
end

if portValue.ClassName ~= "IntValue" then
	warn("run-in-roblox found RUN_IN_ROBLOX_PORT marker, but it was the wrong type.")
	return
end

local place_port = portValue.Value

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local PORT = {{PORT}}
local SERVER_URL = ("http://localhost:%d"):format(PORT)

if place_port ~= PORT then
	return
end

local queuedMessages = {}
local closeDelay = 0.5
local running = true

local function flushMessages()
	if #queuedMessages == 0 then
		return
	end

	local encoded = HttpService:JSONEncode(queuedMessages)
	queuedMessages = {}

	HttpService:PostAsync(SERVER_URL .. "/messages", encoded)
end

local logTypeToLevel = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

local logConnection = LogService.MessageOut:Connect(function(body, messageType)
	table.insert(queuedMessages, {
		type = "Output",
		level = logTypeToLevel[messageType] or "Info",
		body = body,
	})
end)

HttpService:PostAsync(SERVER_URL .. "/start", "")

flushMessages()

spawn(function()
	local success, errorMessage = pcall(function()
		loadstring(script.main.Source)()
	end)

	if not success then
		warn("main encountered an error:")
		warn(errorMessage)
	end

	wait(closeDelay)
	running = false
end)

local timeout = tick() + {{TIMEOUT}}

while (running or (_G.RUN_IN_ROBLOX_COMPLETE == nil or _G.RUN_IN_ROBLOX_COMPLETE == false)) and tick() < timeout do
	flushMessages()
	wait(1)
end

flushMessages()

local success, errorMessage = pcall(function()
	HttpService:PostAsync(SERVER_URL .. "/stop", "")
end)

if not success then
	warn("Could not send POST request to stop")
	warn(errorMessage)
end

logConnection:Disconnect()
