--!strict

local SpatialHash = require(script.Parent.Parent.Libraries.SpatialHash)

export type Boid = {
    Id: number,
    Position: Vector3,
    Velocity: Vector3,
    Acceleration: Vector3,
    MaxSpeed: number,
    MaxForce: number,
    PerceptionRadius: number,
    SeparationRadius: number,
    AlignmentWeight: number,
    CohesionWeight: number,
    SeparationWeight: number,
    IsActive: boolean,
    UserData: any,
}

export type Settings = {
    BoundsCenter: Vector3,
    BoundsSize: Vector3,
    BoundaryForce: number,
    CellSize: number,
    MaxNeighbors: number,
    DeltaTimeCap: number,
    NeighborRefreshRate: number,
}

export type BoidSimulation = {
    Add: (self: BoidSimulation, position: Vector3, velocity: Vector3?) -> Boid,
    Remove: (self: BoidSimulation, boid: Boid) -> boolean,
    Step: (self: BoidSimulation, deltaTime: number) -> (),
    GetBoids: (self: BoidSimulation) -> {Boid},
    SetBounds: (self: BoidSimulation, center: Vector3, size: Vector3) -> (),
    Clear: (self: BoidSimulation) -> (),
}

local BoidSimulation = {}
local SimulationPrototype = {}
SimulationPrototype.__index = SimulationPrototype

local DEFAULT_SETTINGS: Settings = {
    BoundsCenter = Vector3.zero,
    BoundsSize = Vector3.new(256, 128, 256),
    BoundaryForce = 18,
    CellSize = 24,
    MaxNeighbors = 32,
    DeltaTimeCap = 1 / 20,
    NeighborRefreshRate = 0.08,
}

local function limit(vector: Vector3, maximum: number): Vector3
    local magnitudeSquared = vector:Dot(vector)
    local maximumSquared = maximum * maximum

    if magnitudeSquared > maximumSquared then
        return vector * (maximum / math.sqrt(magnitudeSquared))
    end

    return vector
end

local function seek(boid: Boid, targetVelocity: Vector3): Vector3
    return limit(targetVelocity - boid.Velocity, boid.MaxForce)
end

