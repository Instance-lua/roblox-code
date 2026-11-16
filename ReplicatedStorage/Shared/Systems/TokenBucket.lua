--!strict

export type TokenBucket = {
    Allow: (self: TokenBucket, cost: number?, now: number?) -> boolean,
    Available: (self: TokenBucket, now: number?) -> number,
    Reset: (self: TokenBucket, tokens: number?) -> (),
}

local TokenBucket = {}
local BucketPrototype = {}
BucketPrototype.__index = BucketPrototype

function TokenBucket.new(capacity: number, refillRate: number, initialTokens: number?): TokenBucket
    assert(capacity > 0, "Capacity must be positive")
    assert(refillRate >= 0, "Refill rate cannot be negative")

    local now = os.clock()

    return setmetatable({
        _capacity = capacity,
        _refillRate = refillRate,
        _tokens = math.clamp(initialTokens or capacity, 0, capacity),
        _lastUpdate = now,
    }, BucketPrototype) :: any
end

local function refill(self: any, now: number)
    local elapsed = math.max(now - self._lastUpdate, 0)
    self._lastUpdate = math.max(now, self._lastUpdate)
    self._tokens = math.min(self._capacity, self._tokens + elapsed * self._refillRate)
end

function BucketPrototype.Allow(self: any, cost: number?, now: number?): boolean
    local resolvedCost = cost or 1
    assert(resolvedCost > 0, "Cost must be positive")

    refill(self, now or os.clock())

    if self._tokens < resolvedCost then
        return false
    end

    self._tokens -= resolvedCost
    return true
end

function BucketPrototype.Available(self: any, now: number?): number
    refill(self, now or os.clock())
    return self._tokens
end

function BucketPrototype.Reset(self: any, tokens: number?)
    self._tokens = math.clamp(tokens or self._capacity, 0, self._capacity)
    self._lastUpdate = os.clock()
end

return TokenBucket
