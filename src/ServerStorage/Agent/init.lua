--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.trove)

local SharedTypes = require(script.Parent.SharedTypes)

local PlayerFunctions = require(script.PlayerFunctions)



local Agent = {}
Agent.__index = Agent
Agent.Roots = {} --roots of all agents in the game
Agent.parts = {} --parts of all agents in game

local Default = {}
Default.RayParams = RaycastParams.new()
Default.RayParams.IgnoreWater = true
Default.RayParams.FilterType = Enum.RaycastFilterType.Exclude

Default.Info = {
	Speed = 10,
	DetectDist = 30,
	CollisionRays = 8,
	CollisionDist = 2.2,
	SpreadDist = 6,
	VisualRange = 0.2,
	AgentCollision = "Enemy"	
} :: SharedTypes.AgentInfo<number, string>

type self = {
	_info : SharedTypes.AgentInfo<number, string>,
	_characterInfo : SharedTypes.CharacterInfo,
	_rayParams : RaycastParams,
	
	playerFunctions : PlayerFunctions.PlayerFunctions,
	
	target : SharedTypes.PlayerInfo?,
	_targetCleaner : Trove.Trove,
	
	_cleaner : Trove.Trove
} 

export type Agent = typeof(setmetatable({} :: self, Agent))



--[[
constructor
]]
function Agent.new(characterInfo : SharedTypes.CharacterInfo, agentInfo : SharedTypes.AgentInfo<number?, string?>) : Agent
	
	local self = setmetatable({} :: self, Agent)
	self._cleaner = Trove.new()
	
	self._info = {
		Speed = agentInfo.Speed or Default.Info.Speed,
		DetectDist = agentInfo.DetectDist or Default.Info.DetectDist,
		SpreadDist = agentInfo.SpreadDist or Default.Info.SpreadDist,
		VisualRange = agentInfo.VisualRange or Default.Info.VisualRange,
		CollisionRays = agentInfo.CollisionRays or Default.Info.CollisionRays,
		CollisionDist = agentInfo.CollisionDist or Default.Info.CollisionDist,
		AgentCollision = agentInfo.AgentCollision or Default.Info.AgentCollision
	}
	
	self._characterInfo = characterInfo
	self._rayParams = Default.RayParams
	
	self.playerFunctions = PlayerFunctions
	self.target = nil
	
	
	
	self._cleaner:Add(function()
		self:SetCollisionGroup("Default")
		self._characterInfo.Primary:SetNetworkOwnershipAuto()
	end)
	
	self:SetCollisionGroup(self._info.AgentCollision)
	self._characterInfo.Primary:SetNetworkOwner(nil)
	
	table.insert(Agent.Roots, self._characterInfo.Primary)
	table.insert(Agent.parts, self:GetAgentParts())
	
	return self
end

--[[
get the parts of the agent
]]
function Agent.GetAgentParts(self : Agent) : {Instance?}
	return self._characterInfo.Model:GetDescendants()
end

--[[
updates the target to the given player
]]
function Agent.UpdateTarget(self : Agent, player : Player?)
	
	if player and PlayerFunctions.IsAlive(player) and player.Character then
		local character = player.Character
		local primary  = character:FindFirstChild("HumanoidRootPart") :: BasePart
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
		local animator = character:FindFirstChild("Animator", true) :: Animator
		
		if primary and humanoid and animator then
			
			if self._targetCleaner then --cleanup when new target
				self._targetCleaner:Destroy()
			end
			self._targetCleaner = self._cleaner:Extend() --new cleaner connected to main cleaner
			
			--wont detect if instance is destyoed so have to use event
			self._targetCleaner:Connect(humanoid.Died, function()
				self._targetCleaner:Destroy()
			end)
			
			self._targetCleaner:Add(function() --clear target on remove
				self.target = nil
			end)
			
			
			self.target = { --target information
				Player = player,
				Model  = character,
				Primary  = primary,
				Humanoid = humanoid,
				Animator = animator
			}
			
		else
			self.target = nil
		end
		
	else
		self.target = nil
	end
end

--[[
sets collision group for agent
]]
function Agent.SetCollisionGroup(self : Agent, group : string)
	for _, inst in pairs(self:GetAgentParts()) do
		if inst and inst:IsA("BasePart") then 
			inst.CollisionGroup = group
		end
	end
end

--[[
excludes agent or players, or both when raycasting
]]
function Agent.AvoidParams(self : Agent, paramType : "Agents" | "Players" | "Both") : RaycastParams
	local params = self._rayParams
	
	if paramType == "Agents" then
		params.FilterDescendantsInstances = {Agent.parts :: any}
	elseif paramType == "Players" then
		params.FilterDescendantsInstances = {PlayerFunctions.GetParts() :: any}
	elseif paramType == "Both" then
		params.FilterDescendantsInstances = {Agent.parts :: any, PlayerFunctions.GetParts() :: any}
	end
	
	return params
end

