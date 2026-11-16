--!strict

export type Comparator<T> = (T, T) -> boolean

export type BinaryHeap<T> = {
    Push: (self: BinaryHeap<T>, value: T) -> (),
    Pop: (self: BinaryHeap<T>) -> T?,
    Peek: (self: BinaryHeap<T>) -> T?,
    Clear: (self: BinaryHeap<T>) -> (),
    Size: (self: BinaryHeap<T>) -> number,
    IsEmpty: (self: BinaryHeap<T>) -> boolean,
}

local BinaryHeap = {}
local HeapPrototype = {}
HeapPrototype.__index = HeapPrototype

function BinaryHeap.new<T>(comparator: Comparator<T>): BinaryHeap<T>
    assert(type(comparator) == "function", "Comparator must be a function")

    return setmetatable({
        _items = {} :: {T},
        _comparator = comparator,
    }, HeapPrototype) :: any
end

function HeapPrototype.Push<T>(self: any, value: T)
    local items = self._items
    local index = #items + 1
    items[index] = value

    while index > 1 do
        local parentIndex = math.floor(index / 2)
        local parent = items[parentIndex]

        if not self._comparator(value, parent) then
            break
        end

        items[index] = parent
        index = parentIndex
    end

    items[index] = value
end

function HeapPrototype.Pop<T>(self: any): T?
    local items = self._items
    local count = #items

    if count == 0 then
        return nil
    end

    local root = items[1]
    local tail = items[count]
    items[count] = nil

    if count == 1 then
        return root
    end

    local index = 1
    local newCount = count - 1

    while true do
        local leftIndex = index * 2
        if leftIndex > newCount then
            break
        end

        local rightIndex = leftIndex + 1
        local childIndex = leftIndex

        if rightIndex <= newCount and self._comparator(items[rightIndex], items[leftIndex]) then
            childIndex = rightIndex
        end

        if not self._comparator(items[childIndex], tail) then
            break
        end

        items[index] = items[childIndex]
        index = childIndex
    end

    items[index] = tail
    return root
end

function HeapPrototype.Peek<T>(self: any): T?
    return self._items[1]
end

function HeapPrototype.Clear(self: any)
    table.clear(self._items)
end

function HeapPrototype.Size(self: any): number
    return #self._items
end

function HeapPrototype.IsEmpty(self: any): boolean
    return #self._items == 0
end

return BinaryHeap
