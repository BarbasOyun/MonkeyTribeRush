--Weapon Server -> Dmg + Sounds
local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Events = require(ReplicatedStorage.Shared.Events)
local WeaponConfig = require(ReplicatedStorage.Shared.Modules.WeaponConfig)
local Gears = require(ReplicatedStorage.Shared.Gears)

--Remote Events
local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip
local attackHitEvent = Events.AttackHit

-- Players
local expectingAttack = {}

function FindHumanoidFromPart(part)
	local character = part.Parent

	if character then
		return character:FindFirstChild("Humanoid")
	end

	return nil
end

local function IncrementCombo(playerStat)
	playerStat.comboCount += 1

	if playerStat.comboCount > 1 then
		playerStat.comboCount = 0
	end

	if playerStat.comboReset then
		task.cancel(playerStat.comboReset)
	end

	playerStat.comboReset = task.delay(2, function()
		playerStat.ComboCount = 0
	end)
end

local function WeaponDamage(player)
	-- Check if The Call is Legit
	if not expectingAttack[player] then
		-- print("Unexpected AttackHit from player: " .. player.Name)
		return
	end

	local weaponInfo = PlayersStats[player].weaponInfo
	if not weaponInfo then
		return
	end

	local playerStat = PlayersStats[player]

	weaponInfo.sounds.slash:Play()
	player.Character.Humanoid.WalkSpeed = PlayersStats[player].mobility -- Reset WalkSpeed

	local function Hit()
		local attackPosition = weaponInfo.attackPoint.WorldCFrame
		Gears.DisplayHitBox(attackPosition, weaponInfo.range, 0.3)

		expectingAttack[player] = nil

		local hits = workspace:GetPartBoundsInRadius(attackPosition.Position, weaponInfo.range)
		local humanoidsHit = {}

		for _, hit in ipairs(hits) do
			--print("Hit Part: " .. hit.Name)
			local humanoid = FindHumanoidFromPart(hit)
			if humanoid and humanoid.Parent ~= player.Character and humanoidsHit[humanoid] == nil then
				humanoidsHit[humanoid] = true
				humanoid:TakeDamage(weaponInfo.damage)
				-- print(player.name .. " Dealt " .. weaponInfo.Damage .. " damage to " .. humanoid.Parent.Name)
			end
		end
	end

	IncrementCombo(playerStat)
	Hit()
end

local function Attack(player)
	-- Try to Attack using Player's Weapon
	local playerStat = PlayersStats[player]
	local weaponInfo = playerStat.weaponInfo
	if not playerStat or not weaponInfo then
		return
	end

	-- IsAttackReady
	local currentTime = tick()
	local attackDelta = currentTime - playerStat.lastAttack
	local missingTime = playerStat.animationTime - attackDelta

	local function StartAttack()
		-- print("Go Attack")
		playerStat.lastAttack = tick()

		-- print("Attack By : " .. player.Name)
		expectingAttack[player] = true
		player.Character.Humanoid.WalkSpeed *= 0.5
		attackEvent:FireClient(player, playerStat.comboCount + 1, weaponInfo.finalAttackSpeed) -- Animation
	end

	if attackDelta < playerStat.animationTime then
		-- Input Buffer
		if missingTime <= 0.1 then
			-- print("Attack Buffer: " .. player.Name)
			playerStat.lastAttack = currentTime -- Lock Input Buffer
			task.delay(missingTime, function()
				StartAttack()
			end)
		end

		return
	end

	StartAttack()
end

-- EVENTS SETUP
attackEvent.OnServerEvent:Connect(Attack)
attackHitEvent.OnServerEvent:Connect(WeaponDamage)

function OnEquipped(weapon, weaponInfo)
	local character = weapon.Parent
	local player = Players:GetPlayerFromCharacter(character)
	print(weapon.Name .. " Equipped by player: " .. player.Name)

	local playerStat = PlayersStats[player]
	playerStat.weaponInfo = weaponInfo
	PlayersStats.CalculateAttackSpeed(player)

	playerStat.weaponInfo.sounds.unsheath:Play()
	equipEvent:FireClient(player, true)
end

function OnUnequipped(weapon)
	local player = weapon.Parent.Parent -- Backpack

	if not player then
		return
	end

	PlayersStats[player].weaponInfo = nil
	print(weapon.Name .. " Unequipped by player: " .. player.Name)
	equipEvent:FireClient(player, false)
end

local function CreateWeaponInfo(weapon)
	local handle = weapon:WaitForChild("Handle")

	local weaponInfo = {
		weapon = weapon,
		handle = handle,
		attackPoint = weapon:WaitForChild("AttackPoint"),
		weaponType = WeaponConfig[weapon.Name].WeaponType,
		damage = WeaponConfig[weapon.Name].BaseDamage,
		range = WeaponConfig[weapon.Name].Range,
		attackSpeed = WeaponConfig[weapon.Name].AttackSpeed,
		finalAttackSpeed = WeaponConfig[weapon.Name].AttackSpeed,
		sounds = {
			unsheath = handle:WaitForChild("Unsheath"),
			slash = handle:WaitForChild("Slash"),
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

local function SetupWeaponInstances(weaponTag)
	for _, weapon in pairs(CollectionService:GetTagged(weaponTag)) do
		setupWeapon(weapon)
	end

	CollectionService:GetInstanceAddedSignal(weaponTag):Connect(setupWeapon)
end

SetupWeaponInstances("IronMace")
SetupWeaponInstances("IronAxe")
