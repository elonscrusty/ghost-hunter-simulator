--!strict
-- Server → client effect/announcement messages over the "Fx" remote.
-- Kinds: Poof, Announce, ZoneUnlocked, Boss, Toast, Upgrade, Daily (see docs/ARCHITECTURE.md).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("GH").Net)

local Fx = {}
local remote: RemoteEvent

function Fx.Init()
	remote = Net.Event("Fx")
end

function Fx.All(kind: string, data: any?)
	remote:FireAllClients(kind, data)
end

-- Everyone except one player (e.g. the opener of a legendary crate, who sees the reveal).
function Fx.AllExcept(except: Player, kind: string, data: any?)
	for _, pl in game:GetService("Players"):GetPlayers() do
		if pl ~= except then
			remote:FireClient(pl, kind, data)
		end
	end
end

function Fx.To(player: Player, kind: string, data: any?)
	remote:FireClient(player, kind, data)
end

function Fx.Toast(player: Player, text: string, color: string?)
	remote:FireClient(player, "Toast", { Text = text, Color = color })
end

return Fx
