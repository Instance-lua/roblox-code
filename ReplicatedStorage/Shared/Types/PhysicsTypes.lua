--!strict

export type BodyId = number

export type Body = {
    Id: BodyId,
    Position: Vector3,
    PreviousPosition: Vector3,
    Velocity: Vector3,
    Acceleration: Vector3,
    Radius: number,
    InverseMass: number,
    Restitution: number,
    Friction: number,
    IsStatic: boolean,
    IsActive: boolean,
    UserData: any,
}

export type DistanceConstraint = {
    Id: number,
    BodyA: Body,
    BodyB: Body,
    RestLength: number,
    Stiffness: number,
    Enabled: boolean,
}

export type SphereCollider = {
    Center: Vector3,
    Radius: number,
    Layer: number,
    Mask: number,
}

return {}
