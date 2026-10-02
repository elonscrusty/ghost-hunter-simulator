--!strict
-- placeholder: built by the zone pass
local Kit = require(script.Parent.Kit)

local Inferno = {}

function Inferno.Build(map: Instance)
	Kit.Folder(map, "Inferno")
end

return Inferno
