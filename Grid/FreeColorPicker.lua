-----------------------------------------------------------------------------------------------
-- FreeColorPicker.lua by WildcardC
-- TODO: add license here
-----------------------------------------------------------------------------------------------
 
require "Window"

local function CColorToString(c)
	return string.format("%02x%02x%02x%02x", c.a * 255, c.r * 255, c.g * 255, c.b * 255)
end

local function StringToCColor(s)
	local a,r,g,b = string.match(s, "^([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])$")

	if b == nil then return nil end

	a = tonumber(a, 16) / 255
	r = tonumber(r, 16) / 255
	g = tonumber(g, 16) / 255
	b = tonumber(b, 16) / 255

	return CColor.new(r, g, b, a)
end
 
local FreeColorPicker = {}

function FreeColorPicker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

Apollo.GetAddon("Grid").options.colorPicker = FreeColorPicker:new()

function FreeColorPicker:Pick(initialColor, callback, param, object, settings)
	self.callback = callback
    self.param = param
    self.object = object
    self.settings = settings

    self.oldColor = initialColor
    self:ApplyCColor(initialColor)

    self.wndOldColor:SetBGColor(CColor.new(self.oldColor.r, self.oldColor.g, self.oldColor.b, 1.0))

    self.wndColorPicker:Show(true)
    self.wndColorPicker:ToFront()
end

function FreeColorPicker:OnLoad()
	Apollo.LoadSprites("FreeColorPickerTextures.xml", "FreeColorPickerSprites")

	self.xmlDoc = XmlDoc.CreateFromFile("FreeColorPicker.xml")
    self.wndColorPicker = Apollo.LoadForm(self.xmlDoc, "ColorPicker", nil, self)

    self.wndHS1 = self.wndColorPicker:FindChild("hs1")
    self.wndHS1Wrap = self.wndColorPicker:FindChild("hs1wrap")
    self.wndValue = self.wndColorPicker:FindChild("value")
    self.wndAlpha = self.wndColorPicker:FindChild("alpha")
    self.wndNewColor = self.wndColorPicker:FindChild("newcolor")
    self.wndOldColor = self.wndColorPicker:FindChild("oldcolor")

    self.wndValueCursor = self.wndColorPicker:FindChild("valuecursor")
    self.wndHS1Cursor = self.wndColorPicker:FindChild("hs1cursor")
    self.wndAlphaCursor = self.wndColorPicker:FindChild("alphacursor")

    self.wndHexText = self.wndColorPicker:FindChild("hextext")

    self.wndColorPicker:Show(false)
end

local function HSV2RGB(h, s, v)
	h = h * 360 / 60

	local c = v * s
	local x = c * (1 - math.abs(h % 2 - 1))

	local r, g, b

	if 0 <= h and h < 1 then
        r = c
        g = x
        b = 0
    elseif 1 <= h and h < 2 then
        r = x
        g = c
        b = 0
    elseif 2 <= h and h < 3 then
        r = 0
        g = c
        b = x
    elseif 3 <= h and h < 4 then
        r = 0
        g = x
        b = c
    elseif 4 <= h and h < 5 then
        r = x
        g = 0
        b = c
    elseif 5 <= h and h < 6 then
        r = c
        g = 0
        b = x
    else
        r = 0
        g = 0
        b = 0
    end

    local m = v - c
    r = r + m
    g = g + m
    b = b + m

    return r, g, b
end


function FreeColorPicker:ApplyCColor(c)
	self.color = c

	local h,s,_ self:CurrentHSV()

	self.selectedH = h
	self.selectedS = s

	self:ColorChanged()
end

function FreeColorPicker:ApplyHSV(h, s, v)
	if self:CurrentHSV() == 0 and v > 0 and self.selectedH ~= nil then
		h = self.selectedH
		s = self.selectedS
	end

	local r, g, b = HSV2RGB(h, s, v)

    self.color = CColor.new(r, g, b, self.color.a)
    self:ColorChanged()
end

function FreeColorPicker:CurrentHSV()
	local r,g,b = self.color.r, self.color.g, self.color.b
	local h,s,v

	local M = math.max(r, g, b)
	local m = math.min(r, g, b)
	local C = M - m

	if C == 0 then
		h = 0
	elseif M == r then
		h = ((g - b)/C) % 6
	elseif M == g then
		h = (b - r) / C + 2
	elseif M == b then
		h = (r - g) / C + 4
	else
		assert(false)
	end

	h = h * 60 / 360

	v = M

	if C == 0 then
		s = 0
	else
		s = C / v
	end

	return h,s,v
end



