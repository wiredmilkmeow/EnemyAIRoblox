--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Stater = require(ReplicatedStorage.Packages.stater)
local FetchPathfindingType = require(script.Parent.Parent.FetchPathfindingType)
local Animate = require(script.Parent.Parent.Animate)
local Agent = require(script.Parent.Parent.Agent)

local Trove = require(ReplicatedStorage.Packages.trove)

local SharedTypes = require(script.Parent.Parent.SharedTypes)



local State = {}

type self = {
	Info : {
		_characterInfo : SharedTypes.CharacterInfo,
		_pathfinder : FetchPathfindingType.RobloxNavigationMesh,
		_animate : Animate.Animate,
		_agent : Agent.Agent,
		
		lostCount : number,
		
		_cleaner : Trove.Trove
	} & {any}
}

export type State = typeof(setmetatable({} :: self, {__index = Stater}))



function State.Init(self : State, characterInfo : SharedTypes.CharacterInfo) : boolean
	self.Info = {} :: any
	self.Info._cleaner = Trove.new()
	self.Info._characterInfo = characterInfo
	
	self.Info.lostCount = 0
	
	local pathfinder = FetchPathfindingType.Get(self.Info._characterInfo.PathingType)
	self.Info._pathfinder = pathfinder.new(self.Info._characterInfo, {})
	self.Info._animate = Animate.new(self.Info._characterInfo)
	self.Info._agent = Agent.new(self.Info._characterInfo, {})
	
	self.Info._cleaner:Add(function()
		self.Info._pathfinder:Destroy()
		self.Info._animate:Destroy()
		self.Info._agent:Destroy()
	end)
	
	self.Info._animate:StandardMovementAnimSystem(18924653990, 18924888684, 18924789934, 16)
	self.Info._pathfinder:ShowPath(true)
	
	return true
end


--first state to activate
function State.First(self : State) : boolean
	self:SetState("Idle")
	
	return true
end



function State.IdleStart(self : State) : boolean
	self.Info._pathfinder:Stop()
	
	return true
end

function State.IdleEnd(self : State) : boolean
	self.Info._pathfinder:Stop()
	return true
end

function State.Idle(self : State) : boolean
	local player, dist = self.Info._agent.playerFunctions.NearestPlayerInBounds(self.Info._characterInfo.Primary.Position, self.Info._agent._info.DetectDist)
	self.Info._agent:UpdateTarget(player and player or nil)
	
	if self.Info._agent.target and self.Info._agent:AgentSeesTarget() then
		self:SetState("Target")
	end
	
	local part, vectorAB = self.Info._agent:ClosestPart(self.Info._agent.Roots)--closest agent
	if part and vectorAB and vectorAB.Magnitude < (self.Info._agent._info.SpreadDist or 6) then
		local position = self.Info._pathfinder._goalPart.Position::Vector3 - (vectorAB.Unit::Vector3 * 2)--2 studs away from other agent
		self.Info._pathfinder._goalPart.Position = position
		self.Info._pathfinder:Toggle(true)

		local speed = self.Info._agent:CalcCollisionSpeed(self.Info._characterInfo.Humanoid.WalkSpeed, self.Info._agent._info.Speed or 8)
		self.Info._characterInfo.Humanoid.WalkSpeed = speed
	else
		self.Info._characterInfo.Humanoid.WalkSpeed = 0
	end
	
	return true
end



function State.TargetStart(self : State) : boolean
	self.Info._pathfinder:Stop()
	self.Info.lostCount = 0
	
	return true
end

function State.TargetEnd(self : State) : boolean
	self.Info._pathfinder:Stop()
	return true
end

function State.Target(self : State) : boolean
	local target:SharedTypes.PlayerInfo? = self.Info._agent.target
	
	local player, _ = self.Info._agent.playerFunctions.NearestPlayerInBounds(self.Info._characterInfo.Primary.Position, 5)
	
	if player then
		self:SetState("Attack")
	end
	
	if target and self.Info._pathfinder:GoalMagnitude() < self.Info._agent._info.DetectDist * 2 then
		
		local speed = self.Info._agent:CalcCollisionSpeed(self.Info._characterInfo.Humanoid.WalkSpeed, self.Info._agent._info.Speed or 8)
		self.Info._characterInfo.Humanoid.WalkSpeed = speed
		
		if not self.Info._agent:Obstructed(target.Primary.Position) and not self.Info._agent:CloseToObject() then
			self.Info._pathfinder:Toggle(false) -- turn off pathfinding
			self.Info._characterInfo.Humanoid:MoveTo(target.Primary.Position) --move directly to target
			
			self.Info.lostCount = 0
		else
			self.Info._pathfinder:Toggle(true) -- turn on pathfinding
			self.Info._pathfinder:MoveTo(target.Primary.Position) --pathfind to target
			
			self.Info.lostCount += 1
		end
	else
		self:SetState("Idle")
	end
	
	if target == nil then
		self:SetState("Idle")
	end
	
	if self.Info.lostCount > 100 then
		self:SetState("Idle")
	end

	return true
end

function State.AttackStart(self : State) : boolean
	self.Info._pathfinder:Stop()
	self.Info.lostCount = 0

	return true
end

function State.AttackEnd(self : State) : boolean
	self.Info._pathfinder:Stop()
	return true
end
--106799420474296
function State.Attack(self : State) : boolean
	local player, _ = self.Info._agent.playerFunctions.NearestPlayerInBounds(self.Info._characterInfo.Primary.Position, 5)
	local punchTrack = self.Info._animate:_loadTrack(106799420474296)
	
	if player and punchTrack then
		if not punchTrack.IsPlaying then
			
			punchTrack.Looped = false
			punchTrack:Play(0.2, 2, 1)
			
			task.delay(1, function()
				self.Info._agent.playerFunctions.DamagePlayer(player, 10)
			end)
		end
	else
		if punchTrack then
			punchTrack:Stop(0.2)
		end
		
		self:SetState("Target")
	end
	
	return true
end



function State.Exit(self : State) : boolean
	self.Info._cleaner:Destroy()
	
	print("Cleaned Up")

	return true
end

return State