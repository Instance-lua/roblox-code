--!strict

export type Task = RBXScriptConnection | Instance | (() -> ()) | thread | {[string]: any}

export type Maid = {
    GiveTask: (self: Maid, taskValue: Task) -> Task,
    RemoveTask: (self: Maid, taskValue: Task) -> (),
    DoCleaning: (self: Maid) -> (),
    Destroy: (self: Maid) -> (),
}

local Maid = {}
local MaidPrototype = {}
MaidPrototype.__index = MaidPrototype

local function cleanTask(taskValue: any)
    local taskType = typeof(taskValue)

    if taskType == "RBXScriptConnection" then
        taskValue:Disconnect()
    elseif taskType == "Instance" then
        taskValue:Destroy()
    elseif taskType == "function" then
        taskValue()
    elseif taskType == "thread" then
        pcall(task.cancel, taskValue)
    elseif type(taskValue) == "table" then
        if type(taskValue.Destroy) == "function" then
            taskValue:Destroy()
        elseif type(taskValue.Disconnect) == "function" then
            taskValue:Disconnect()
        elseif type(taskValue.DoCleaning) == "function" then
            taskValue:DoCleaning()
        end
    end
end

function Maid.new(): Maid
    return setmetatable({
        _tasks = {} :: {Task},
        _cleaning = false,
        _destroyed = false,
    }, MaidPrototype) :: any
end

function MaidPrototype.GiveTask(self: any, taskValue: Task): Task
    assert(not self._destroyed, "Cannot add tasks to a destroyed Maid")
    assert(taskValue ~= nil, "Task cannot be nil")

    if self._cleaning then
        cleanTask(taskValue)
        return taskValue
    end

    table.insert(self._tasks, taskValue)
    return taskValue
end

function MaidPrototype.RemoveTask(self: any, taskValue: Task)
    for index = #self._tasks, 1, -1 do
        if self._tasks[index] == taskValue then
            table.remove(self._tasks, index)
            return
        end
    end
end

function MaidPrototype.DoCleaning(self: any)
    if self._cleaning then
        return
    end

    self._cleaning = true

    for index = #self._tasks, 1, -1 do
        local taskValue = self._tasks[index]
        self._tasks[index] = nil

        local success, message = pcall(cleanTask, taskValue)
        if not success then
            warn(`Maid cleanup failed: {message}`)
        end
    end

    table.clear(self._tasks)
    self._cleaning = false
end

function MaidPrototype.Destroy(self: any)
    if self._destroyed then
        return
    end

    self:DoCleaning()
    self._destroyed = true
end

return Maid
