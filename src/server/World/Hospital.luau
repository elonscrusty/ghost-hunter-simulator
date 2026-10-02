--!strict
-- placeholder: built by the zone pass
local Kit = require(script.Parent.Kit)

local Hospital = {}

function Hospital.Build(map: Instance)
	Kit.Folder(map, "Hospital")
end

return Hospital
