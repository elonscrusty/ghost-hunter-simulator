--!strict
-- Minimal signal. Unlike a BindableEvent, arguments are passed by reference (BindableEvents
-- deep-copy tables and turn Instance keys into strings), and each handler runs in its own
-- thread so one failing handler can't break the others.
export type Connection = { Connected: boolean, Disconnect: (Connection) -> () }
export type Signal = {
	Connect: (Signal, (...any) -> ()) -> Connection,
	Fire: (Signal, ...any) -> (),
	Wait: (Signal) -> ...any,
}

local Signal = {}

function Signal.new(): Signal
	local handlers: { [Connection]: (...any) -> () } = {}
	local waiting: { thread } = {}
	local self = {} :: Signal

	function self.Connect(_: Signal, fn: (...any) -> ()): Connection
		local conn = { Connected = true } :: Connection
		function conn.Disconnect(c: Connection)
			c.Connected = false
			handlers[c] = nil
		end
		handlers[conn] = fn
		return conn
	end

	function self.Fire(_: Signal, ...: any)
		for conn, fn in handlers do
			if conn.Connected then
				task.spawn(fn, ...)
			end
		end
		if #waiting > 0 then
			local list = waiting
			waiting = {}
			for _, th in list do
				task.spawn(th, ...)
			end
		end
	end

	function self.Wait(_: Signal): ...any
		table.insert(waiting, coroutine.running())
		return coroutine.yield()
	end

	return self
end

return Signal
