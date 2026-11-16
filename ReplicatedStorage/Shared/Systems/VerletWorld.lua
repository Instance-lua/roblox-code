--!strict

local PhysicsTypes = require(script.Parent.Parent.Types.PhysicsTypes)

type Body = PhysicsTypes.Body
type DistanceConstraint = PhysicsTypes.DistanceConstraint

export type WorldSettings = {
    Gravity: Vector3,
    Damping: number,
    Iterations: number,
    MaxDeltaTime: number,
    CollisionSlop: number,
    CollisionPercent: number,
}

export type VerletWorld = {
    CreateBody: (self: VerletWorld, position: Vector3, radius: number, mass: number, isStatic: boolean?) -> Body,
    RemoveBody: (self: VerletWorld, body: Body) -> boolean,
    AddDistanceConstraint: (self: VerletWorld, bodyA: Body, bodyB: Body, stiffness: number?) -> DistanceConstraint,
    RemoveConstraint: (self: VerletWorld, constraint: DistanceConstraint) -> boolean,
    ApplyImpulse: (self: VerletWorld, body: Body, impulse: Vector3) -> (),
    Step: (self: VerletWorld, deltaTime: number) -> (),
    GetBodies: (self: VerletWorld) -> {Body},
    Clear: (self: VerletWorld) -> (),
}

local VerletWorld = {}
local WorldPrototype = {}
WorldPrototype.__index = WorldPrototype

local DEFAULT_SETTINGS: WorldSettings = {
    Gravity = Vector3.new(0, -196.2, 0),
    Damping = 0.995,
    Iterations = 5,
    MaxDeltaTime = 1 / 20,
    CollisionSlop = 0.001,
    CollisionPercent = 0.8,
}

local function inverseMass(body: Body): number
    return if body.IsStatic then 0 else body.InverseMass
end

local function solveConstraint(constraint: DistanceConstraint)
    if not constraint.Enabled then
        return
    end

    local bodyA = constraint.BodyA
    local bodyB = constraint.BodyB
    local delta = bodyB.Position - bodyA.Position
    local distanceSquared = delta:Dot(delta)

    if distanceSquared <= 1e-12 then
        return
    end

    local distance = math.sqrt(distanceSquared)
    local difference = (distance - constraint.RestLength) / distance
    local weightA = inverseMass(bodyA)
    local weightB = inverseMass(bodyB)
    local totalWeight = weightA + weightB

    if totalWeight <= 0 then
        return
    end

    local correction = delta * (difference * constraint.Stiffness)
    bodyA.Position += correction * (weightA / totalWeight)
    bodyB.Position -= correction * (weightB / totalWeight)
end

local function solveBodyCollision(bodyA: Body, bodyB: Body, slop: number, percent: number)
    if bodyA.IsStatic and bodyB.IsStatic then
        return
    end

    local delta = bodyB.Position - bodyA.Position
    local distanceSquared = delta:Dot(delta)
    local minimumDistance = bodyA.Radius + bodyB.Radius

    if distanceSquared >= minimumDistance * minimumDistance then
        return
    end

    local distance = math.sqrt(math.max(distanceSquared, 1e-12))
    local normal = if distanceSquared <= 1e-12 then Vector3.xAxis else delta / distance
    local penetration = math.max(minimumDistance - distance - slop, 0)
    local weightA = inverseMass(bodyA)
    local weightB = inverseMass(bodyB)
    local totalWeight = weightA + weightB

    if totalWeight <= 0 then
        return
    end

    local correction = normal * (penetration * percent / totalWeight)
    bodyA.Position -= correction * weightA
    bodyB.Position += correction * weightB
end

function VerletWorld.new(settings: WorldSettings?): VerletWorld
    local resolved = table.clone(DEFAULT_SETTINGS)

    if settings then
        for key, value in settings do
            (resolved :: any)[key] = value
        end
    end

    return setmetatable({
        _settings = resolved,
        _bodies = {} :: {Body},
        _constraints = {} :: {DistanceConstraint},
        _nextBodyId = 0,
        _nextConstraintId = 0,
        _stepping = false,
    }, WorldPrototype) :: any
end

