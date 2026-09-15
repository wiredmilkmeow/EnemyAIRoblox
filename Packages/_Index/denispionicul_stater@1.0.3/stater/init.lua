--!nonstrict
-- Version 1.0.3

-- Dependencies
local Signal = require(script.Parent.Signal)
local Trove = require(script.Parent.Trove)

--[=[
    @class Stater

    Stater is a finite state machine module with the purpose of easing the creation of ai and npcs in games,
    Stater was built with the intent of being used in module scripts.

    ```lua
        local States = {}

        function States.DoSomethingEnd(Data)
            -- this will fire when the machine switches from the "DoSomething" state 
        end

        function States.DoSomething(Data)
            -- do something with the data
        end

        function States.DoSomethingStart(Data)
            -- this will fire when the machine switch to "DoSomething"
            Data.Stater:SetState("SomethingDifferent")
        end

        local Data = {
            Something = "Something",
        }

        Data.Stater = Stater.new(States, 0, Data)

        Data.Stater:Start("DoSomething")
    ```
]=]
local Stater = {}
Stater.__index = Stater

function Stater:__tostring(): "Stater"
    return "Stater"
end

function Stater:__eq(Val: any): boolean
    return type(Val) == "table" and getmetatable(Val) == Stater and tostring(Val) == "Stater"
end

-- Types
--[=[
    @type State (Stater | any) -> boolean?
    @within Stater
]=]

--[=[
    @interface Stater
    @within Stater
    .States {[string]: State} -- The Provided States Table, if theres a "Init" state then that function will execute each time the Stater Starts.
    .Info {any?} -- A table that you can add anything in, this is more recommended than directly inserting variables inside the object.
    .Tick number? -- The time it takes for the current state to be called again after a function is done. Default is 0
    .Return any -- This is the thing that returns as the first parameter of every single state. Default is the Stater object itself.
    .State State -- The current state that the Stater is on.
    .StateConfirmation boolean -- If this is enabled, the state MUST return a boolean indicating if the function ran properly.
    .Changed RBXScriptSignal -- A signal that fires whenever the State changes. Returns Current State and Previous State
    .StatusChanged RBXScriptSignal -- Fired whenever the Stater starts or closes. Returns the current status as a boolean.
    .StateRemoved RBXScriptSignal -- A signal that fires whenever a state is added via the Stater:AddState() method. Returns the State Name.
    .StateAdded RBXScriptSignal -- A signal that fires whenever a state is removed via the Stater:RemoveState() method. Returns the State Name.
]=]

type State<T = unknown> = (self: T) -> boolean?

type Module<T> = {
    __index: Module<T>,
    new: (States: { [string]: State<T> }, Tick: number?, Return: T?) -> Stater<T>,
    __eq: (self: Stater<T>, Val: any) -> boolean,
    __tostring: (self: Stater<T>) -> "Stater",

    RemoveState: (self: Stater<T>, Name: string) -> (),
    AddState: (self: Stater<T>, Name: string, State: State) -> (),
    GetCurrentState: (self: Stater<T>) -> string?,
    IsWorking: (self: Stater<T>) -> boolean,
    SetState: (self: Stater<T>, Name: string) -> (),
    Start: (self: Stater<T>, StartingState: string, ...any) -> (),
    Stop: (self: Stater<T>) -> (),
    Destroy: (self: Stater<T>) -> ()
}

type Properties<T> = {
    States: { [string]: State<T> },
    Info: { any },
    Tick: number?,
    Return: T,
    State: string,
    StateConfirmation: boolean,

    Changed: Signal.Signal<string, string>, -- ignore if this is underlined
    StatusChanged: Signal.Signal<boolean>, -- ignore if this is underlined
    StateRemoved: Signal.Signal<string>, -- ignore if this is underlined
    StateAdded: Signal.Signal<string>, -- ignore if this is underlined
}

export type Stater<T = unknown> = typeof(setmetatable({} :: Properties<T>, {} :: Module<T>))

--[=[
    Returns a new Stater Object.

    @error "No States" -- Happens when no States are provided
    @param States -- The Table that will have all the States
    @param Tick -- Optional tick to be set.
    @param Return -- Determines what to return in the first parameter of each state.
]=]
function Stater.new<T>(States: {[string]: State<T>}, Tick: number?, Return: T?): Stater<T>
    assert(type(States) == "table", "Please provide a valid table with the states.")

    local self = setmetatable({}, Stater)

    -- Non Usable
    self._Trove = Trove.new()
    self._Connections = {
        Main = nil,
    }

    -- Usable
    self.States = States
    self.Info = {}
    self.Tick = Tick or 0
    self.State = nil
    self.StateConfirmation = false
    self.Return = Return or self

    self.Changed = self._Trove:Construct(Signal)
    self.StatusChanged = self._Trove:Construct(Signal)
    self.StateRemoved = self._Trove:Construct(Signal)
    self.StateAdded = self._Trove:Construct(Signal)

    return self
