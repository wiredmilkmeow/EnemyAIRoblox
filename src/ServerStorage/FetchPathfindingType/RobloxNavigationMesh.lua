--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Trove = require(ReplicatedStorage.Packages.trove)

local SharedTypes = require(script.Parent.Parent.SharedTypes)



local Pathfinding = {}
Pathfinding.__index = Pathfinding

Pathfinding.PathReadjustRate = 1 --seconds
Pathfinding.ErrorWarnRetry = 20 --errorCount

Pathfinding.PartsFolder = Instance.new("Folder")
Pathfinding.PartsFolder.Name = "RobloxNavigationMeshParts"
Pathfinding.PartsFolder.Parent = workspace
Pathfinding.PartsFolder:AddTag("KeepOnRun")



Pathfinding.PathfindingInfoDefault = {
	AgentRadius = 3,
	AgentHeight = 6,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 2,
	Costs = {
		Avoid = math.huge,
		Follow = 0.1,
		Door = 100
	}
} :: SharedTypes.PathfindingInfo



type self = {
	type : "RobloxNavigationMesh",
	
	_pathfindingInfo : SharedTypes.PathfindingInfo,
	_characterInfo : SharedTypes.CharacterInfo,
	
	_path : Path,
	_pathing : boolean,
	_goalPart : BasePart,
	_showPath : boolean,
	_errorCount : number,
	
	_visualParts : Trove.Trove,
	
	_runConnection:RBXScriptConnection?,
	_moveConnection:RBXScriptConnection?,
	
	_cleaner : Trove.Trove
}

export type Pathfinding = typeof(setmetatable({} :: self, Pathfinding))



--constructor
function Pathfinding.new(characterInfo : SharedTypes.CharacterInfo, pathfindingInfo : SharedTypes.PathfindingInfo?) : Pathfinding
	assert(typeof(characterInfo) == "table", typeof(characterInfo).." is not a characterInfo table.")
	assert(typeof(pathfindingInfo) == "table" or pathfindingInfo == nil, typeof(Pathfinding).." is not a pathfindingInfo table or nil.")
	
	local self = setmetatable({} :: self, Pathfinding)
	self._cleaner = Trove.new()
	
	self._characterInfo = characterInfo
	self._pathfindingInfo = (pathfindingInfo and setmetatable(pathfindingInfo, Pathfinding.PathfindingInfoDefault) or Pathfinding.PathfindingInfoDefault) :: SharedTypes.PathfindingInfo
	
	self._goalPart = self:NewPart("Goal")
	self._pathing = false
	self._showPath = false
	self._errorCount = 0
	
	self:_setPathInfo(self._pathfindingInfo)
	
	return self
end



function Pathfinding._setPathInfo(self : Pathfinding, pathfindingInfo : SharedTypes.PathfindingInfo)
	self._path = PathfindingService:CreatePath(pathfindingInfo :: {[string] : any})
end

--ball part with multiple purposes
function Pathfinding.NewPart(self : Pathfinding, name : string) : BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.one
	part.CanTouch = false
	part.CanCollide = false
	part.CanQuery = false
	part.Shape = Enum.PartType.Ball
	part.Locked = true
	part.CastShadow = false
	part.Transparency = 1
	part.Anchored = true
	part.Material = Enum.Material.Neon
	part.Color = Color3.new(0, 1, 0)
	part.Parent = Pathfinding.PartsFolder
	
	return part
end



-- will attempt to reach goal through pathfinding if running
function Pathfinding.MoveTo(self : Pathfinding, destination : Vector3)
	assert(typeof(destination) == "Vector3", typeof(destination).." is not a Vector3.")
	self._goalPart.Position = destination
end

-- visual show destination for debugging
function Pathfinding.ShowPath(self : Pathfinding, show : boolean)
	assert(typeof(show) == "boolean", typeof(show).." is not boolean.")
	
	self._showPath = show
end

-- teleports the agent to given position
function Pathfinding.PivotAgent(self : Pathfinding, cordinate : CFrame)
	assert(typeof(cordinate) == "CFrame", typeof(cordinate).." is not a CFrame.")
	
	self:Stop()
	self._characterInfo.Primary:PivotTo(cordinate)
	self._goalPart.Position = cordinate.Position
end

