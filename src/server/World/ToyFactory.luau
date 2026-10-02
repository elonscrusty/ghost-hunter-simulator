--!strict
-- placeholder: built by the zone pass
local Kit = require(script.Parent.Kit)

local ToyFactory = {}

function ToyFactory.Build(map: Instance)
	Kit.Folder(map, "ToyFactory")
end

return ToyFactory
