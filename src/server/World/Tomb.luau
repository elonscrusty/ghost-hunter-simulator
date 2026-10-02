--!strict
-- placeholder: built by the zone pass
local Kit = require(script.Parent.Kit)

local Tomb = {}

function Tomb.Build(map: Instance)
	Kit.Folder(map, "Tomb")
end

return Tomb
