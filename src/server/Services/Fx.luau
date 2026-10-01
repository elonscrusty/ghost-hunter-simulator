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

function Fx.To(player: Player, kind: string, data: any?)
	remote:FireClient(player, kind, data)
end

function Fx.Toast(player: Player, text: string, color: string?)
	remote:FireClient(player, "Toast", { Text = text, Color = color })
end

return Fx
