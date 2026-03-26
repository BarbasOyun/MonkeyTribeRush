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
local playerGui = player:WaitForChild("PlayerGui")

local uiInfos = player:WaitForChild("UIInfos")
local xpBarCurrent = uiInfos.XpBarCurrent
local xpBarMax = uiInfos.XpBarMax
local bananas = uiInfos.Bananas
local sticks = uiInfos.Sticks

-- Main UI
local mainGui = playerGui:WaitForChild("MainGui")
local barUpdaters = {}
local deathUI = mainGui.DeathUI

-- Player Data
local levelText = mainGui.LevelText
local levelUpButton = mainGui.LvlUpButton

local xpBarBg = mainGui.XpBarBG
local xpBar = xpBarBg.XpBar
local xpBarText = xpBarBg.XpBarText

local bananaText = mainGui.BananaNbrText
local sticksText = mainGui.StickNbrText

-- Stage
local stageProgressBG = mainGui.StageProgressBG
local stageProgressBar = stageProgressBG.StageProgressBar
local swarmSkull = ReplicatedStorage.Prefabs.SwarmSkull
local nextStageTimer = mainGui.NextStageTimer
local robotLvlText = mainGui.RobotIcon.RobotLvlText

-- Augments
local cardGui = playerGui:WaitForChild("CardGui")
local rerollButton = cardGui.RerollButton
local cards = { cardGui.Card_01, cardGui.Card_02, cardGui.Card_03 }
local cardTexts = { cards[1].TextLabel, cards[2].TextLabel, cards[3].TextLabel }
local blur = nil

-- Sounds
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

	if not blur then
		local lighting = game.Lighting -- :WaitForChild("Lighting")
		blur = Instance.new("BlurEffect")
		blur.Size = 10
		blur.Parent = lighting
	end

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

local function SetupStageEventsUI(stageEventsNbr)
	-- print("Create " .. stageEventsNbr .. " Events")
	local adjusted = stageEventsNbr + 1
	for i = 1, stageEventsNbr, 1 do
		local swarmIcon = swarmSkull:clone()
		swarmIcon.Parent = stageProgressBG
		swarmIcon.Position = UDim2.new(i / adjusted - 0.04, -0.3) -- 0.04 = Half Skull XSize
	end
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
local function OnCharacterAdded(character)
	-- print("Character Added")
	local humanoid2 = character.Humanoid

	-- Disable Fall
	humanoid2:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid2:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	-- Re-fetch UI elements on respawn
	-- Player
	uiInfos = player:WaitForChild("UIInfos")
	xpBarCurrent = uiInfos.XpBarCurrent
	xpBarMax = uiInfos.XpBarMax

	mainGui = playerGui:WaitForChild("MainGui")

	deathUI = mainGui.DeathUI
	deathUI.Visible = false

	xpBarBg = mainGui.XpBarBG
	xpBar = xpBarBg.XpBar
	xpBarText = xpBarBg.XpBarText

	levelText = mainGui.LevelText
	levelUpButton = mainGui.LvlUpButton

	cardGui = playerGui:WaitForChild("CardGui")
	rerollButton = cardGui.RerollButton
	cards = { cardGui.Card_01, cardGui.Card_02, cardGui.Card_03 }
	cardTexts = { cards[1].TextLabel, cards[2].TextLabel, cards[3].TextLabel }

	-- Stage
	stageProgressBG = mainGui.StageProgressBG
	stageProgressBar = mainGui.StageProgressBG.StageProgressBar
	swarmSkull = ReplicatedStorage.Prefabs.SwarmSkull
	bananaText = mainGui.BananaNbrText
	robotLvlText = mainGui.RobotIcon.RobotLvlText

	-- Sounds
	levelUpSound = playerGui.Sounds.LvlUp
	augmentMenuSound = playerGui.Sounds.AugmentMenu
	augmentPickSound = playerGui.Sounds.AugmentPick
	getXPSound = playerGui.Sounds.GetXp

	-- Update new UI
	Events.GetFullStageData:FireServer()

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

-- Player Events
player.CharacterAdded:Connect(OnCharacterAdded)

xpBarCurrent.Changed:Connect(UpdateXpBar)
xpBarMax.Changed:Connect(UpdateXpBar)
Events.XpPickup.OnClientEvent:Connect(function()
	getXPSound:Play()
end)

levelUpEvent.OnClientEvent:Connect(OnLevelUp)
levelUpButton.MouseButton1Click:Connect(DisplayAugments)

augmentPick.OnClientEvent:Connect(AugmentPickResponse)

-- Bananas
bananas.Changed:Connect(function()
	bananaText.Text = bananas.Value
end)

sticks.Changed:Connect(function()
	sticksText.Text = sticks.Value
end)

-- Death
Events.PlayerDied.OnClientEvent:Connect(function()
	deathUI.Visible = true
end)

-- Stage Events

-- Get Full Stage Data -> StageEvents, StageProgress, Bananas, EnemiesLevel
Events.GetFullStageData.OnClientEvent:Connect(function(stageEventsNbr, stageBarProgress, globalEnemiesLevel)
	SetupStageEventsUI(stageEventsNbr)
	UpdateBar(stageProgressBar, stageBarProgress)
	robotLvlText.Text = "Lvl " .. globalEnemiesLevel
end)

-- StageEvents
Events.StageData.OnClientEvent:Connect(function(stageEventsNbr)
	SetupStageEventsUI(stageEventsNbr)
end)

-- Stage Progress
stageProgress.OnClientEvent:Connect(function(progress)
	UpdateBar(stageProgressBar, progress)
end)

-- Enemies Lvl
Events.EnemyLevelUp.OnClientEvent:Connect(function(globalEnemiesLevel)
	robotLvlText.Text = "Lvl " .. globalEnemiesLevel
end)

Events.CurrentStageChanged.OnClientEvent:Connect(function(currentStage)
	nextStageTimer.Text = "Next Stage In 10s"
	nextStageTimer.Visible = true
end)

Events.NextStageTimerTick.OnClientEvent:Connect(function(currentTimer)
	nextStageTimer.Text = "Next Stage In : " .. currentTimer .. "s"

	if currentTimer == 0 then
		nextStageTimer.Visible = false
	end
end)

InitUi()
