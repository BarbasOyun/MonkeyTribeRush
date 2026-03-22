local ReplicatedStorage = game.ReplicatedStorage
local TeleportService = game:GetService("TeleportService")
local SafeTeleport = require(ReplicatedStorage.Shared.SafeTeleport)
local Events = require(ReplicatedStorage.Shared.Events)
local Players = game:GetService("Players")

local DataStoreService = game:GetService("DataStoreService")
local BananasData = DataStoreService:GetDataStore("Bananas")

local placeId = 126527146316982

-- local gameInstances = {}
local platforms = { workspace.Game1.Platform }
local teleportedPlayers = {}

local playerData = {}

-- Music
local music = workspace.Music
music:Play()

local function onPlatformTouched(hit, index)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)

	if not player or table.find(teleportedPlayers, player) then
		return
	end

	-- print("Player Touched Platform")
	table.insert(teleportedPlayers, player)
	Events.platformTouched:FireClient(player)

	local success, errorMsg, currentInstance, placeId, jobId = pcall(function()
		return SafeTeleport(placeId, { player })
	end)

	-- gameInstances[index] = jobId
	local playerIndex = table.find(teleportedPlayers, player)
	if playerIndex then
		teleportedPlayers[playerIndex] = nil
	end
end

local function SetupPlatforms()
	for i, platform in ipairs(platforms) do
		platform.Touched:Connect(function(hit)
			onPlatformTouched(hit, i + 1)
		end)
	end
end

local function createRoomAndTeleport(players)
	local success, reservedCode = pcall(function()
		return TeleportService:ReserveServerAsync(placeId)
	end)

	if success then
		TeleportService:TeleportToPrivateServer(placeId, reservedCode, players)
	else
		warn("Failed to reserve server!")
	end
end

-- Player Added
Players.PlayerAdded:Connect(function(player)
	-- TP Player to followed Player
	local followPlayerId = player.FollowUserId

	if followPlayerId and followPlayerId ~= 0 then
		local success, errorMsg, currentInstance, placeId, jobId = pcall(function()
			return TeleportService:GetPlayerPlaceInstanceAsync(followPlayerId)
		end)

		if success then
			TeleportService.TeleportToPlaceInstance(placeId, jobId, player)
		else
			warn(errorMsg)
		end
	end

	-- Display Bananas
	local uiData = Instance.new("Folder")
	uiData.Parent = player
	uiData.Name = "UIData"

	local bananas = Instance.new("IntValue")
	bananas.Parent = uiData
	bananas.Name = "Bananas"

	local bananasCount = BananasData:GetAsync(player.UserId)
	bananas.Value = bananasCount
	print(player.Name .. " Has " .. bananasCount .. " Bananas")

	playerData[player.UserId] = bananasCount
end)

-- Do
SetupPlatforms()
