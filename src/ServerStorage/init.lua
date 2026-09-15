--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stater = require(ReplicatedStorage.Packages.stater)
local Trove = require(ReplicatedStorage.Packages.trove)

local SharedTypes = require(script.SharedTypes)

local FetchEnemyType = require(script.FetchEnemyType)
local FetchPathfindingType = require(script.FetchPathfindingType)



local EnemyAI = {}
EnemyAI.__index = EnemyAI
EnemyAI.TAG_NAME = "EnemyAI"

type self = {
	_characterInfo : SharedTypes.CharacterInfo,
	_stater : Stater.Stater,
	_cleaner : Trove.Trove
}

type EnemyAI = typeof(setmetatable({} :: self, EnemyAI))

function EnemyAI.new(model : Model) : EnemyAI
	
	local enemyType = model:GetAttribute("EnemyType") or "Default"
	assert(FetchEnemyType.Get(enemyType), "Could not find Correct EnemyType in EnemyAI, " .. model:GetFullName())
	
	local pathingType = model:GetAttribute("PathingType") or "RobloxNavigationMesh"
	assert(FetchPathfindingType.Get(pathingType), "Could not find Correct PathingType in EnemyAI, " .. model:GetFullName())
	
	local primary = model.PrimaryPart :: BasePart
	assert(primary, "Could not find primay part in EnemyAI, " .. model:GetFullName())
	
	local humanoid = model:FindFirstChildWhichIsA("Humanoid") :: Humanoid
	assert(humanoid, "Could not find humanoid in EnemyAI, " .. model:GetFullName())
	
	local animator = model:FindFirstChildWhichIsA("Animator", true) :: Animator
	assert(animator, "Could not find animator in EnemyAI, " .. model:GetFullName())
	
	
	
	local self = setmetatable({} :: self, EnemyAI)
	self._cleaner = Trove.new()
	
	self._characterInfo = {
		EnemyType = enemyType,
		PathingType = pathingType,

		Model  = model,

		Primary = primary,
		Humanoid = humanoid,
		Animator = animator
	}
	
	self:_init()
	
	return self
end

function EnemyAI._init(self:EnemyAI)
	local enemyStates = FetchEnemyType.Get(self._characterInfo.EnemyType)
	
	self._stater = Stater.new(enemyStates, 0.1)
	self._stater:Start("First", self._characterInfo)
	
	self._cleaner:Add(function()
		self._stater:Destroy()
	end)
end

function EnemyAI.Cleanup(self:EnemyAI)
	self._cleaner:Destroy()
	self = nil::any
end



--COLLECTION---------------------------------------------------------------------------

local instances = {}

local instanceAddedSignal = CollectionService:GetInstanceAddedSignal(EnemyAI.TAG_NAME)
local instanceRemovedSignal = CollectionService:GetInstanceRemovedSignal(EnemyAI.TAG_NAME)

local function onInstanceAdded(instance)
	if instance:IsA("Model") then
		instances[instance] = EnemyAI.new(instance)
	end
end

local function onInstanceRemoved(instance : Instance)
	instances[instance :: any]:Cleanup()
end

task.wait(1) --let children load
for _, instance in pairs(CollectionService:GetTagged(EnemyAI.TAG_NAME)) do
	task.spawn(onInstanceAdded, instance)
end
instanceAddedSignal:Connect(onInstanceAdded)
instanceRemovedSignal:Connect(onInstanceRemoved)

return {}