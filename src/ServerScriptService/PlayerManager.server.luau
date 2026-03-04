-- Services
local DataStoreService = game:GetService("DataStoreService")
local KillsData = DataStoreService:GetOrderedDataStore("Wins") -- TODO : Use Scopes
local BananasData = DataStoreService:GetDataStore("Bananas")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PlayersStats = require(ServerScriptService.Server.PlayersStats)
local Gears = require(ServerScriptService.Server.Gears)
local Events = ReplicatedStorage.Shared

-- Variables
local frameCount = 0
local targetFrame = 5

-- XpGrabRange Parameters
local xpPickupParam = OverlapParams.new()
xpPickupParam.FilterType = Enum.RaycastFilterType.Include
xpPickupParam.FilterDescendantsInstances = { workspace.XP_Orbs }
xpPickupParam.MaxParts = 50

local function EquipDefaultWeapon(player)
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	local defaultTool = backpack:FindFirstChild("WoodenClub")
	if defaultTool then
		humanoid:EquipTool(defaultTool)
	end
end

local function SpawnRangeAroundPlayer(player)
	local radius = math.random(5, 8)
	local progress = Gears.FloatRandom(0, math.pi * 2)
	local circlePos = Gears.CirclePos(radius, progress)
	return player.PrimaryPart.Position + Vector3.new(circlePos.X, 0, circlePos.Y)
end

local function GetXp(xpOrb, player, playerStats)
	if xpOrb.Name == "SmallXpOrb" then
		-- print("Add Small XP Orb")
		PlayersStats.AddXp(10)
	elseif xpOrb.Name == "Banana" then
		-- print("Banana Collected")
		playerStats.bananas.Value += 1
	end

	Events.XpPickup:FireClient(player)
	xpOrb:Destroy()
end

local function GrabXp(character, xpOrb, player, playerStats)
	-- print("xpOrb Found")
	if not xpOrb.Parent then
		return
	end

	if xpOrb.Parent ~= workspace.XP_Orbs then
		return
	end

	xpOrb.Parent = game.Workspace
	xpOrb.CanCollide = false

	-- Lerp XP
	local startPos = xpOrb.CFrame

	local steps = 60
	local progress = 0
	local speed = 1 / steps / 4
	local acceleration = (1 / steps - speed) / (steps / 2)

	for _ = 1, steps do
		progress += speed
		speed += acceleration
		xpOrb.CFrame = startPos:Lerp(character:GetPivot(), progress)
		RunService.Heartbeat:Wait()
	end

	GetXp(xpOrb, player, playerStats)
end

local function XpGrabRange()
	if frameCount < targetFrame then
		frameCount += 1
		return
	end

	frameCount = 0

	for _, player in pairs(game.Players:GetChildren()) do
		-- print(player.Name)
		local playerStats = PlayersStats[player.UserId]
		local character = player.Character or player.CharacterAdded:Wait()
		local position = character.HumanoidRootPart.CFrame.Position
		local range = playerStats.finalPickupRange

		-- Gears.DisplayHitBox(position, range, 0.1)
		local xpOrbs = workspace:GetPartBoundsInRadius(position, range, xpPickupParam)
		for _, xpOrb in ipairs(xpOrbs) do
			GrabXp(character, xpOrb, player, playerStats)
		end
	end
end

RunService.Heartbeat:Connect(XpGrabRange)

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game!")

	local leaderstats = Instance.new("Folder")
	leaderstats.Parent = player
	leaderstats.Name = "leaderstats"

	local uiInfos = Instance.new("Folder")
	uiInfos.Parent = player
	uiInfos.Name = "UIInfos"

	PlayersStats.CreatePlayer(player, leaderstats, uiInfos)

	EquipDefaultWeapon(player)

	-- TODO : At the end of the Game
	-- local killsData = leaderstats:WaitForChild("KillsData")
	-- killsData.Changed:Connect(function()
	-- 	KillsData:SetAsync(player.UserId, killsData.Value)
	-- end)

	-- Find max Kills & Destruction Value
	-- use pcall
end)

Gears.StartStage()
