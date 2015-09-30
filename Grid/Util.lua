local Grid = Apollo.GetAddon("Grid")

local Util = {}
Grid.Util = Util

local GridEnum = Grid.GridEnum

-- breaks for cyclic references, so avoid those.
function Util.CopyTable(t)
	local o = {}

	for k,v in pairs(t) do
		if type(v) == 'table' then
			o[k] = Util.CopyTable(v)
		else
			o[k] = v
		end
	end

	return o
end

function Util.CColorToString(c)
	return string.format("%02x%02x%02x%02x", c.a * 255, c.r * 255, c.g * 255, c.b * 255)
end

function Util.StringToCColor(color, override)
	override = override or {}

	local ac = ApolloColor.new(color)
	return CColor.new(override.r or ac.r, override.g or ac.g, override.b or ac.b, override.a or ac.a)
end

function Util.GridLayoutAnchorToTextAnchor(window, anchor)
	local v = math.floor(anchor / 3)
	local h = (anchor % 3)

	window:SetTextFlags("DT_CENTER", h == 1)
	window:SetTextFlags("DT_VCENTER", v == 1)
	window:SetTextFlags("DT_RIGHT", h == 2)
	window:SetTextFlags("DT_BOTTOM", v == 2)
end

function Util.IsVertical(growth)
	return growth >= GridEnum.BarGrowth.TopDown
end

function Util.IsHorizontal(growth)
	return not Util.IsVertical(growth)
end

function Util.NeedsInversion(growth)
	return growth == GridEnum.BarGrowth.RightToLeft or growth == GridEnum.BarGrowth.BottomUp
end