function WorldPrototype.CreateBody(self: any, position: Vector3, radius: number, mass: number, isStatic: boolean?): Body
    assert(radius >= 0, "Radius cannot be negative")
    assert(mass > 0 or isStatic == true, "Dynamic body mass must be positive")

    self._nextBodyId += 1

    local body: Body = {
        Id = self._nextBodyId,
        Position = position,
        PreviousPosition = position,
        Velocity = Vector3.zero,
        Acceleration = Vector3.zero,
        Radius = radius,
        InverseMass = if isStatic then 0 else 1 / mass,
        Restitution = 0.1,
        Friction = 0.2,
        IsStatic = isStatic == true,
        IsActive = true,
        UserData = nil,
    }

    table.insert(self._bodies, body)
    return body
end

function WorldPrototype.RemoveBody(self: any, body: Body): boolean
    for index = #self._bodies, 1, -1 do
        if self._bodies[index] == body then
            table.remove(self._bodies, index)

            for constraintIndex = #self._constraints, 1, -1 do
                local constraint = self._constraints[constraintIndex]
                if constraint.BodyA == body or constraint.BodyB == body then
                    table.remove(self._constraints, constraintIndex)
                end
            end

            return true
        end
    end

    return false
end

function WorldPrototype.AddDistanceConstraint(self: any, bodyA: Body, bodyB: Body, stiffness: number?): DistanceConstraint
    assert(bodyA ~= bodyB, "A body cannot be constrained to itself")

    self._nextConstraintId += 1

    local constraint: DistanceConstraint = {
        Id = self._nextConstraintId,
        BodyA = bodyA,
        BodyB = bodyB,
        RestLength = (bodyB.Position - bodyA.Position).Magnitude,
        Stiffness = math.clamp(stiffness or 1, 0, 1),
        Enabled = true,
    }

    table.insert(self._constraints, constraint)
    return constraint
end

function WorldPrototype.RemoveConstraint(self: any, constraint: DistanceConstraint): boolean
    for index = #self._constraints, 1, -1 do
        if self._constraints[index] == constraint then
            table.remove(self._constraints, index)
            return true
        end
    end

    return false
end

function WorldPrototype.ApplyImpulse(self: any, body: Body, impulse: Vector3)
    if body.IsStatic or not body.IsActive then
        return
    end

    body.Velocity += impulse * body.InverseMass
end

function WorldPrototype.Step(self: any, deltaTime: number)
    if self._stepping then
        return
    end

    self._stepping = true

    local settings = self._settings
    local dt = math.clamp(deltaTime, 0, settings.MaxDeltaTime)
    local dtSquared = dt * dt
    local damping = math.pow(settings.Damping, dt * 60)

    for _, body in self._bodies do
        if not body.IsActive or body.IsStatic then
            continue
        end

        local currentPosition = body.Position
        local velocity = (currentPosition - body.PreviousPosition) * damping
        local acceleration = settings.Gravity + body.Acceleration

        body.PreviousPosition = currentPosition
        body.Position = currentPosition + velocity + acceleration * dtSquared
        body.Acceleration = Vector3.zero
    end

    for _ = 1, settings.Iterations do
        for _, constraint in self._constraints do
            solveConstraint(constraint)
        end

        local bodyCount = #self._bodies
        for firstIndex = 1, bodyCount - 1 do
            local bodyA = self._bodies[firstIndex]
            if not bodyA.IsActive then
                continue
            end

            for secondIndex = firstIndex + 1, bodyCount do
                local bodyB = self._bodies[secondIndex]
                if bodyB.IsActive then
                    solveBodyCollision(
                        bodyA,
                        bodyB,
                        settings.CollisionSlop,
                        settings.CollisionPercent
                    )
                end
            end
        end
    end

    for _, body in self._bodies do
        if body.IsStatic or not body.IsActive then
            continue
        end

        body.Velocity = (body.Position - body.PreviousPosition) / math.max(dt, 1e-6)
    end

    self._stepping = false
end

function WorldPrototype.GetBodies(self: any): {Body}
    return self._bodies
end

function WorldPrototype.Clear(self: any)
    table.clear(self._bodies)
    table.clear(self._constraints)
end

return VerletWorld