-- will run or stop pathfinding depending on input
-- used to stop the run and stop methods from being called multiple times
function Pathfinding.Toggle(self : Pathfinding, on : boolean)
	assert(typeof(on) == "boolean", typeof(on).." is not boolean.")
	
	if on == self._pathing then return end
	
	if on then
		self:Run()
	else
		self:Stop()
	end
end

-- follows current path
function Pathfinding.Run(self : Pathfinding)
	self:Stop()
	self._pathing = true

	self:_setPathInfo(self._pathfindingInfo)
	
	local prevTime = 0
	self._runConnection = RunService.Heartbeat:Connect(function()
		if time() - prevTime < Pathfinding.PathReadjustRate then return end
		prevTime = time()
		
		self:_attemptPath(self._goalPart.Position)
	end)
end

--stop following current path
function Pathfinding.Stop(self : Pathfinding)
	self._pathing = false
	self._errorCount = 0

	self._goalPart.Position = self._characterInfo.Primary.Position
	self._characterInfo.Humanoid:MoveTo(self._characterInfo.Primary.Position)

	if self._runConnection then
		self._runConnection:Disconnect()
	end

	if self._moveConnection then
		self._moveConnection:Disconnect()
	end
	
	if self._visualParts then
		self._visualParts:Destroy()
	end
end

--compute path to goal
function Pathfinding._computeAsync(self : Pathfinding) : Path?
	if not self._path then
		self:_setPathInfo(self._pathfindingInfo)
	end
	
	local newPath:Path = self._path
	
	local success = pcall(function()
		newPath:ComputeAsync(self._characterInfo.Primary.Position, self._goalPart.Position)
	end)

	if success then
		return newPath
	else
		warn("could not compute path, ", self._characterInfo.Model:GetFullName())
		return nil
	end
end

function Pathfinding._displayPath(self : Pathfinding, path : Path)
	if self._visualParts then
		self._visualParts:Destroy()
	end
	self._visualParts = self._cleaner:Extend()
	
	task.delay(Pathfinding.PathReadjustRate + 5, function()
		if self._visualParts then
			self._visualParts:Destroy()
		end
	end)
	
	local waypoints = path:GetWaypoints()
	for i, waypoint in pairs(waypoints) do
		local part = self._visualParts:Add(self:NewPart("waypoint"))
		part.Transparency = 0.5
		part.Position = waypoint.Position
		part.Size = Vector3.one * 0.5
		
		if i == #waypoints then
			part.Color = Color3.new(1, 1, 1)
			part.Size = Vector3.one
		end
	end
end

--moves humanoid to goal
function Pathfinding._attemptPath(self : Pathfinding, goalPos : Vector3)
	local path = self:_computeAsync()
	if not path then return end
	
	self:_displayPath(path)

	local function goTo(waypoints : {PathWaypoint})
		if self._moveConnection then
			self._moveConnection:Disconnect()
		end

		if #waypoints < 2 then return end
		local nextWaypointIndex = 2

		self._moveConnection = self._characterInfo.Humanoid.MoveToFinished:Connect(function(reached : boolean)
			if reached and nextWaypointIndex < #waypoints then
				nextWaypointIndex += 1
				
				self._characterInfo.Humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
			else
				if self._moveConnection then
					self._moveConnection:Disconnect()
				end
			end
		end)

		self._characterInfo.Humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
	end
	
	local waypoints = path:GetWaypoints()
	if path.Status == Enum.PathStatus.Success then
		self._errorCount = 0
		goTo(waypoints)
	else
		self._errorCount += 1
	end
	
	if self._errorCount >= Pathfinding.ErrorWarnRetry and self._errorCount % Pathfinding.ErrorWarnRetry == 0 then
		warn("Pathfinding is currently obstructed, ", self._characterInfo.Model:GetFullName())
	end
end

-- the linear distance to current goal
function Pathfinding.GoalMagnitude(self : Pathfinding) : number
	return (self._characterInfo.Primary.Position - self._goalPart.Position).Magnitude
end

-- the distance of the current path
function Pathfinding.GoalDist(self : Pathfinding) : number
	if not self._path then return 0 end
	
	local waypoints = self._path:GetWaypoints()
	if #waypoints < 2 then return 0 end
	
	local distance = self._pathfindingInfo.WaypointSpacing or 2
	return (distance * #waypoints) - distance
end



--cleanup everything
function Pathfinding.Destroy(self : Pathfinding)
	self._cleaner:Destroy()
	self = nil :: any
end

return Pathfinding