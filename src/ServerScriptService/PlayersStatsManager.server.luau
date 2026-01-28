local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local function ApplyStat(player)
	local PlayerStat = PlayersStats[player]
	local Character = player.Character or player.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")

	Humanoid.MaxHealth = PlayerStat.Health
	Humanoid.WalkSpeed = PlayerStat.Mobility
end

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game!")
	PlayersStats.createPlayer(player)
	ApplyStat(player)
end)
