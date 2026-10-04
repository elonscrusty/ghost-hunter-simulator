--!strict
-- RETIRED: the GIANT POLTERGEIST lobby event (a server-wide boss in front of the Boss Tower) was
-- removed; the Endless Boss Tower replaces it. This module stays so older callers keep working:
-- nothing is scheduled or spawned, and TriggerNow is a harmless no-op.
-- (The "SummonEvent" Robux product is no longer sold; ShopService grants a substitute for
-- any old receipt.)
local EventService = {}

function EventService.Init() end

function EventService.Start() end

-- Old entry point (DEV button / Summon product): does nothing now. Returns false = not started.
function EventService.TriggerNow(): boolean
	return false
end

function EventService.IsBusy(): boolean
	return false
end

return EventService
