--!strict

export type Entry<T> = {
    Position: Vector3,
    Value: T,
}

export type SpatialHash<T> = {
    Insert: (self: SpatialHash<T>, position: Vector3, value: T) -> (),
    Remove: (self: SpatialHash<T>, position: Vector3, value: T) -> boolean,
    QueryRadius: (self: SpatialHash<T>, position: Vector3, radius: number, output: {T}?) -> {T},
    QueryAABB: (self: SpatialHash<T>, minimum: Vector3, maximum: Vector3, output: {T}?) -> {T},
    Clear: (self: SpatialHash<T>) -> (),
}

local SpatialHash = {}
local HashPrototype = {}
HashPrototype.__index = HashPrototype

local function cellCoordinate(value: number, inverseCellSize: number): number
    return math.floor(value * inverseCellSize)
end

local function cellKey(x: number, y: number, z: number): string
    return `{x}:{y}:{z}`
end

local function getCell(self: any, position: Vector3): string
    local inverse = self._inverseCellSize
    return cellKey(
        cellCoordinate(position.X, inverse),
        cellCoordinate(position.Y, inverse),
        cellCoordinate(position.Z, inverse)
    )
end

function SpatialHash.new<T>(cellSize: number): SpatialHash<T>
    assert(cellSize > 0, "Cell size must be positive")

    return setmetatable({
        _cellSize = cellSize,
        _inverseCellSize = 1 / cellSize,
        _cells = {} :: {[string]: {Entry<T>}},
        _count = 0,
    }, HashPrototype) :: any
end

function HashPrototype.Insert<T>(self: any, position: Vector3, value: T)
    local key = getCell(self, position)
    local cell = self._cells[key]

    if not cell then
        cell = {}
        self._cells[key] = cell
    end

    table.insert(cell, {
        Position = position,
        Value = value,
    })

    self._count += 1
end

function HashPrototype.Remove<T>(self: any, position: Vector3, value: T): boolean
    local key = getCell(self, position)
    local cell = self._cells[key]

    if not cell then
        return false
    end

    for index = #cell, 1, -1 do
        if cell[index].Value == value then
            table.remove(cell, index)
            self._count -= 1

            if #cell == 0 then
                self._cells[key] = nil
            end

            return true
        end
    end

    return false
end

function HashPrototype.QueryRadius<T>(self: any, position: Vector3, radius: number, output: {T}?): {T}
    local result = output or {}
    table.clear(result)

    local inverse = self._inverseCellSize
    local minimumX = cellCoordinate(position.X - radius, inverse)
    local minimumY = cellCoordinate(position.Y - radius, inverse)
    local minimumZ = cellCoordinate(position.Z - radius, inverse)
    local maximumX = cellCoordinate(position.X + radius, inverse)
    local maximumY = cellCoordinate(position.Y + radius, inverse)
    local maximumZ = cellCoordinate(position.Z + radius, inverse)
    local radiusSquared = radius * radius

    for x = minimumX, maximumX do
        for y = minimumY, maximumY do
            for z = minimumZ, maximumZ do
                local cell = self._cells[cellKey(x, y, z)]
                if cell then
                    for _, entry in cell do
                        if (entry.Position - position):Dot(entry.Position - position) <= radiusSquared then
                            table.insert(result, entry.Value)
                        end
                    end
                end
            end
        end
    end

    return result
end

function HashPrototype.QueryAABB<T>(self: any, minimum: Vector3, maximum: Vector3, output: {T}?): {T}
    local result = output or {}
    table.clear(result)

    local inverse = self._inverseCellSize
    local minimumX = cellCoordinate(minimum.X, inverse)
    local minimumY = cellCoordinate(minimum.Y, inverse)
    local minimumZ = cellCoordinate(minimum.Z, inverse)
    local maximumX = cellCoordinate(maximum.X, inverse)
    local maximumY = cellCoordinate(maximum.Y, inverse)
    local maximumZ = cellCoordinate(maximum.Z, inverse)

    for x = minimumX, maximumX do
        for y = minimumY, maximumY do
            for z = minimumZ, maximumZ do
                local cell = self._cells[cellKey(x, y, z)]
                if cell then
                    for _, entry in cell do
                        local point = entry.Position
                        if point.X >= minimum.X and point.X <= maximum.X
                            and point.Y >= minimum.Y and point.Y <= maximum.Y
                            and point.Z >= minimum.Z and point.Z <= maximum.Z then
                            table.insert(result, entry.Value)
                        end
                    end
                end
            end
        end
    end

    return result
end

function HashPrototype.Clear(self: any)
    table.clear(self._cells)
    self._count = 0
end

return SpatialHash
