--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.trove)

local SharedTypes = require(script.Parent.SharedTypes)



local Animate = {}
Animate.__index = Animate

type self = {
	_characterInfo : SharedTypes.CharacterInfo,
	_animTracks : {number : Animation},
	_limits : {number : () -> (boolean)},
	
	_movementCleaner : Trove.Trove,
	_cleaner : Trove.Trove
}

export type Animate = typeof(setmetatable({} :: self, Animate))



--constructor
function Animate.new(characterInfo : SharedTypes.CharacterInfo) : Animate
	local self = setmetatable({} :: self, Animate)
	self._cleaner = Trove.new()

	self._characterInfo = characterInfo
	self._animTracks = {} :: any
	self._limits = {} :: any
	

	return self
end

function Animate._loadTrack(self : Animate, animID : number) : AnimationTrack?
	local animationTrack : AnimationTrack? = nil

	if not self._animTracks[animID] then --make new if needed
		local newAnim = self._cleaner:Add(Instance.new("Animation"))
		newAnim.AnimationId = "rbxassetid://" .. animID
		newAnim.Parent = self._characterInfo.Animator
		
		self._animTracks[animID] = self._characterInfo.Animator:LoadAnimation(newAnim)
	end

	animationTrack = self._animTracks[animID] --fetch track
	
	return animationTrack
end

--[[
plays animation track

animID : Id of animation to play

limit : how soon the next anim can be playe if its the same

fade : transition time for anim

weight : how heavy it should follow the anim movements

speed : how fast the anim plays
]]
function Animate.PlayAnim(self : Animate, animID : number, limit : number?, fade : number?, weight : number?, speed : number?)
	local animationTrack : AnimationTrack? = self:_loadTrack(animID)
	
	if limit then
		local currentTime = time()
		self._limits[animID] = function()-- returns true if waiting
			return (time() - currentTime) < limit
		end
	end
	
	--if just track or track and limit reached then play
	if (animationTrack and not self._limits[animID]) or (animationTrack and self._limits[animID] and self._limits[animID]() == false)  then
		animationTrack:Play(fade, weight, speed)
	end
end

--[[
stops animation track

animID : Id of animation to play

fade : transition time for anim
]]
function Animate.StopAnim(self : Animate, animID : number, fade : number?)
	local animationTrack : AnimationTrack? = self._animTracks[animID] 

	if animationTrack then
		animationTrack:Stop(fade)
	end
end




function Animate.ClearMovementAnimSystem(self : Animate)
	if self._movementCleaner then
		self._movementCleaner:Destroy()
	end
end

-- function that controls how the character reacts to moving
function Animate.CreateMovementAnimSystem(self : Animate, system : (cleaner : Trove.Trove) -> ())
	self:ClearMovementAnimSystem()
	self._movementCleaner = self._cleaner:Extend()
	
	system(self._cleaner)
end



function Animate.StandardMovementAnimSystem(self : Animate, walkID : number, runID : number, idleID : number, runSpeed : number)
	self:CreateMovementAnimSystem(function(cleaner)
		local walkTrack = self:_loadTrack(walkID)
		local runTrack = self:_loadTrack(runID)
		local idleTrack = self:_loadTrack(idleID)

		if not walkTrack or not runTrack or not idleTrack then
			warn("Could not load an anim in StandardMovement")
			return
		end
		
		cleaner:Connect(RunService.Heartbeat, function()
			local velocity = self._characterInfo.Primary.AssemblyLinearVelocity
			local velocityXZ = Vector3.new(velocity.X, 0, velocity.Z)
			
			if velocityXZ.Magnitude > runSpeed then --run
				if not runTrack.IsPlaying then
					runTrack:Play(0.3, 1, 1)
					walkTrack:Stop(0.4)
					idleTrack:Stop()
				end
			elseif velocityXZ.Magnitude > 1 then --walk
				if not walkTrack.IsPlaying then
					walkTrack:Play(0.6, 1, 1)
					runTrack:Stop(0.7)
					idleTrack:Stop(0.2)
				end
			else --idle
				if not idleTrack.IsPlaying then
					idleTrack:Play(0.2, 1, 1)
					walkTrack:Stop(0.2)
					runTrack:Stop()
				end
			end
		end)
	end)
end


--cleanup everything
function Animate.Destroy(self : Animate)
	self._cleaner:Destroy()
	self = nil :: any
end

return Animate