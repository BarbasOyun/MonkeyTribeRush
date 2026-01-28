local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Events = ReplicatedStorage.Shared
local Players = game:GetService("Players")

-- Weapon Client -> Input +  Animation
local LocalPlayer = Players.LocalPlayer
local Username = LocalPlayer.Name
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = character:WaitForChild("Humanoid")
local animationTrack
local animator = Humanoid:WaitForChild("Animator")

-- Remote Events
local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip
local attackHitEvent = Events.AttackHit

local function loadAnimation()
	local anim = Instance.new("Animation")
	--anim.AnimationId = "rbxassetid://522635514" -- R6 slash animation
	anim.AnimationId = "rbxassetid://119339188916178" -- Custom R15
	animationTrack = animator:LoadAnimation(anim)
	animationTrack.Priority = Enum.AnimationPriority.Action

	animationTrack:GetMarkerReachedSignal("AttackHit"):Connect(function()
		--print("Hit Event Triggered by player: " .. Username)
		attackHitEvent:FireServer(LocalPlayer)
	end)
end

loadAnimation()

equipEvent.OnClientEvent:Connect(function(isEquipped)
	--print("Weapon Equipped: " .. tostring(isEquipped) .. " for player: " .. Username)
end)

--Attack Triggered
attackEvent.OnClientEvent:Connect(function()
	--print("Animation for player: " .. Username)
	animationTrack:Play()
	animationTrack:AdjustSpeed(1.2)
end)

--Try to Attack
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then -- or input.KeyCode == Enum.KeyCode.E then
		attackEvent:FireServer(LocalPlayer)
	end
end)
