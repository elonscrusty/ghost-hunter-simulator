--!strict
-- placeholder: built by the zone pass
local Kit = require(script.Parent.Kit)

local Throne = {}

function Throne.Build(map: Instance)
	Kit.Folder(map, "Throne")
end

return Throne