end

--[=[
    Removes a state inside the states table.

    @param Name -- The name of the removing state.
]=]
function Stater:RemoveState(Name: string)
    assert(type(Name) == "string", "The name must be a string.")

    local RemovingState = self.States[Name]

    if RemovingState then
        RemovingState = nil
        self.States[Name] = nil
        self.StateRemoved:Fire(Name)
    else
        warn("Given state " .. Name .. " does not exist.")
    end
end

--[=[
    Adds a state inside the states table. If there is a Start after the State name inside the States, that will play.
    If there is a End after the State name inside the States, that will play after the state changes.

    @param Name -- The name that the state will go by.
    @param State -- The State function itself.
    @error "Existing State" -- Happens when the name of the state is already inside the table.
]=]
function Stater:AddState(Name: string, State: State<any>)
    assert(type(Name) == "string", "The name must be a string.")
    assert(type(State) == "function", "The State must be a function.")

    local AlreadyExists = self.States[Name]
    assert(AlreadyExists == nil, "There is already a State with that name, consider changing.")

    self.States[Name] = State
    self.StateAdded:Fire(Name)
end

--[=[
    Returns the current state the Stater is on indicated by a string. If none then nil.
    This is currently the same as self.State.
]=]
function Stater:GetCurrentState(): string?
    return self.State
end

--[=[
    Returns a boolean indicating if the State currently is on.
]=]
function Stater:IsWorking(): boolean
    return self._Connections.Main ~= nil
end

--[=[
    Returns a boolean indicating if the State currently is on.

    @param State -- The function name inside States represented by a string
    @error "No State" -- Happens when no State is provided.
    @error "Invalid State" -- Happens when the state provided doesn't exist.
]=]
function Stater:SetState(State: string)
    assert(type(State) == "string", "Please provide a state when setting.")

    local StateInStates = self.States[State]
    assert(StateInStates ~= nil, "No state with the given name.")

    local StartOption = self.States[State .. "Start"]
    local EndOption = self.States[tostring(self.State) .. "End"]

    if StartOption then
        StartOption(self.Return)
    end

    if EndOption then
        EndOption(self.Return)
    end

    local OldState = self.State
    self.State = State
    self.Changed:Fire(State, OldState)
end

--[=[
    Begins the Stater.

    @param StartingState string -- The function name inside States represented by a string, this state will be set at the start.
    @error "No State" -- Happens when no State is provided.
]=]
function Stater:Start(StartingState: string, ...:any)
    assert(type(StartingState) == "string", "Please provide a state when starting.")

    if self._Connections.Main ~= nil then
        return
    end
    assert(self._Connections.Main == nil, "You cannot start twice.")

    if self.States["Init"] then
        self.States["Init"](self.Return, ...)
    end

    self:SetState(StartingState)
    self.StatusChanged:Fire(true)

    self._Connections.Main = self._Trove
        :Add(task.spawn(function()
            while self.State ~= nil do
                task.wait(self.Tick)
                local StateOption = self.States[self.State]

                if StateOption then
                    local Result = StateOption(self.Return)

                    if self.StateConfirmation and (Result == false) then
                        warn("State returned false or nil, stopping...")
                        self:Stop()
                    end
                else
                    warn("Current State is not set, Please consider setting a state. The state machine will be stopping.")
                end
            end
        end))
end

--[=[
    Stops the stater and its state.
]=]
function Stater:Stop()
    if self._Connections.Main == nil then
        return
    end

    local StopOption = self.States.End
    local EndOption = self.States[tostring(self.State) .. "End"]

    self._Trove:Remove(self._Connections.Main)
    task.cancel(self._Connections.Main)
    self._Connections.Main = nil
    self.State = nil

    if StopOption then
        StopOption(self.Return)
    end

    if EndOption then
        EndOption(self.Return)
    end

    self.StatusChanged:Fire(false)
end

--[=[
    Gets rid of the Stater Object.
]=]
function Stater:Destroy()
	
	if self.States["Exit"] then --added by VIPER
		self.States["Exit"](self.Return)
	end
	
    self:Stop()
    self._Trove:Destroy()
    table.clear(self)
    self = nil
end

return Stater