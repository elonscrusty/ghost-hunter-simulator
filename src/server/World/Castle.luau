--!strict
-- placeholder: built by the zone pass
local Kit = require(script.Parent.Kit)

local Castle = {}

function Castle.Build(map: Instance)
	Kit.Folder(map, "Castle")
end

return Castle
