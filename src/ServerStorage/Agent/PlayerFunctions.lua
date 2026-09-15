--!strict

--[[
May make more sense to have this module be part of the agent module instead.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")



local PlayerFunctions = {}

export type PlayerFunctions = typeof(PlayerFunctions)

--is player alive
function PlayerFunctions.IsAlive(player : Player) : boolean
	
	local function hasHealth() -- for default roblox system
		local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid") :: Humanoid or nil
		if not humanoid then return false end
		
		return humanoid.Health > 0
	end
	
	local function AliveAttribute() -- for custom system
		return player:GetAttribute("Alive") and true or nil
	end
	
	return AliveAttribute() or hasHealth() or false
end

--get roots of all players
function PlayerFunctions.GetRoots() : {Instance?}
	local roots = {}
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and PlayerFunctions.IsAlive(player) then
			table.insert(roots, player.Character.PrimaryPart)
		end
	end

	return roots
end

--get parts of all players
function PlayerFunctions.GetParts() : {Instance?}
	local parts = {}
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and PlayerFunctions.IsAlive(player) then
			table.insert(parts, player.Character:GetDescendants())
		end
	end

	return parts
end

--player distance from point
function PlayerFunctions.Distance(player : Player, position : Vector3) : number
	if not player.Character or not PlayerFunctions.IsAlive(player) then return math.huge end
	local root = player.Character.PrimaryPart :: BasePart
	if not root then return math.huge end
	return (position - root.Position).Magnitude
end

--nearest player and distance from position
function PlayerFunctions.NearestPlayer(position : Vector3) : (Player?, number)
	local bestPlayer, bestDist = nil, math.huge

	for _, player in pairs(Players:GetPlayers()) do
		local distance = PlayerFunctions.Distance(player, position)
		if distance < bestDist then
			bestDist = distance
			bestPlayer = player
		end
	end

	return bestPlayer, bestDist
end

--nearest player and distance from position
function PlayerFunctions.NearestPlayerInBounds(position : Vector3, bounds : number) : (Player?, number)
	local player, dist = PlayerFunctions.NearestPlayer(position)
	
	if dist <= bounds then
		return player, dist
	else
		
		return nil, math.huge
	end
end

--damage nearest player in radius
function PlayerFunctions.DamagePlayerInBounds(position : Vector3, distance : number, damage : number)
	local player, dist = PlayerFunctions.NearestPlayer(position)

	if player and dist < distance then
		PlayerFunctions.DamagePlayer(player, damage)
	end
end

--damage player
function PlayerFunctions.DamagePlayer(player : Player, damage : number)
	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid") :: Humanoid
		humanoid:TakeDamage(damage)
	end
end

return PlayerFunctions