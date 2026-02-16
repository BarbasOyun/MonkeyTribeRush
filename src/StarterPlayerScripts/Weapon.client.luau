-- Weapon Client -> Input +  Animation
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Events = ReplicatedStorage.Shared
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local animationTracks = {}

local isLClickDown = false

-- Remote Events
local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip
local attackHitEvent = Events.AttackHit

-- Animations
local function loadAnimation(animationId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animationId
	local animationTrack = animator:LoadAnimation(anim)
	animationTrack.Priority = Enum.AnimationPriority.Action

	animationTrack:GetMarkerReachedSignal("AttackHit"):Connect(function()
		--print("Hit Event Triggered by player: " .. player.Name)
		attackHitEvent:FireServer(player)
	end)

	return animationTrack
end

local function loadAllAnimations()
	local horizontalSlash = loadAnimation("rbxassetid://88145589618998") -- Combo 1
	local verticalSlash = loadAnimation("rbxassetid://119339188916178") -- Combo 2

	table.insert(animationTracks, horizontalSlash)
	table.insert(animationTracks, verticalSlash)
end

equipEvent.OnClientEvent:Connect(function(isEquipped)
	--print("Weapon Equipped: " .. tostring(isEquipped) .. " for player: " .. LocalPlayer.Name)
end)

-- On Respawn
local function onCharacterAdded(newCharacter)
	print("Character Added for player: " .. player.Name)
	animator = newCharacter:WaitForChild("Humanoid"):WaitForChild("Animator")
	table.clear(animationTracks)
	loadAllAnimations()
end

--Attack Triggered
attackEvent.OnClientEvent:Connect(function(animationId, animationSpeed)
	-- print(localPlayer.Name .. " Combo: " .. animationId .. " Animation Speed: " .. animationSpeed)
	animationTracks[animationId]:Play()
	animationTracks[animationId]:AdjustSpeed(animationSpeed)
end)

--Try to Attack
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attackEvent:FireServer(player)
		isLClickDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isLClickDown = false
	end
end)

RunService.Heartbeat:Connect(function()
	if isLClickDown then
		attackEvent:FireServer(player)
	end
end)

-- Run
player.CharacterAdded:Connect(onCharacterAdded)
loadAllAnimations()
