--!strict

export type Connection = {
    Connected: boolean,
    Disconnect: (self: Connection) -> (),
}

type Listener = {
    Callback: (...any) -> (),
    Connection: Connection,
}

export type Signal = {
    Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
    Once: (self: Signal, callback: (...any) -> ()) -> Connection,
    Fire: (self: Signal, ...any) -> (),
    Wait: (self: Signal) -> ...any,
    DisconnectAll: (self: Signal) -> (),
    Destroy: (self: Signal) -> (),
}

local Signal = {}
local SignalPrototype = {}
SignalPrototype.__index = SignalPrototype

function Signal.new(): Signal
    local self = {
        _listeners = {} :: {Listener},
        _destroyed = false,
        _firing = 0,
        _pendingRemoval = {} :: {[Connection]: boolean},
    }

    return setmetatable(self, SignalPrototype) :: any
end

local function removeConnection(self: any, connection: Connection)
    if self._firing > 0 then
        self._pendingRemoval[connection] = true
        return
    end

    for index = #self._listeners, 1, -1 do
        if self._listeners[index].Connection == connection then
            table.remove(self._listeners, index)
            break
        end
    end
end

function SignalPrototype.Connect(self: any, callback: (...any) -> ()): Connection
    assert(not self._destroyed, "Cannot connect to a destroyed signal")
    assert(type(callback) == "function", "Expected callback")

    local connection = {
        Connected = true,
    }

    function connection:Disconnect()
        if not self.Connected then
            return
        end

        self.Connected = false
        removeConnection(self._signal, self)
    end

    connection._signal = self

    table.insert(self._listeners, {
        Callback = callback,
        Connection = connection,
    })

    return connection :: any
end

function SignalPrototype.Once(self: any, callback: (...any) -> ()): Connection
    local connection: Connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        callback(...)
    end)

    return connection
end

function SignalPrototype.Fire(self: any, ...: any)
    if self._destroyed then
        return
    end

    local arguments = table.pack(...)
    local boundary = #self._listeners
    self._firing += 1

    for index = 1, boundary do
        local listener = self._listeners[index]
        if listener and listener.Connection.Connected then
            task.spawn(listener.Callback, table.unpack(arguments, 1, arguments.n))
        end
    end

    self._firing -= 1

    if self._firing == 0 then
        for connection in self._pendingRemoval do
            removeConnection(self, connection)
        end
        table.clear(self._pendingRemoval)
    end
end

function SignalPrototype.Wait(self: any): ...any
    assert(not self._destroyed, "Cannot wait on a destroyed signal")

    local thread = coroutine.running()
    local connection: Connection

    connection = self:Connect(function(...)
        connection:Disconnect()
        task.spawn(thread, ...)
    end)

    return coroutine.yield()
end

function SignalPrototype.DisconnectAll(self: any)
    for _, listener in self._listeners do
        listener.Connection.Connected = false
    end

    table.clear(self._listeners)
    table.clear(self._pendingRemoval)
end

function SignalPrototype.Destroy(self: any)
    if self._destroyed then
        return
    end

    self._destroyed = true
    self:DisconnectAll()
end

return Signal
