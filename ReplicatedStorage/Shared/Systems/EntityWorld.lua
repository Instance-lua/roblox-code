--!strict

export type Entity = number
export type ComponentId = number
export type ComponentStore = {[Entity]: any}

export type EntityWorld = {
    CreateEntity: (self: EntityWorld) -> Entity,
    DestroyEntity: (self: EntityWorld, entity: Entity) -> boolean,
    RegisterComponent: (self: EntityWorld, name: string) -> ComponentId,
    Set: (self: EntityWorld, entity: Entity, componentId: ComponentId, value: any) -> (),
    Get: (self: EntityWorld, entity: Entity, componentId: ComponentId) -> any?,
    Has: (self: EntityWorld, entity: Entity, componentId: ComponentId) -> boolean,
    Remove: (self: EntityWorld, entity: Entity, componentId: ComponentId) -> boolean,
    Query: (self: EntityWorld, ...ComponentId) -> {Entity},
    Each: (self: EntityWorld, ...ComponentId) -> (() -> Entity?),
    Clear: (self: EntityWorld) -> (),
}

local EntityWorld = {}
local WorldPrototype = {}
WorldPrototype.__index = WorldPrototype

function EntityWorld.new(): EntityWorld
    return setmetatable({
        _nextEntity = 0,
        _nextComponent = 0,
        _alive = {} :: {[Entity]: boolean},
        _componentIds = {} :: {[string]: ComponentId},
        _componentNames = {} :: {[ComponentId]: string},
        _stores = {} :: {[ComponentId]: ComponentStore},
        _entityComponents = {} :: {[Entity]: {[ComponentId]: boolean}},
    }, WorldPrototype) :: any
end

function WorldPrototype.CreateEntity(self: any): Entity
    self._nextEntity += 1
    local entity = self._nextEntity

    self._alive[entity] = true
    self._entityComponents[entity] = {}

    return entity
end

function WorldPrototype.DestroyEntity(self: any, entity: Entity): boolean
    if not self._alive[entity] then
        return false
    end

    local components = self._entityComponents[entity]
    for componentId in components do
        self._stores[componentId][entity] = nil
    end

    self._entityComponents[entity] = nil
    self._alive[entity] = nil
    return true
end

function WorldPrototype.RegisterComponent(self: any, name: string): ComponentId
    assert(name ~= "", "Component name cannot be empty")

    local existing = self._componentIds[name]
    if existing then
        return existing
    end

    self._nextComponent += 1
    local componentId = self._nextComponent

    self._componentIds[name] = componentId
    self._componentNames[componentId] = name
    self._stores[componentId] = {}

    return componentId
end

function WorldPrototype.Set(self: any, entity: Entity, componentId: ComponentId, value: any)
    assert(self._alive[entity], "Entity does not exist")
    local store = self._stores[componentId]
    assert(store, "Component is not registered")

    store[entity] = value
    self._entityComponents[entity][componentId] = true
end

function WorldPrototype.Get(self: any, entity: Entity, componentId: ComponentId): any?
    local store = self._stores[componentId]
    return if store then store[entity] else nil
end

function WorldPrototype.Has(self: any, entity: Entity, componentId: ComponentId): boolean
    local store = self._stores[componentId]
    return store ~= nil and store[entity] ~= nil
end

function WorldPrototype.Remove(self: any, entity: Entity, componentId: ComponentId): boolean
    local store = self._stores[componentId]
    if not store or store[entity] == nil then
        return false
    end

    store[entity] = nil
    self._entityComponents[entity][componentId] = nil
    return true
end

function WorldPrototype.Query(self: any, ...: ComponentId): {Entity}
    local requested = table.pack(...)
    local result = {}

    if requested.n == 0 then
        for entity in self._alive do
            table.insert(result, entity)
        end
        return result
    end

    local smallestStore: ComponentStore? = nil
    local smallestSize = math.huge

    for index = 1, requested.n do
        local store = self._stores[requested[index]]
        if not store then
            return result
        end

        local size = 0
        for _ in store do
            size += 1
        end

        if size < smallestSize then
            smallestSize = size
            smallestStore = store
        end
    end

    if not smallestStore then
        return result
    end

    for entity in smallestStore do
        local matches = true

        for index = 1, requested.n do
            if self._stores[requested[index]][entity] == nil then
                matches = false
                break
            end
        end

        if matches then
            table.insert(result, entity)
        end
    end

    return result
end

function WorldPrototype.Each(self: any, ...: ComponentId): () -> Entity?
    local entities = self:Query(...)
    local index = 0

    return function(): Entity?
        index += 1
        return entities[index]
    end
end

function WorldPrototype.Clear(self: any)
    table.clear(self._alive)
    table.clear(self._entityComponents)

    for _, store in self._stores do
        table.clear(store)
    end
end

return EntityWorld
