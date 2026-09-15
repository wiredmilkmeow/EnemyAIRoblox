--!strict

--[[
fetch specific state machine
]]

local FetchEnemyType = {}

local SharedTypes = require(script.Parent.SharedTypes)

function FetchEnemyType.Get(enemyType : SharedTypes.EnemyTypes) : {Init : () -> (), First : () -> (), Exit : () -> ()}
	local module = script:FindFirstChild(enemyType)
	assert(module, "Could not find module named "..enemyType..".")
	
	return require(module) :: any
end

return FetchEnemyType