function FreeColorPicker:ColorChanged()
	local ntcol = CColor.new(self.color.r, self.color.g, self.color.b, 1.0)

	self.wndNewColor:SetBGColor(ntcol)

	local h,s,v = self:CurrentHSV()

	if self.selectedH == nil then
		self.selectedH, self.selectedS = h, s
	end

    local r,g,b = HSV2RGB(self.selectedH, self.selectedS, 1.0)
    self.wndValue:SetBGColor(CColor.new(r, g, b, 1.0))

   	self.wndAlpha:SetBGColor(ntcol)
    self:ApplyValueMarker()
    self:ApplyHS1Marker()
    self:ApplyAlphaMarker()

    self.wndHexText:SetText(CColorToString(self.color))

    if self.callback ~= nil then
    	if self.object ~= nil then
    		self.callback(self.object, self.color, self.param)
    	else
    		self.callback(self.color, self.param)
    	end
    end
end



function FreeColorPicker:ApplyValueMarker()
	local l,t,r,b = self.wndValue:GetAnchorOffsets()

	local _,_,v = self:CurrentHSV()
	v = v * 255

	local y = t + v - 9/2
	self.wndValueCursor:SetAnchorOffsets(r, y, r + 5, y + 9)
end

function FreeColorPicker:ApplyHS1Marker()
	if self.selectedH == nil then return end

	local l,t,r,b = self.wndHS1:GetAnchorOffsets()

	local h = self.selectedH * 256
	local s = self.selectedS * 255

	local x = l + h - 7/2
	local y = t + 255 - s - 7/2

	self.wndHS1Cursor:SetAnchorOffsets(x, y, x + 7, y + 7)
end

function FreeColorPicker:ApplyAlphaMarker()
	local l,t,r,b = self.wndAlpha:GetAnchorOffsets()

	local a = self.color.a * 255

	local y = 255 - a + t - 9/2
	self.wndAlphaCursor:SetAnchorOffsets(r, y, r + 5, y + 9)
end



function FreeColorPicker:ApplyValue(y)
	local _,t = self.wndValue:GetAnchorOffsets()
	y = y - t
	y = math.max(0, math.min(y, 255))

	local h,s = self:CurrentHSV()
	self:ApplyHSV(h, s, y/255)
end

function FreeColorPicker:ApplyHS1(x, y)
	local l,t = self.wndHS1:GetAnchorOffsets()
	x = x - l
	y = y - t

	x, y = math.max(0, math.min(x, 255)), 255 - math.max(0, math.min(y, 255))

	local _,_,v = self:CurrentHSV()
	local h,s = x/256, y/255
	self.selectedH = h
	self.selectedS = s
	self:ApplyHSV(h, s, v)
end

function FreeColorPicker:ApplyAlpha(y)
	local _,t = self.wndAlpha:GetAnchorOffsets()
	y = y - t
	y = 255 - math.max(0, math.min(y, 255))

	local a = y/255

	self.color = CColor.new(self.color.r, self.color.g, self.color.b, a)
	self:ColorChanged()
end


function FreeColorPicker:OnHS1MouseDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	self.selectingHS1 = true
	self:ApplyHS1(nLastRelativeMouseX, nLastRelativeMouseY)
end

function FreeColorPicker:OnHS1MouseMove(wndHandler, wndControl, x, y)
	if self.selectingHS1 then
		self:ApplyHS1(x, y)
	end
end

function FreeColorPicker:OnHS1MouseUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	self.selectingHS1 = false
end

function FreeColorPicker:OnHS1MouseExit()
	self.selectingHS1 = false
end



function FreeColorPicker:OnValueMouseDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	self.selectingValue = true
	self:ApplyValue(nLastRelativeMouseY)
end

function FreeColorPicker:OnValueMouseMove(wndHandler, wndControl, x, y)
	if self.selectingValue then
		self:ApplyValue(y)
	end
end

function FreeColorPicker:OnValueMouseUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	self.selectingValue = false
end

function FreeColorPicker:OnValueMouseExit()
	self.selectingValue = false
end



function FreeColorPicker:OnAlphaMouseDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	self.selectingAlpha = true
	self:ApplyAlpha(nLastRelativeMouseY)
end

function FreeColorPicker:OnAlphaMouseMove(wndHandler, wndControl, x, y)
	if self.selectingAlpha then
		self:ApplyAlpha(y)
	end
end

function FreeColorPicker:OnAlphaMouseUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	self.selectingAlpha = false
end

function FreeColorPicker:OnAlphaMouseExit()
	self.selectingAlpha = false
end



function FreeColorPicker:OnTextChanged(wndHandler, wndControl, strText)
	local c = StringToCColor(strText)

	if c == nil then
		wndControl:SetTextColor("xkcdlightgrey")
		return
	end

	wndControl:SetTextColor("white")

	self:ApplyCColor(c)
end

function FreeColorPicker:OnOldColorMouseDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	self:ApplyCColor(self.oldColor)
end

function FreeColorPicker:OnOKButtonSignal()
	self.wndColorPicker:Show(false)
end

function FreeColorPicker:Cancel()
	if not self.wndColorPicker:IsShown() then return end

	self:ApplyCColor(self.oldColor)
	self.wndColorPicker:Show(false)
end
