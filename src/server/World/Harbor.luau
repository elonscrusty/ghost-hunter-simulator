--!strict
-- placeholder: built by the zone pass
local Kit = require(script.Parent.Kit)

local Harbor = {}

function Harbor.Build(map: Instance)
	Kit.Folder(map, "Harbor")
end

return Harbor
