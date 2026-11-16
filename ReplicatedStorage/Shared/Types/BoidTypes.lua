--!strict

export type Boid = {
    Id: number,
    Position: Vector3,
    Velocity: Vector3,
    Acceleration: Vector3,
    MaxSpeed: number,
    MaxForce: number,
    PerceptionRadius: number,
    SeparationRadius: number,
    WeightAlignment: number,
    WeightCohesion: number,
    WeightSeparation: number,
    IsActive: boolean,
    UserData: any,
}

export type FlockSettings = {
    BoundsCenter: Vector3,
    BoundsSize: Vector3,
    BoundaryForce: number,
    NeighborCellSize: number,
    MaxNeighbors: number,
    DeltaTimeCap: number,
}

return {}