local function calculateSteering(self: any, boid: Boid, neighbors: {Boid}): Vector3
    local alignment = Vector3.zero
    local cohesion = Vector3.zero
    local separation = Vector3.zero
    local alignmentCount = 0
    local cohesionCount = 0
    local separationCount = 0
    local maxNeighbors = self._settings.MaxNeighbors
    local maxNeighborsSquared = boid.PerceptionRadius * boid.PerceptionRadius
    local separationSquared = boid.SeparationRadius * boid.SeparationRadius

    for index = 1, math.min(#neighbors, maxNeighbors) do
        local other = neighbors[index]
        if other == boid or not other.IsActive then
            continue
        end

        local offset = other.Position - boid.Position
        local distanceSquared = offset:Dot(offset)

        if distanceSquared <= maxNeighborsSquared then
            alignment += other.Velocity
            cohesion += other.Position
            alignmentCount += 1
            cohesionCount += 1
        end

        if distanceSquared > 1e-8 and distanceSquared <= separationSquared then
            separation -= offset / distanceSquared
            separationCount += 1
        end
    end

    local steering = Vector3.zero

    if alignmentCount > 0 then
        steering += seek(boid, (alignment / alignmentCount).Unit * boid.MaxSpeed) * boid.AlignmentWeight
    end

    if cohesionCount > 0 then
        local center = cohesion / cohesionCount
        steering += seek(boid, (center - boid.Position).Unit * boid.MaxSpeed) * boid.CohesionWeight
    end

    if separationCount > 0 then
        steering += seek(boid, (separation / separationCount).Unit * boid.MaxSpeed) * boid.SeparationWeight
    end

    return limit(steering, boid.MaxForce * 3)
end

local function calculateBoundaryForce(settings: Settings, position: Vector3): Vector3
    local localPosition = position - settings.BoundsCenter
    local halfSize = settings.BoundsSize * 0.5
    local force = Vector3.zero

    if localPosition.X > halfSize.X then
        force -= Vector3.xAxis * settings.BoundaryForce
    elseif localPosition.X < -halfSize.X then
        force += Vector3.xAxis * settings.BoundaryForce
    end

    if localPosition.Y > halfSize.Y then
        force -= Vector3.yAxis * settings.BoundaryForce
    elseif localPosition.Y < -halfSize.Y then
        force += Vector3.yAxis * settings.BoundaryForce
    end

    if localPosition.Z > halfSize.Z then
        force -= Vector3.zAxis * settings.BoundaryForce
    elseif localPosition.Z < -halfSize.Z then
        force += Vector3.zAxis * settings.BoundaryForce
    end

    return force
end

function BoidSimulation.new(settings: Settings?): BoidSimulation
    local resolved = table.clone(DEFAULT_SETTINGS)

    if settings then
        for key, value in settings do
            (resolved :: any)[key] = value
        end
    end

    return setmetatable({
        _settings = resolved,
        _boids = {} :: {Boid},
        _spatialHash = SpatialHash.new(resolved.CellSize),
        _nextId = 0,
        _neighborTimer = 0,
        _neighbors = {} :: {[number]: {Boid}},
        _queryBuffer = {} :: {Boid},
        _steeringBuffer = {} :: {Vector3},
    }, SimulationPrototype) :: any
end

function SimulationPrototype.Add(self: any, position: Vector3, velocity: Vector3?): Boid
    self._nextId += 1

    local boid: Boid = {
        Id = self._nextId,
        Position = position,
        Velocity = velocity or Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * 8,
        Acceleration = Vector3.zero,
        MaxSpeed = 16,
        MaxForce = 5,
        PerceptionRadius = 28,
        SeparationRadius = 12,
        AlignmentWeight = 1,
        CohesionWeight = 0.8,
        SeparationWeight = 1.4,
        IsActive = true,
        UserData = nil,
    }

    table.insert(self._boids, boid)
    return boid
end

function SimulationPrototype.Remove(self: any, boid: Boid): boolean
    for index = #self._boids, 1, -1 do
        if self._boids[index] == boid then
            table.remove(self._boids, index)
            self._neighbors[boid.Id] = nil
            return true
        end
    end

    return false
end

function SimulationPrototype.Step(self: any, deltaTime: number)
    local dt = math.clamp(deltaTime, 0, self._settings.DeltaTimeCap)
    if dt <= 0 then
        return
    end

    local settings = self._settings
    local spatialHash = self._spatialHash

    self._neighborTimer += dt
    if self._neighborTimer >= settings.NeighborRefreshRate then
        self._neighborTimer %= settings.NeighborRefreshRate
        spatialHash:Clear()

        for _, boid in self._boids do
            if boid.IsActive then
                spatialHash:Insert(boid.Position, boid)
            end
        end

        for _, boid in self._boids do
            if boid.IsActive then
                self._neighbors[boid.Id] = spatialHash:QueryRadius(
                    boid.Position,
                    boid.PerceptionRadius,
                    self._queryBuffer
                )
                self._neighbors[boid.Id] = table.clone(self._queryBuffer)
            end
        end
    end

    for index, boid in self._boids do
        if not boid.IsActive then
            self._steeringBuffer[index] = Vector3.zero
            continue
        end

        local neighbors = self._neighbors[boid.Id] or {}
        local steering = calculateSteering(self, boid, neighbors)
        steering += calculateBoundaryForce(settings, boid.Position)
        self._steeringBuffer[index] = limit(steering, boid.MaxForce * 4)
    end

    for index, boid in self._boids do
        if not boid.IsActive then
            continue
        end

        boid.Acceleration = self._steeringBuffer[index]
        boid.Velocity = limit(boid.Velocity + boid.Acceleration * dt, boid.MaxSpeed)
        boid.Position += boid.Velocity * dt
        boid.Acceleration = Vector3.zero
    end
end

function SimulationPrototype.GetBoids(self: any): {Boid}
    return self._boids
end

function SimulationPrototype.SetBounds(self: any, center: Vector3, size: Vector3)
    self._settings.BoundsCenter = center
    self._settings.BoundsSize = size
end

function SimulationPrototype.Clear(self: any)
    table.clear(self._boids)
    table.clear(self._neighbors)
    table.clear(self._steeringBuffer)
    self._spatialHash:Clear()
end

return BoidSimulation
