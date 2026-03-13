local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Events = ReplicatedStorage.Shared
local RunService = game:GetService("RunService")
local AugmentsConfig = require(ReplicatedStorage.Shared.Modules.AugmentsConfig)

local player = game.Players.LocalPlayer

local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local Controls = require(PlayerScripts:WaitForChild("PlayerModule")):GetControls() -- Rojo error

local storedWaitLevels = 0

-- Events
local levelUpEvent = Events.LevelUp
local rerollEvent = Events.Reroll
local augmentPick = Events.AugmentPick
local stageProgress = Events.StageProgress

-- UI
--local playerGui = player:WaitForChild("PlayerGui")
local playerGui = player.PlayerGui

local uiInfos = player:WaitForChild("UIInfos")
local xpBarCurrent = uiInfos.XpBarCurrent
local xpBarMax = uiInfos.XpBarMax --:WaitForChild("XpBarMax")

-- Main UI
local mainGui = playerGui:WaitForChild("MainGui")
local barUpdaters = {}

-- Level + XP Bar
local levelText = mainGui.LevelText
local levelUpButton = mainGui.LvlUpButton

local xpBarBg = mainGui.XpBarBG
local xpBar = xpBarBg.XpBar
local xpBarText = xpBarBg.XpBarText

-- Stage
local stageProgressBar = mainGui.StageProgressBG.StageProgressBar
local nextStageTimer = mainGui.NextStageTimer
-- local currentStageText = mainGui.StageProgressBG.StageNbr
local bananaText = mainGui.BananaNbrText

-- Augments
local cardGui = playerGui:WaitForChild("CardGui")
local rerollButton = cardGui.RerollButton
local cards = { cardGui.Card_01, cardGui.Card_02, cardGui.Card_03 }
local cardTexts = { cards[1].TextLabel, cards[2].TextLabel, cards[3].TextLabel }
local blur = nil

-- Sounds
-- local levelUpSound = playerGui.Sounds:WaitForChild("LvlUp")
local levelUpSound = playerGui.Sounds.LvlUp
local augmentMenuSound = playerGui.Sounds.AugmentMenu
local augmentPickSound = playerGui.Sounds.AugmentPick
local getXPSound = playerGui.Sounds.GetXp

local humanoid = player.Character.Humanoid
humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

local function OnLevelUp(level, waitingLevels)
	levelUpButton.Text = "(A) " .. waitingLevels .. " Lvl+"
	levelUpSound:Play()

	levelUpButton.Visible = true
	storedWaitLevels = waitingLevels
end

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

local function AugmentPickResponse(level, waitingLevels)
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
	augmentMenuSound:Play()
	augmentPick:FireServer()

	Controls:Disable()
end

local function Reroll()
	rerollEvent:FireServer()
end

local function ChooseCard(choiceNbr)
	-- print("Choosed Card : " .. choiceNbr)

	levelUpEvent:FireServer(choiceNbr)
	levelUpButton.Visible = false
	augmentPickSound:Play()

	if storedWaitLevels > 1 then
		return
	end

	Controls:Enable()
	blur:Destroy()

	cardGui.Enabled = false
end

local function UpdateBar(bar, progress)
	local barUpdater = barUpdaters[bar]

	local Disconnect = function()
		if barUpdater then
			barUpdater:Disconnect()
			barUpdaters[bar] = nil
		end
	end

	Disconnect()

	-- print("Update " .. bar .. " -> " .. progress)
	local targetSize = UDim2.fromScale(progress, 1)

	barUpdater = RunService.Heartbeat:Connect(function(dT)
		bar.Size = bar.Size:Lerp(targetSize, 5 * dT) -- 5 = Speed

		if bar.Size.X.Scale >= 0.99 then
			bar.Size = targetSize
			Disconnect()
		end
	end)

	barUpdaters[bar] = barUpdater
end

local function UpdateXpBar()
	xpBarText.Text = xpBarCurrent.Value .. " / " .. xpBarMax.Value
	UpdateBar(xpBar, xpBarCurrent.Value / xpBarMax.Value)
end

local function InitUi()
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
end

-- Respawn
local function onCharacterAdded(character)
	-- print("Character Added")
	local humanoid2 = character.Humanoid -- :WaitForChild("Humanoid")

	-- Disable Fall
	humanoid2:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid2:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	-- Re-fetch UI elements on respawn
	uiInfos = player:WaitForChild("UIInfos")
	xpBarCurrent = uiInfos.XpBarCurrent -- :WaitForChild("XpBarCurrent")
	xpBarMax = uiInfos.XpBarMax -- :WaitForChild("XpBarMax")

	mainGui = playerGui:WaitForChild("MainGui")

	xpBarBg = mainGui.XpBarBG -- :WaitForChild("XpBarBG")
	xpBar = xpBarBg.XpBar -- :WaitForChild("XpBar")
	xpBarText = xpBarBg.XpBarText -- :WaitForChild("XpBarText")

	bananaText = mainGui.BananaNbrText -- :WaitForChild("BananaNbrText")

	levelText = mainGui.LevelText -- :WaitForChild("LevelText")
	levelUpButton = mainGui.LvlUpButton --:WaitForChild("LvlUpButton")

	stageProgressBar = mainGui.StageProgressBG.StageProgressBar
	currentStageText = mainGui.StageProgressBG.StageNbr

	cardGui = playerGui:WaitForChild("CardGui")
	rerollButton = cardGui.RerollButton -- :WaitForChild("RerollButton")
	cards = { cardGui.Card_01, cardGui.Card_02, cardGui.Card_03 } -- :WaitForChild("Card_01") :WaitForChild("Card_02") :WaitForChild("Card_03")
	cardTexts = { cards[1].TextLabel, cards[2].TextLabel, cards[3].TextLabel } -- :WaitForChild("TextLabel")

	InitUi()
end

-- Keybinds
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		DisplayAugments()
	end
end)

xpBarCurrent.Changed:Connect(UpdateXpBar)
xpBarMax.Changed:Connect(UpdateXpBar)

-- bananas.Changed:Connect(function()
-- 	bananaText.Text = bananas.Value
-- end)

Events.BananaPickup.OnClientEvent:Connect(function(bananasCount)
	bananaText.Text = bananasCount
end)

levelUpEvent.OnClientEvent:Connect(OnLevelUp)
levelUpButton.MouseButton1Click:Connect(DisplayAugments)

augmentPick.OnClientEvent:Connect(AugmentPickResponse)

Events.XpPickup.OnClientEvent:Connect(function()
	getXPSound:Play()
end)

Events.CurrentStageChanged.OnClientEvent:Connect(function(currentStage)
	-- currentStageText.Text = currentStage .. " / 5"
	nextStageTimer.Visible = true
end)

Events.NextStageTimerTick.OnClientEvent:Connect(function(currentTimer)
	nextStageTimer.Text = "Next Stage In : " .. currentTimer .. "s"

	if currentTimer == 0 then
		nextStageTimer.Visible = false
	end
end)

stageProgress.OnClientEvent:Connect(function(progress)
	UpdateBar(stageProgressBar, progress)
end)

InitUi()

player.CharacterAdded:Connect(onCharacterAdded)
