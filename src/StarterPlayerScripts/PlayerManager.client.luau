local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Events = ReplicatedStorage.Shared
local RunService = game:GetService("RunService")
local AugmentsConfig = require(ReplicatedStorage.Shared.Modules.AugmentsConfig)

local player = game.Players.LocalPlayer

local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
-- local Controls = require(PlayerScripts:WaitForChild("PlayerModule")):GetControls() -- Rojo error

local storedWaitLevels = 0

-- UI
local playerGui = player:WaitForChild("PlayerGui")

local uiInfos = player:WaitForChild("UIInfos")
local xpBarCurrent = uiInfos:WaitForChild("XpBarCurrent")
local xpBarMax = uiInfos:WaitForChild("XpBarMax")

-- Main
local mainGui = playerGui:WaitForChild("MainGui")
local levelText = mainGui:WaitForChild("LevelText")
local levelUpButton = mainGui:WaitForChild("Lvl+Button")

local xpBarBg = mainGui:WaitForChild("XpBarBG")
local xpBar = xpBarBg:WaitForChild("XpBar")
local xpBarText = xpBarBg:WaitForChild("XpBarText")
local xpBarUpdater = nil

-- Augments
local cardGui = playerGui:WaitForChild("CardGui")
local rerollButton = cardGui:WaitForChild("RerollButton")
local cards = { cardGui:WaitForChild("Card_01"), cardGui:WaitForChild("Card_02"), cardGui:WaitForChild("Card_03") }
local cardTexts =
	{ cards[1]:WaitForChild("TextLabel"), cards[2]:WaitForChild("TextLabel"), cards[3]:WaitForChild("TextLabel") }
local blur = nil

-- Events
local levelUpEvent = Events.LevelUp
local rerollEvent = Events.Reroll
local augmentPick = Events.AugmentPick

local function PrintAugmentChoice(augmentsChoice)
	local function AugmentToString(augment)
		print("Type = " .. augment[1] .. " Rarity = " .. augment[2] .. " Value = " .. augment[3])
	end

	print("Augment Choices :")
	AugmentToString(augmentsChoice[1])
	AugmentToString(augmentsChoice[2])
	AugmentToString(augmentsChoice[3])
end

local function SetupAugments(augmentsChoice)
	-- PrintAugmentChoice(augmentsChoice)
	for i, card in pairs(cards) do
		card.BackgroundColor3 = AugmentsConfig.colors[augmentsChoice[i][2]] -- Rarity Color
		cardTexts[i].Text = augmentsChoice[i][2] -- Rarity
			.. " \n "
			.. augmentsChoice[i][3] -- Value
			.. " \n "
			.. AugmentsConfig.displayName[augmentsChoice[i][1]] -- Type
	end
end

local function OnLevelUp(level, waitingLevels)
	levelText.Text = "Level : " .. level
	levelUpButton.Text = "(A) " .. waitingLevels .. " Lvl+"

	if waitingLevels > 0 then
		levelUpButton.Visible = true
	end

	storedWaitLevels = waitingLevels
end

local function DisplayAugments()
	if not levelUpButton.Visible then
		return
	end

	local lighting = game:WaitForChild("Lighting")
	blur = Instance.new("BlurEffect")
	blur.Size = 10
	blur.Parent = lighting

	cardGui.Enabled = true
	augmentPick:FireServer()

	-- Controls:Disable()
end

local function Reroll()
	rerollEvent:FireServer()
end

local function ChooseCard(choiceNbr)
	-- print("Choosed Card : " .. choiceNbr)

	levelUpEvent:FireServer(choiceNbr)
	levelUpButton.Visible = false

	if storedWaitLevels > 1 then
		return
	end

	-- Controls:Enable()
	blur:Destroy()

	cardGui.Enabled = false
end

local function UpdateXpBar()
	if xpBarUpdater then
		xpBarUpdater:Disconnect()
	end

	-- print("Update XP Bar : " .. xpBarCurrent.Value .. " / " .. xpBarMax.Value)

	xpBarUpdater = RunService.Heartbeat:Connect(function(dT)
		-- local targetSize = UDim2.new(xpBarCurrent.Value / xpBarMax.Value, 0, 1, 0)
		local targetSize = UDim2.fromScale(xpBarCurrent.Value / xpBarMax.Value, 1)
		xpBar.Size = xpBar.Size:Lerp(targetSize, 5 * dT)
		xpBarText.Text = xpBarCurrent.Value .. " / " .. xpBarMax.Value

		if xpBar.Size.X.Scale >= 0.99 then
			xpBar.Size = targetSize
			xpBarUpdater:Disconnect()
		end
	end)
end

-- Keybinds
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
	if gameProcessed then
		return
	end

	local keyName = UserInputService:GetStringForKeyCode(input.KeyCode)

	if keyName:lower() == "a" then
		DisplayAugments()
	end
end)

-- level.Changed:Connect(function()
-- 	levelText.Text = "Level : " .. level.Value
-- end)

xpBarCurrent.Changed:Connect(UpdateXpBar)
xpBarMax.Changed:Connect(UpdateXpBar)

levelUpEvent.OnClientEvent:Connect(OnLevelUp)
levelUpButton.MouseButton1Click:Connect(DisplayAugments)

rerollButton.MouseButton1Click:Connect(Reroll)
rerollEvent.OnClientEvent:Connect(SetupAugments)

cards[1].MouseButton1Click:Connect(function()
	ChooseCard(1)
end)

cards[2].MouseButton1Click:Connect(function()
	ChooseCard(2)
end)

cards[3].MouseButton1Click:Connect(function()
	ChooseCard(3)
end)

-- Update XP Bar
xpBarCurrent.Value = 1
xpBarCurrent.Value = 0
