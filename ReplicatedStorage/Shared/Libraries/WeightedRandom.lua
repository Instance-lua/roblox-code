--!strict

export type WeightedEntry<T> = {
    Value: T,
    Weight: number,
}

export type WeightedRandom<T> = {
    Add: (self: WeightedRandom<T>, value: T, weight: number) -> (),
    Remove: (self: WeightedRandom<T>, value: T) -> boolean,
    Choose: (self: WeightedRandom<T>, random: Random?) -> T?,
    TotalWeight: (self: WeightedRandom<T>) -> number,
    Clear: (self: WeightedRandom<T>) -> (),
}

local WeightedRandom = {}
local WeightedPrototype = {}
WeightedPrototype.__index = WeightedPrototype

function WeightedRandom.new<T>(): WeightedRandom<T>
    return setmetatable({
        _entries = {} :: {WeightedEntry<T>},
        _indices = {} :: {[T]: number},
        _totalWeight = 0,
    }, WeightedPrototype) :: any
end

function WeightedPrototype.Add<T>(self: any, value: T, weight: number)
    assert(weight > 0 and weight < math.huge, "Weight must be finite and positive")

    local index = self._indices[value]
    if index then
        local entry = self._entries[index]
        self._totalWeight += weight - entry.Weight
        entry.Weight = weight
        return
    end

    table.insert(self._entries, {
        Value = value,
        Weight = weight,
    })

    self._indices[value] = #self._entries
    self._totalWeight += weight
end

function WeightedPrototype.Remove<T>(self: any, value: T): boolean
    local index = self._indices[value]
    if not index then
        return false
    end

    local entries = self._entries
    local removed = entries[index]
    local tail = table.remove(entries)

    self._indices[value] = nil
    self._totalWeight -= removed.Weight

    if index <= #entries and tail then
        entries[index] = tail
        self._indices[tail.Value] = index
    end

    return true
end

function WeightedPrototype.Choose<T>(self: any, random: Random?): T?
    if self._totalWeight <= 0 then
        return nil
    end

    local generator = random or Random.new()
    local threshold = generator:NextNumber(0, self._totalWeight)
    local cumulative = 0

    for _, entry in self._entries do
        cumulative += entry.Weight
        if threshold <= cumulative then
            return entry.Value
        end
    end

    return self._entries[#self._entries].Value
end

function WeightedPrototype.TotalWeight(self: any): number
    return self._totalWeight
end

function WeightedPrototype.Clear(self: any)
    table.clear(self._entries)
    table.clear(self._indices)
    self._totalWeight = 0
end

return WeightedRandom
