-- Author      : zachl
-- Create Date : 11/15/2023 6:40:23 AM

FSM = {}
FSM.__index = FSM

function FSM:new(states)
    local fsm = setmetatable({}, FSM)
    fsm.states = states or {}
    fsm.currentState = nil
    return fsm
end

function FSM:setState(stateName, ...)
    local state = self.states[stateName]
    if not state then
        error("State " .. stateName .. " does not exist.")
        return
    end

    -- Call the exit function of the current state if it exists
    if self.currentState and self.currentState.exit then
        self.currentState.exit(self)
    end

    self.currentState = state

    -- Call the enter function of the new state if it exists
    if state.enter then
        state.enter(self, ...)
    end
end

function FSM:update(...)
    if self.currentState and self.currentState.update then
        self.currentState.update(self, ...)
    end
end

function FSM:handleEvent(event, ...)
    if self.currentState and self.currentState.events and self.currentState.events[event] then
        self.currentState.events[event](self, ...)
    end
end
