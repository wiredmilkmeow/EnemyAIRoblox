--!strict

--[[
roblox doesnt have dynamic return types so both pathfinders have to have the exact same layout as far as i know
]]

local FetchPathfindingType = {}

local SharedTypes = require(script.Parent.SharedTypes)

local RobloxNavigationMesh =  require(script.RobloxNavigationMesh)
local AStar = require(script.AStar)

export type RobloxNavigationMesh = RobloxNavigationMesh.Pathfinding

function FetchPathfindingType.Get(pathingType : SharedTypes.PathTypes) : RobloxNavigationMesh.Pathfinding
	
	if pathingType == "RobloxNavigationMesh" then
		return RobloxNavigationMesh :: any
	elseif pathingType == "AStar" then
		return AStar :: any
	else
		warn("Could not find PathingType called ", pathingType)
		return RobloxNavigationMesh :: any
	end
end

return FetchPathfindingType