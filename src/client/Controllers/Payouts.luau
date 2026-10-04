--!strict
-- v1.6 combat toasts: your share of a shared ghost/boss kill, and crew knockouts/recoveries.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage:WaitForChild("GH").Logic.Format)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local State = require(Client.State)

local Payouts = {}

function Payouts.Init() end

function Payouts.Start()
	State.OnFx("Payout", function(d: any)
		local text = string.format("%s: %s damage -> +💚%s", string.upper(tostring(d.Name)), Format.Percent(tonumber(d.Pct) or 0), Format.Short(tonumber(d.Ecto) or 0))
		local shards = tonumber(d.Shards)
		if shards and shards > 0 then
			text ..= " +🔮" .. Format.Short(shards) .. " SHARDS"
		end
		Kit.Toast(text, "Good")
	end)
	State.OnFx("Knocked", function(d: any)
		Kit.Toast(string.format("%s knocked out! Back in %s", tostring(d.Name), Format.Time((tonumber(d.Until) or 0) - State.Now())), "Bad")
	end)
	State.OnFx("Recovered", function(d: any)
		Kit.Toast(tostring(d.Name) .. " is back!", "Good")
	end)
end

return Payouts
