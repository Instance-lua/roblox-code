--!strict

export type TrieNode = {
    Children: {[string]: TrieNode},
    IsTerminal: boolean,
    Value: any,
}

export type Trie = {
    Insert: (self: Trie, word: string, value: any?) -> (),
    Find: (self: Trie, word: string) -> (boolean, any?),
    HasPrefix: (self: Trie, prefix: string) -> boolean,
    Remove: (self: Trie, word: string) -> boolean,
    Complete: (self: Trie, prefix: string, limit: number?) -> {string},
    Clear: (self: Trie) -> (),
}

local Trie = {}
local TriePrototype = {}
TriePrototype.__index = TriePrototype

local function createNode(): TrieNode
    return {
        Children = {},
        IsTerminal = false,
        Value = nil,
    }
end

function Trie.new(): Trie
    return setmetatable({
        _root = createNode(),
        _size = 0,
    }, TriePrototype) :: any
end

function TriePrototype.Insert(self: any, word: string, value: any?)
    assert(word ~= "", "Word cannot be empty")

    local node = self._root

    for index = 1, #word do
        local character = string.sub(word, index, index)
        local child = node.Children[character]

        if not child then
            child = createNode()
            node.Children[character] = child
        end

        node = child
    end

    if not node.IsTerminal then
        self._size += 1
    end

    node.IsTerminal = true
    node.Value = value
end

function TriePrototype.Find(self: any, word: string): (boolean, any?)
    local node = self._root

    for index = 1, #word do
        node = node.Children[string.sub(word, index, index)]
        if not node then
            return false, nil
        end
    end

    return node.IsTerminal, node.Value
end

function TriePrototype.HasPrefix(self: any, prefix: string): boolean
    local node = self._root

    for index = 1, #prefix do
        node = node.Children[string.sub(prefix, index, index)]
        if not node then
            return false
        end
    end

    return true
end

function TriePrototype.Remove(self: any, word: string): boolean
    local path = {}
    local node = self._root

    for index = 1, #word do
        local character = string.sub(word, index, index)
        local child = node.Children[character]

        if not child then
            return false
        end

        table.insert(path, {
            Parent = node,
            Character = character,
            Node = child,
        })

        node = child
    end

    if not node.IsTerminal then
        return false
    end

    node.IsTerminal = false
    node.Value = nil
    self._size -= 1

    for index = #path, 1, -1 do
        local entry = path[index]
        local childNode = entry.Node

        if childNode.IsTerminal or next(childNode.Children) ~= nil then
            break
        end

        entry.Parent.Children[entry.Character] = nil
    end

    return true
end

function TriePrototype.Complete(self: any, prefix: string, limit: number?): {string}
    local node = self._root

    for index = 1, #prefix do
        node = node.Children[string.sub(prefix, index, index)]
        if not node then
            return {}
        end
    end

    local results = {}
    local maximum = limit or 32
    local buffer = {prefix}

    local function visit(current: TrieNode, depth: number)
        if #results >= maximum then
            return
        end

        if current.IsTerminal then
            table.insert(results, table.concat(buffer))
        end

        local keys = {}
        for character in current.Children do
            table.insert(keys, character)
        end
        table.sort(keys)

        for _, character in keys do
            buffer[depth + 1] = character
            visit(current.Children[character], depth + 1)
            buffer[depth + 1] = nil

            if #results >= maximum then
                return
            end
        end
    end

    visit(node, #prefix)
    return results
end

function TriePrototype.Clear(self: any)
    self._root = createNode()
    self._size = 0
end

return Trie