--[[
used to help prevent agents from colliding with eachother
uses random because small variations in speed help agents that are too close to seperate from eachother
]]
function Agent.CalcCollisionSpeed(self : Agent, currentSpeed : number, maxSpeed : number) : number
	local part, vectorAB = self:ClosestPart(Agent.Roots)
	
	local adjust = Random.new():NextNumber() * 0.3
	if not part or not vectorAB or (vectorAB.Magnitude > self._info.SpreadDist) then return currentSpeed + (maxSpeed - currentSpeed) * adjust end
	local inSight, product = self:PosInSightOfCord(self._characterInfo.Primary.CFrame, part.Position)
	local percent = (1 - product)/2
	local speed = maxSpeed * percent

	return currentSpeed + (speed - currentSpeed) * adjust
end

--[[
is agent close to collidable object?
]]
function Agent.CloseToObject(self : Agent, distance : number?) : RaycastResult?
	local distance = distance or self._info.CollisionDist

	local params = self:AvoidParams("Both")
	local radinsPerRay = (math.pi * 2)/self._info.CollisionRays
	for i=1, self._info.CollisionRays do
		local direction = Vector3.new(math.cos(radinsPerRay * i), 0, math.sin(radinsPerRay * i))
		local ray = workspace:Raycast(self._characterInfo.Primary.Position, direction * distance, params)
		if ray then return ray end
	end

	return nil
end

--[[
direction that has the most distance/space from the others
]]
function Agent.OpenDirection(self : Agent) : (Vector3, number)
	local bestDirection, bestDist = nil, 0
	local distance = 100

	local params = self:AvoidParams("Both")
	local radinsPerRay = (math.pi * 2)/self._info.CollisionRays
	for i = 1, self._info.CollisionRays do
		local direction = Vector3.new(math.cos(radinsPerRay * i), 0, math.sin(radinsPerRay * i))
		local ray = workspace:Raycast(self._characterInfo.Primary.Position, direction * distance, params)

		if ray then
			if ray.Distance < bestDist then continue end
			bestDist = ray.Distance
			bestDirection = direction
		else
			bestDist = distance 
			bestDirection = direction
		end
	end

	return bestDirection, bestDist
end

--[[
is it possible for agent to see this position?
]]
function Agent.Obstructed(self : Agent, position : Vector3) : RaycastResult?
	local params = self:AvoidParams("Both")
	local direction = (position - self._characterInfo.Primary.Position)-- keep magnitude
	return workspace:Raycast(self._characterInfo.Primary.Position, direction, params)
end

--[[
angle relation of a cordinate and position/dot product
]]
function Agent.PosInSightOfCord(self : Agent, cord : CFrame, pos2 : Vector3, range : number?) : (boolean, number)
	local range = range or self._info.VisualRange
	local direction = (pos2 - cord.Position).Unit
	local product = direction:Dot(cord.LookVector)
	return product > range, product
end

--[[
is target in line of sight with no obstructions?
]]
function Agent.AgentSeesTarget(self : Agent) : boolean
	if not self.target then return false end
	local result = self:Obstructed(self.target.Primary.Position)
	local inSight, product = self:PosInSightOfCord(self._characterInfo.Primary.CFrame, self.target.Primary.Position)
	
	if not result and inSight then
		return true
	else
		return false
	end
end

--[[
is position in line of sight with no obstructions?
]]
function Agent.AgentSeesPosition(self : Agent, position : Vector3) : boolean
	local result = self:Obstructed(position)
	local inSight, product = self:PosInSightOfCord(self._characterInfo.Primary.CFrame, position)

	if not result and inSight then
		return true
	else
		return false
	end
end

--[[
is agent in line of sight with no obstructions?
]]
function Agent.TargetSeesAgent(self : Agent) : boolean
	if not self.target then return false end
	local result = self:Obstructed(self.target.Primary.Position)
	local inSight, product = self:PosInSightOfCord(self.target.Primary.CFrame, self._characterInfo.Primary.Position)

	if not result and inSight then
		return true
	else
		return false
	end
end

--[[
similar to AgentSeesTarget but accounts for all players
]]
function Agent.PlayersSeeAgent(self : Agent) : {BasePart?}
	local roots = {}

	for _, root in pairs(PlayerFunctions.GetRoots() :: {BasePart}) do
		local inSight, product = self:PosInSightOfCord(root.CFrame, self._characterInfo.Primary.Position)
		local result = self:Obstructed(root.Position)
		
		if not result and inSight then
			table.insert(roots, root)
		end

	end

	return roots
end

--[[
returns closest parts from table of baseparts
]]
function Agent.ClosestPart(self : Agent, parts : {BasePart}) : (BasePart?, Vector3?)
	local bestPart, bestVector = nil, Vector3.new(1, 1, 1) * math.huge

	for i, part in pairs(parts) do
		if table.find(self:GetAgentParts(), part) then continue end--exclude agent parts from table
		
		local vectorAB = (part.Position - self._characterInfo.Primary.Position)
		if vectorAB.Magnitude < bestVector.Magnitude then
			bestPart, bestVector = part, vectorAB
		end
	end

	return bestPart, bestVector
end

--[[
cleanup everything
]]
function Agent.Destroy(self : Agent)
	self._cleaner:Destroy()
	self = nil :: any
end

return Agent