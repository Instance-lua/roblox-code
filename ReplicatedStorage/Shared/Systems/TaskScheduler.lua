--!strict

export type ScheduledTask = {
    Id: number,
    Callback: (number) -> (),
    Interval: number,
    Remaining: number,
    Repetitions: number?,
    IsCancelled: boolean,
}

export type TaskScheduler = {
    Schedule: (self: TaskScheduler, delayTime: number, callback: (number) -> ()) -> ScheduledTask,
    Every: (self: TaskScheduler, interval: number, callback: (number) -> (), repetitions: number?) -> ScheduledTask,
    Cancel: (self: TaskScheduler, scheduledTask: ScheduledTask) -> boolean,
    Step: (self: TaskScheduler, deltaTime: number) -> (),
    Clear: (self: TaskScheduler) -> (),
}

local TaskScheduler = {}
local SchedulerPrototype = {}
SchedulerPrototype.__index = SchedulerPrototype

function TaskScheduler.new(maxCallbacksPerStep: number?): TaskScheduler
    return setmetatable({
        _tasks = {} :: {ScheduledTask},
        _nextId = 0,
        _maxCallbacksPerStep = maxCallbacksPerStep or 256,
        _stepping = false,
        _pending = {} :: {ScheduledTask},
    }, SchedulerPrototype) :: any
end

local function createTask(self: any, interval: number, callback: (number) -> (), repetitions: number?): ScheduledTask
    assert(interval >= 0, "Interval cannot be negative")
    assert(type(callback) == "function", "Callback must be a function")

    self._nextId += 1

    local scheduledTask: ScheduledTask = {
        Id = self._nextId,
        Callback = callback,
        Interval = interval,
        Remaining = interval,
        Repetitions = repetitions,
        IsCancelled = false,
    }

    if self._stepping then
        table.insert(self._pending, scheduledTask)
    else
        table.insert(self._tasks, scheduledTask)
    end

    return scheduledTask
end

function SchedulerPrototype.Schedule(self: any, delayTime: number, callback: (number) -> ()): ScheduledTask
    return createTask(self, delayTime, callback, 1)
end

function SchedulerPrototype.Every(self: any, interval: number, callback: (number) -> (), repetitions: number?): ScheduledTask
    assert(repetitions == nil or repetitions > 0, "Repetitions must be positive")
    return createTask(self, interval, callback, repetitions)
end

function SchedulerPrototype.Cancel(self: any, scheduledTask: ScheduledTask): boolean
    if scheduledTask.IsCancelled then
        return false
    end

    scheduledTask.IsCancelled = true
    return true
end

function SchedulerPrototype.Step(self: any, deltaTime: number)
    if self._stepping then
        return
    end

    self._stepping = true

    local callbackCount = 0
    local tasks = self._tasks

    for index = #tasks, 1, -1 do
        local scheduledTask = tasks[index]

        if scheduledTask.IsCancelled then
            table.remove(tasks, index)
            continue
        end

        scheduledTask.Remaining -= deltaTime

        if scheduledTask.Remaining <= 0 then
            callbackCount += 1
            local elapsed = scheduledTask.Interval - scheduledTask.Remaining
            local success, message = pcall(scheduledTask.Callback, elapsed)

            if not success then
                warn(`Scheduled task {scheduledTask.Id} failed: {message}`)
                scheduledTask.IsCancelled = true
            elseif scheduledTask.Repetitions ~= nil then
                scheduledTask.Repetitions -= 1
                if scheduledTask.Repetitions <= 0 then
                    scheduledTask.IsCancelled = true
                end
            end

            if not scheduledTask.IsCancelled and callbackCount < self._maxCallbacksPerStep then
                if scheduledTask.Interval > 0 then
                    scheduledTask.Remaining += scheduledTask.Interval
                else
                    scheduledTask.Remaining = 0
                end
            end
        end

        if scheduledTask.IsCancelled or callbackCount >= self._maxCallbacksPerStep then
            table.remove(tasks, index)
        end
    end

    self._stepping = false

    for _, scheduledTask in self._pending do
        if not scheduledTask.IsCancelled then
            table.insert(tasks, scheduledTask)
        end
    end

    table.clear(self._pending)
end

function SchedulerPrototype.Clear(self: any)
    for _, scheduledTask in self._tasks do
        scheduledTask.IsCancelled = true
    end

    for _, scheduledTask in self._pending do
        scheduledTask.IsCancelled = true
    end

    table.clear(self._tasks)
    table.clear(self._pending)
end

return TaskScheduler
