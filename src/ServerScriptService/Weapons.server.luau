--Made by Luckymaxer
--Updated for R15 avatar by StarWars
--Updated by RedRocStudio for Monkey Tribe Rush

--Weapon Server -> Dmg + Sounds
local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Events = require(ReplicatedStorage.Shared.Events)
local WeaponConfig = require(ReplicatedStorage.Shared.Modules.WeaponConfig)
local gizmo = require(ReplicatedStorage.Shared.gizmo)

--Remote Events
local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip
local attackHitEvent = Events.AttackHit

-- Players
local PlayersWeaponInfo = {}

function OnEquipped(weapon, WeaponInfo)
	local character = weapon.Parent
	local player = Players:GetPlayerFromCharacter(character)
	print(weapon.Name .. " Equipped by player: " .. player.Name)

	PlayersWeaponInfo[player] = WeaponInfo

	PlayersWeaponInfo[player].Sounds.Unsheath:Play()
	equipEvent:FireClient(player, true)
end

function OnUnequipped(weapon)
	local player = weapon.Parent.Parent -- Backpack

	if not player then
		return
	end

	PlayersWeaponInfo[player] = nil
	print(weapon.Name .. " Unequipped by player: " .. player.Name)
	equipEvent:FireClient(player, false)
end

function FindHumanoidFromPart(part)
	local character = part.Parent
	if character then
		return character:FindFirstChild("Humanoid")
	end
	return nil
end

local function DisplayHitBox(cFrame, Range)
	local drawSphere = RunService.Heartbeat:Connect(function()
		--print("Draw Sphere Gizmo")
		gizmo.setColor("Bright red")
		gizmo.setTransparency(0.5)
		gizmo.drawSphere(cFrame, Range)
		gizmo.reset()
	end)

	task.delay(0.5, function()
		drawSphere:Disconnect()
	end)
end

local function WeaponDamage(player)
	local weaponInfo = PlayersWeaponInfo[player]
	if not weaponInfo then
		return
	end

	PlayersWeaponInfo[player].Sounds.Slash:Play()
	player.Character.Humanoid.WalkSpeed = PlayersStats[player].Mobility

	--Hit + Damage
	DisplayHitBox(weaponInfo.AttackPoint.WorldCFrame, weaponInfo.Range)
	local hits = workspace:GetPartBoundsInRadius(weaponInfo.AttackPoint.WorldPosition, weaponInfo.Range)
	local humanoidsHit = {}
	for _, hit in ipairs(hits) do
		--print("Hit Part: " .. hit.Name)
		local humanoid = FindHumanoidFromPart(hit)
		if humanoid and humanoid.Parent ~= player.Character and humanoidsHit[humanoid] == nil then
			humanoidsHit[humanoid] = true
			humanoid:TakeDamage(weaponInfo.Damage)
			print(player.name .. " Dealt " .. weaponInfo.Damage .. " damage to " .. humanoid.Parent.Name)
		end
	end
end

local function Attack(player)
	-- Try to Attack using Player's Weapon
	local weaponInfo = PlayersWeaponInfo[player]
	if not weaponInfo then
		return
	end

	-- IsAttackReady
	local currentTime = tick()
	if weaponInfo.lastAttack and currentTime - weaponInfo.lastAttack < weaponInfo.AttackSpeed then
		return
	end
	weaponInfo.lastAttack = currentTime

	-- print("Attack By : " .. player.Name)
	player.Character.Humanoid.WalkSpeed *= 0.5
	attackEvent:FireClient(player)
end

-- EVENTS SETUP
attackEvent.OnServerEvent:Connect(Attack)
attackHitEvent.OnServerEvent:Connect(WeaponDamage)

local function CreateWeaponInfo(weapon)
	local handle = weapon:WaitForChild("Handle")

	local weaponInfo = {
		Weapon = weapon,
		Handle = handle,
		AttackPoint = weapon:WaitForChild("AttackPoint"),
		WeaponType = WeaponConfig[weapon.Name].WeaponType,
		Damage = WeaponConfig[weapon.Name].BaseDamage,
		Range = WeaponConfig[weapon.Name].Range,
		AttackSpeed = WeaponConfig[weapon.Name].AttackSpeed,
		lastAttack = 0,
		Sounds = {
			Unsheath = handle:WaitForChild("Unsheath"),
			Slash = handle:WaitForChild("Slash"),
		},
	}

	return weaponInfo
end

local function setupWeapon(weapon)
	-- Create Weapon Info
	local weaponInfo = CreateWeaponInfo(weapon)

	weapon.Equipped:Connect(function()
		OnEquipped(weapon, weaponInfo)
	end)

	weapon.Unequipped:Connect(function()
		OnUnequipped(weapon)
	end)
end

local function SetupWeaponInstances(WeaponTag)
	for _, weapon in pairs(CollectionService:GetTagged(WeaponTag)) do
		setupWeapon(weapon)
	end

	CollectionService:GetInstanceAddedSignal(WeaponTag):Connect(setupWeapon)
end

SetupWeaponInstances("IronMace")
SetupWeaponInstances("IronAxe")
