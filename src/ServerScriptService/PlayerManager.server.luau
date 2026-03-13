-- Services
local DataStoreService = game:GetService("DataStoreService")
local KillsData = DataStoreService:GetOrderedDataStore("Wins") -- TODO : Use Scopes
local BananasData = DataStoreService:GetDataStore("Bananas")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PlayersStats = require(ServerScriptService.Server.PlayersStats)
-- local Gears = require(ServerScriptService.Server.Gears)
local MapGenerator = require(ServerScriptService.Server.MapGenerator)
local Events = ReplicatedStorage.Shared

-- Players
local MAX_SPEED = 100
local MAX_DISTANCE = 200

local bananaCount = 0

local xpFrame = 5 -- Gather xp Every X Frame
local frameCount = 0

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

local function GetXp(xpOrb, player)
	if xpOrb.Name == "SmallXpOrb" then
		-- print("Add Small XP Orb")
		PlayersStats.AddXp(10)
	elseif xpOrb.Name == "Banana" then
		bananaCount += 1
		Events.BananaPickup:FireAllClients(bananaCount)
	end

	Events.XpPickup:FireClient(player)
	xpOrb:Destroy()
end

local function GrabXp(character, xpOrb, player)
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

	local steps = 30
	local progress = 0
	local speed = 1 / steps / 4
	local acceleration = (1 / steps - speed) / (steps / 2)

	for _ = 1, steps do
		progress += speed
		speed += acceleration
		xpOrb.CFrame = startPos:Lerp(character:GetPivot(), progress)
		RunService.Heartbeat:Wait()
	end

	GetXp(xpOrb, player)
end

local function XpGrabRange()
	if frameCount < xpFrame then
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
			GrabXp(character, xpOrb, player)
		end
	end
end

RunService.Heartbeat:Connect(XpGrabRange)

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game")

	local leaderstats = Instance.new("Folder")
	leaderstats.Parent = player
	leaderstats.Name = "leaderstats"

	local uiInfos = Instance.new("Folder")
	uiInfos.Parent = player
	uiInfos.Name = "UIInfos"

	PlayersStats.CreatePlayer(player, leaderstats, uiInfos)

	EquipDefaultWeapon(player)

	local character = player.Character
	local root = character:FindFirstChild("HumanoidRootPart")

	RunService.Heartbeat:Connect(function()
		-- Limit Velocity
		-- if root then
		-- 	local velocity = root.AssemblyLinearVelocity
		-- 	if velocity.Magnitude > MAX_SPEED then
		-- 		root.AssemblyLinearVelocity = velocity.Unit * MAX_SPEED
		-- 	end
		-- end

		-- Limit Distance
		local pos = root.Position
		local flatPos = Vector2.new(pos.X, pos.Z) -- Check 2D distance

		if flatPos.Magnitude > MAX_DISTANCE then -- TODO : Squared Magnitude
			character:PivotTo(CFrame.new(Vector3.zero))
			root.AssemblyLinearVelocity = Vector3.zero -- Kill the momentum
		end
	end)

	-- TODO : At the end of the Game
	-- local killsData = leaderstats:WaitForChild("KillsData")
	-- killsData.Changed:Connect(function()
	-- 	KillsData:SetAsync(player.UserId, killsData.Value)
	-- end)

	-- Find max Kills & Destruction Value
	-- use pcall
end)

MapGenerator.StartStage()
