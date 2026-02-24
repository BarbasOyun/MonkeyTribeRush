local TeleportService = game:GetService("TeleportService")
local SafeTeleport = require(game.ReplicatedStorage:WaitForChild("SafeTeleport"))

local placeId = 126527146316982

local gameInstances = {}
local platforms = { workspace.Game1.Platform }
local teleportedPlayers = {}

local function onPlatformTouched(hit, index)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)

	if not player or table.find(teleportedPlayers, player) then
		return
	end

	-- print("Player Touched Platform")
	table.insert(teleportedPlayers, player)

	local success, errorMsg, currentInstance, placeId, jobId = pcall(function()
		return SafeTeleport(placeId, { player })
	end)

	gameInstances[index] = jobId
	teleportedPlayers[table.find(teleportedPlayers, player)] = nil
end

-- Setup Platforms
for i, platform in ipairs(platforms) do
	platform.Touched:Connect(function(hit)
		onPlatformTouched(hit, i + 1)
	end)
end

-- TP Player to followed Player
game.Players.PlayerAdded:Connect(function(player)
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
end)

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
