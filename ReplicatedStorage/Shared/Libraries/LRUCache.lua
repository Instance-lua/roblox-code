--!strict

export type LRUCache<K, V> = {
    Get: (self: LRUCache<K, V>, key: K) -> V?,
    Set: (self: LRUCache<K, V>, key: K, value: V) -> (),
    Remove: (self: LRUCache<K, V>, key: K) -> boolean,
    Clear: (self: LRUCache<K, V>) -> (),
    Size: (self: LRUCache<K, V>) -> number,
}

type Node<K, V> = {
    Key: K?,
    Value: V?,
    Previous: Node<K, V>?,
    Next: Node<K, V>?,
}

local LRUCache = {}
local CachePrototype = {}
CachePrototype.__index = CachePrototype

local function detach<K, V>(node: Node<K, V>)
    local previous = node.Previous
    local nextNode = node.Next

    if previous then
        previous.Next = nextNode
    end

    if nextNode then
        nextNode.Previous = previous
    end

    node.Previous = nil
    node.Next = nil
end

local function attachAfter<K, V>(anchor: Node<K, V>, node: Node<K, V>)
    local nextNode = anchor.Next

    node.Previous = anchor
    node.Next = nextNode
    anchor.Next = node

    if nextNode then
        nextNode.Previous = node
    end
end

local function moveToFront<K, V>(self: any, node: Node<K, V>)
    detach(node)
    attachAfter(self._head, node)
end

local function evictTail(self: any)
    local node = self._tail.Previous
    if node == self._head then
        return
    end

    detach(node)
    self._nodes[node.Key] = nil
    self._size -= 1
end

function LRUCache.new<K, V>(capacity: number): LRUCache<K, V>
    assert(capacity >= 1 and capacity % 1 == 0, "Capacity must be a positive integer")

    local head = {Next = nil, Previous = nil} :: any
    local tail = {Next = nil, Previous = head} :: any
    head.Next = tail

    return setmetatable({
        _capacity = capacity,
        _size = 0,
        _nodes = {} :: {[K]: Node<K, V>},
        _head = head,
        _tail = tail,
    }, CachePrototype) :: any
end

function CachePrototype.Get<K, V>(self: any, key: K): V?
    local node = self._nodes[key]
    if not node then
        return nil
    end

    moveToFront(self, node)
    return node.Value
end

function CachePrototype.Set<K, V>(self: any, key: K, value: V)
    local node = self._nodes[key]

    if node then
        node.Value = value
        moveToFront(self, node)
        return
    end

    node = {
        Key = key,
        Value = value,
        Previous = nil,
        Next = nil,
    }

    self._nodes[key] = node
    attachAfter(self._head, node)
    self._size += 1

    if self._size > self._capacity then
        evictTail(self)
    end
end

function CachePrototype.Remove<K, V>(self: any, key: K): boolean
    local node = self._nodes[key]
    if not node then
        return false
    end

    detach(node)
    self._nodes[key] = nil
    self._size -= 1
    return true
end

function CachePrototype.Clear(self: any)
    table.clear(self._nodes)
    self._size = 0
    self._head.Next = self._tail
    self._tail.Previous = self._head
end

function CachePrototype.Size(self: any): number
    return self._size
end

return LRUCache
