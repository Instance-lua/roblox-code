--!strict

export type ObjectPool<T> = {
    Acquire: (self: ObjectPool<T>) -> T,
    Release: (self: ObjectPool<T>, object: T) -> boolean,
    ReleaseAll: (self: ObjectPool<T>) -> (),
    Available: (self: ObjectPool<T>) -> number,
    InUse: (self: ObjectPool<T>) -> number,
    Destroy: (self: ObjectPool<T>) -> (),
}

local ObjectPool = {}
local PoolPrototype = {}
PoolPrototype.__index = PoolPrototype

function ObjectPool.new<T>(factory: () -> T, reset: ((T) -> ())?, destroy: ((T) -> ())?, initialSize: number?): ObjectPool<T>
    assert(type(factory) == "function", "Factory must be a function")

    local self = setmetatable({
        _factory = factory,
        _reset = reset,
        _destroy = destroy,
        _available = {} :: {T},
        _inUse = {} :: {[T]: boolean},
        _destroyed = false,
    }, PoolPrototype)

    for _ = 1, initialSize or 0 do
        table.insert(self._available, factory())
    end

    return self :: any
end

function PoolPrototype.Acquire<T>(self: any): T
    assert(not self._destroyed, "Pool has been destroyed")

    local object = table.remove(self._available)
    if object == nil then
        object = self._factory()
    end

    assert(not self._inUse[object], "Pool returned an object already in use")
    self._inUse[object] = true

    return object
end

function PoolPrototype.Release<T>(self: any, object: T): boolean
    if self._destroyed or not self._inUse[object] then
        return false
    end

    self._inUse[object] = nil

    if self._reset then
        self._reset(object)
    end

    table.insert(self._available, object)
    return true
end

function PoolPrototype.ReleaseAll(self: any)
    local objects = table.clone(self._inUse)

    for object in objects do
        self:Release(object)
    end
end

function PoolPrototype.Available(self: any): number
    return #self._available
end

function PoolPrototype.InUse(self: any): number
    local count = 0
    for _ in self._inUse do
        count += 1
    end
    return count
end

function PoolPrototype.Destroy(self: any)
    if self._destroyed then
        return
    end

    self._destroyed = true

    if self._destroy then
        for _, object in self._available do
            self._destroy(object)
        end

        for object in self._inUse do
            self._destroy(object)
        end
    end

    table.clear(self._available)
    table.clear(self._inUse)
end

return ObjectPool
