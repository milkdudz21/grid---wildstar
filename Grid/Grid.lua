-----------------------------------------------------------------------------------------------
-- Grid.lua by WildcardC
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Unit"
require "GroupLib"
require "GameLib"

local dispellIndicatorCount = 8
 
local Grid = {}

local defaultSettings
local GridEnum
local Util

function Grid:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function Grid:Init()
    Apollo.RegisterAddon(self)
end

local GridInst = Grid:new()
GridInst:Init()

function Grid:GetClientSize()
	local settings = self.settings

	local grpSize = self:GetGrpSize()

	local numCols = math.min(settings.playersPerRow, grpSize)
	local numRows = math.ceil( grpSize / settings.playersPerRow )

	if Util.IsVertical(self.settings.primaryGrowth) then
		numCols, numRows = numRows, numCols -- swap
	end

	local w = 2 * settings.padding +
		numCols * settings.cellWidth +
		(numCols - 1) * settings.cellHorizontalSpacing
	
	local h = 2 * settings.padding +
		settings.cellHeight * numRows +
		(numRows - 1) * settings.cellVerticalSpacing

	return w, h
end

function Grid:Resize()
	for i = 0, self.cellsLoaded-1 do
		self.Frame[i].window:Show(false)
	end
	self.cellsLoaded = 0
	self.cellsShown = 0

	local c = self:CalcCellPosition(0)
	local l, t = self.settings.left - c.x, self.settings.top - c.y
	local w, h = self:GetClientSize()

	self.clientArea:SetAnchorOffsets(l, t, l + w, t + h)
end

function Grid:ApplySettings()
	self:Resize()
	
	if self.settings.locked then
		self.clientArea:RemoveStyle("Moveable")
	else
		self.clientArea:AddStyle("Moveable")
	end

	self.options:ApplySettingsToOptionDialogue()
end

function Grid:OnLoad()
	defaultSettings = self.defaultSettings
	GridEnum = self.GridEnum
	Util = self.Util

	Apollo.RegisterSlashCommand("grid", "OnSlashGrid", self)

	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)

	Apollo.RegisterEventHandler("Group_UpdatePosition", "OnGroupUpdatePosition", self)

	self.xmlDoc = XmlDoc.CreateFromFile("Grid.xml")
    self.clientArea = Apollo.LoadForm(self.xmlDoc, "ClientArea", nil, self)

    Apollo.LoadSprites("Textures.xml", "GridSprites")

    self:ResetMembers()

    self.settings = Util.CopyTable(defaultSettings)
	self:ApplySettings()

    self.clientArea:Show(true)

    self.options:OnLoad()
end

function Grid:ResetMembers()
	self.cellsLoaded = 0
	self.cellsShown = 0
	self.oldTargetSet = false
	self.inCombatMobs = {}
	self.prevGroupSize = 0
end

function Grid:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	return self.settings
end

function Grid:OnRestore(eType, tData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	if tData ~= nil then
		for Dkey, Dvalue in pairs(defaultSettings) do
			if tData[Dkey] ~= nil then -- DO NOT MODIFY THIS to "if tData[Dkey] then" - will not behave as expected for booleans
				self.settings[Dkey] = tData[Dkey]
			end
		end
	end

	self:ApplySettings()
end

function Grid:GetGrpSize()
	return math.max(1, GroupLib.GetMemberCount())
end

function Grid:ApplyBarStyles(bar, bargrowth)
	if bar and bargrowth then
		if math.floor(bargrowth / 2) < 1 then bar:RemoveStyleEx("VerticallyAligned")
		else bar:AddStyleEx("VerticallyAligned") end

		if bargrowth % 2 == 0 then bar:RemoveStyleEx("BRtoLT")
		else bar:AddStyleEx("BRtoLT") end
	end
end

function Grid:InitCell(index)
	if self.Frame == nil then
		self.Frame = { }
	end

	-- reload shenanigans
	local window
	if self.Frame[index] == nil or self.Frame[index].window == nil then
		window = Apollo.LoadForm(self.xmlDoc, "Cell", self.clientArea, self)
	elseif self.Frame[index].window ~= nil then
		window = self.Frame[index].window
	end

	local pos = self:CalcCellPosition(index)

	local frame = 
	{
		index = index,
		window = window,
		position = pos,

		innerCell = window:FindChild("InnerCell"),

		wndHealthBar = window:FindChild("HealthBar"),
		wndHealthText = window:FindChild("HealthText"),

		wndInterruptArmor = window:FindChild("InterruptArmor"),
		wndAggroIndicator = window:FindChild("AggroIndicator"),
		wndCCIndicator = window:FindChild("CCIndicator"),
		wndOOMIndicator = window:FindChild("OOMIndicator"),
		wndAbsorbIndicator = window:FindChild("AbsorbIndicator"),
		wndDispellIndicator = {},
		wndShieldBar = window:FindChild("ShieldBar"),

		lastShownDispellIndicator = -1,
	}

	window:SetAnchorOffsets(pos.x, pos.y, pos.x + self.settings.cellWidth, pos.y + self.settings.cellHeight)

	if self.settings.locked and self.settings.clickToSelect then
		window:RemoveStyle("IgnoreMouse")
	else
		window:AddStyle("IgnoreMouse")
	end

	self:LayoutCellPart(frame.innerCell, GridEnum.LayoutAnchor.MiddleCenter, nil, self.settings.cellBorderWidth)

	for i = 1, dispellIndicatorCount do
		local ind = window:FindChild("DispellIndicator" .. i)
		
		self:LayoutCellPart(ind, GridEnum.LayoutAnchor.MiddleCenter, { x = self.settings.dispellIndicatorScale, y = self.settings.dispellIndicatorScale, auto = true })

		ind:Show(false)
		frame.wndDispellIndicator[i] = ind
	end

	frame.wndHealthText:SetTextColor(self.settings.colorMissingHealth)
	frame.wndShieldBar:SetBarColor(self.settings.colorShield)

	frame.wndAggroIndicator:SetSprite(self.settings.aggroIndicatorSprite)
	frame.wndAggroIndicator:SetBGColor(self.settings.colorAggro)

	self:ApplyBarStyles(frame.wndHealthBar, self.settings.healthBarGrowth)
	Util.GridLayoutAnchorToTextAnchor(frame.wndHealthBar, self.settings.nameAnchor)
	self:LayoutCellPart(frame.wndHealthBar)
	self:LayoutCellPart(frame.wndShieldBar, self.settings.shieldAnchor, { x = 1.0, y = self.settings.shieldHeight, absy = true })
	if self.settings.shieldAnchor % 3 == 0 then
		self:ApplyBarStyles(frame.wndShieldBar, GridEnum.BarGrowth.LeftToRight)
	else
		self:ApplyBarStyles(frame.wndShieldBar, GridEnum.BarGrowth.RightToLeft)
	end

	self:LayoutCellPart(frame.wndAggroIndicator)
	self:LayoutCellPart(frame.wndHealthText, GridEnum.LayoutAnchor.MiddleCenter, nil)
	Util.GridLayoutAnchorToTextAnchor(frame.wndHealthText, self.settings.healthTextAnchor)

	self:LayoutCellPart(frame.wndInterruptArmor, GridEnum.LayoutAnchor.TopLeft, { x = 0.25, y = 0.25, auto = true }, 5)
	self:LayoutCellPart(frame.wndCCIndicator, GridEnum.LayoutAnchor.TopLeft, { x = 0.25, y = 0.25, auto = true }, 5)
	self:LayoutCellPart(frame.wndOOMIndicator, GridEnum.LayoutAnchor.TopLeft, { x = 0.25, y = 0.25, auto = true }, 5)
	self:LayoutCellPart(frame.wndAbsorbIndicator, GridEnum.LayoutAnchor.TopRight, { x = 0.25, y = 0.25, auto = true }, 5)

	window:SetData(frame)

	if index >= self.cellsLoaded then
		self.cellsLoaded = index + 1
	end

	self.Frame[index] = frame
end

function Grid:LayoutCellPart(wnd, anchor, scale, padding)
	anchor = anchor or GridEnum.LayoutAnchor.MiddleCenter
	padding = padding or { }
	if type(padding) ~= "table" then
		padding = { left = padding, top = padding, right = padding, bottom = padding }
	else
		padding = { left = padding.left or 0, top = padding.top or 0, right = padding.right or 0, bottom = padding.bottom or 0 }
	end
	scale = scale or { x = 1.0, y = 1.0 }

	local parent = wnd:GetParent()

	local pl, pt, pr, pb = parent:GetAnchorOffsets()
	local pw, ph = pr - pl, pb - pt
	local w, h
	if scale.auto then
		local s = math.min(pw, ph)
		w, h = s * scale.x, s * scale.y
	else
		w = scale.x
		if not scale.absx then w = w * pw end

		h = scale.y
		if not scale.absy then h = h * ph end
	end
	
	local aw, ah = padding.left + w + padding.right, padding.top + h + padding.bottom
	if aw > pw then
		aw = pw
		w = pw - padding.left - padding.right
	end
	if ah > ph then
		ah = ph
		h = ph - padding.top - padding.bottom
	end

	local leftoverw, leftoverh = pw - aw, ph - ah

	local vmul = math.floor(anchor / 3) / 2
	local hmul = (anchor % 3) / 2

	local l = hmul * leftoverw + padding.left
	local t = vmul * leftoverh + padding.right

	wnd:SetAnchorOffsets(l, t, l + w, t + h)
end

function Grid:GetInnerCellSize()
	return self.settings.cellWidth - 2*self.settings.cellBorderWidth, self.settings.cellHeight - 2*self.settings.cellBorderWidth
end

function Grid:CalcCellPosition(index)
	local iprim = index % self.settings.playersPerRow
	local isec = math.floor(index / self.settings.playersPerRow)
	local grpSize = self:GetGrpSize() 

	if Util.NeedsInversion(self.settings.primaryGrowth) then
		iprim = math.min(grpSize, self.settings.playersPerRow) - 1 - iprim
	end
	if Util.NeedsInversion(self.settings.secondaryGrowth) then
		isec = math.ceil(grpSize / self.settings.playersPerRow) - 1 - isec
	end

	if Util.IsVertical(self.settings.primaryGrowth) then
		iprim, isec = isec, iprim -- swap
	end

	local pos = 
	{
		x = self.settings.padding + iprim * (self.settings.cellWidth + self.settings.cellHorizontalSpacing),
		y = self.settings.padding + isec * (self.settings.cellHeight + self.settings.cellVerticalSpacing)
	}

	return pos
end

function Grid:IsUnitMob(unit)
	return unit ~= nil and unit:GetType() == "NonPlayer" and unit:GetDispositionTo(GameLib.GetPlayerUnit()) ~= Unit.CodeEnumDisposition.Friendly
end

-- poor workaround for aggro indicator in scenarios where you do not witness the unit entering combat
-- does not even work anymore as of Ops Week
function Grid:OnUnitCreated(unit)
	if self.settings.enableAggroIndicator and self:IsUnitMob(unit) and unit:IsInCombat() then
		self.inCombatMobs[unit:GetId()] = unit
	end
end

function Grid:OnUnitDestroyed(unit)
	if self.settings.enableAggroIndicator and self:IsUnitMob(unit) then
		self.inCombatMobs[unit:GetId()] = nil
	end
end

function Grid:OnUnitEnteredCombat(unit, bInCombat)
	if unit == nil or not unit:IsValid() then return end

	if self.settings.enableAggroIndicator and self:IsUnitMob(unit) then
		if bInCombat then
			self.inCombatMobs[unit:GetId()] = unit
		else
			self.inCombatMobs[unit:GetId()] = nil
		end
	end
end

function Grid:OnGroupUpdatePosition(arMembers)
	if not arMembers or self.Frame == nil then return end
	
	local zoneMap = GameLib.GetCurrentZoneMap()
	if zoneMap == nil then return end

	local myZoneID = zoneMap.id

	for _, member in pairs(arMembers) do
		local id = member.nIndex - 1

		if member.tZoneMap ~= nil then
			if id ~= 0 and self.Frame[id] ~= nil then
				if member.tZoneMap.id == myZoneID then
					self.Frame[id].lastKnownPosition = member.tWorldLoc
				else
					self.Frame[id].lastKnownPosition = nil
				end
			end
		end
	end
end

function Grid:OnGridMove()
	local l,t = self.clientArea:GetAnchorOffsets()
	local c = self:CalcCellPosition(0)

	self.settings.left = l + c.x
	self.settings.top = t + c.y
end

function Grid:OnCellMouseDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	if wndControl ~= nil and wndControl:GetName() == "Cell" then
		local unit = self:WndToUnit(wndControl)

		if unit ~= nil then
			if self.settings.clickToSelect and eMouseButton == 0 then
				GameLib.SetTargetUnit(unit)

				if self.settings.rememberPrevTarget then
					self.prevTarget = unit
				end
			elseif self.settings.rightClickMenu and eMouseButton == 1 then
				Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", wndHandler, unit:GetName(), unit)
			end
		end
	end
end

function Grid:OnGridMouseEnter(wndHandler, wndControl, eButton)
	if wndControl == nil or not self.settings.mouseOverSelection then return end

	if wndControl:GetName() == "Cell" then
		if self.settings.rememberPrevTarget and not self.oldTargetSet then
			self.prevTarget = GameLib.GetTargetUnit()
			self.oldTargetSet = true
		end

		local unit = self:WndToUnit(wndControl)

		if unit ~= nil then
			GameLib.SetTargetUnit(unit)
		end
	end
end

function Grid:OnGridMouseExit(arg1, arg2, locX, locY)
	if self.settings.mouseOverSelection and self.settings.rememberPrevTarget and arg1 ~= nil and arg2 ~= nil and arg1 == arg2 and arg1 == self.clientArea then
		GameLib.SetTargetUnit(self.prevTarget)
		self.oldTargetSet = false
	end
end

function Grid:WndToUnit(wnd)
	local id = self:WndToIndex(wnd)

	if id == nil then return nil end

	return self:IndexToUnit(id)
end

function Grid:IndexToUnit(index)
	local grpSize = self:GetGrpSize()

	if grpSize == 1 then
		return GameLib.GetPlayerUnit()
	else
		return GroupLib.GetUnitForGroupMember(index+1)
	end
end

function Grid:WndToIndex(wnd)
	local d = wnd:GetData()

	if d == nil then return nil end

	return d.index
end

function Grid:UnitToFrame(unit)
	if self.Frame == nil then return end

	local grpSize = self:GetGrpSize()

	if grpSize == 1 and unit:IsThePlayer() then
		return self.Frame[0]
	else
		for i = 0, grpSize-1 do
			if GroupLib.GetUnitForGroupMember(i+1) == unit then
				return self.Frame[i]
			end
		end
	end

	return nil
end

---------------------------------------------------------------------------------------------------------------

 -- workaround for DT_RIGHT
local function TextFix(text, anchor)
	if anchor % 3 == 1 then return text .. " " else return text end
end

function Grid:GetHealthText(mhp, hp, dead)
	if not self.settings.displayHealthText then return "" end
	if dead or (hp <= 0 and mhp > 0) then return "dead" end
	if mhp <= 0 then return "" end

	local unt = self.settings.healthPercent and "%" or "k"
	local pfx = self.settings.displayMissingHealth and -1 or 1
	local mul = self.settings.healthPercent and 100 or 1/1000
	local max = self.settings.healthPercent and 1 or mhp

	local val = self.settings.healthPercent and (hp/mhp) or hp
	if self.settings.displayMissingHealth then val = max - val end

	if self.settings.healthPercent then -- because 0% and -100% would look stupid in the respective cases
		val = self.settings.displayMissingHealth and math.min(val, 0.99) or math.max(0.01, val)
	end

	val = math.floor(val * mul + 0.5)

	-- could argue for a threshold setting
	if self.settings.displayMissingHealth and val < 1 then return "" end

	return pfx * math.ceil(val) .. unt
end

function Grid:UpdateBar(frame, mhp, hp, msh, sh, classId, name, dead)
	local classColor = self.settings.classColors[classId]

	if dead then
		frame.innerCell:SetBGColor(self.settings.colorDead)
		frame.wndHealthBar:SetTextColor(self.settings.colorTextDead)
	else
		if self.settings.invertHealthBarCols then
			frame.wndHealthBar:SetBarColor("99000000")
			frame.innerCell:SetBGColor(classColor)
		else
			frame.innerCell:SetBGColor(Util.StringToCColor(classColor) * CColor.new(0.4, 0.4, 0.4, 1.0))
			frame.wndHealthBar:SetBarColor(classColor)
		end
		frame.wndHealthBar:SetTextColor(self.settings.colorText)
	end

	if self.settings.displayName then
		frame.wndHealthBar:SetText(TextFix(name, self.settings.nameAnchor))
	else
		frame.wndHealthBar:SetText("")
	end

	if mhp > 0 then
		frame.wndHealthBar:SetProgress(hp / mhp)
	end

	frame.wndHealthText:SetText(self:GetHealthText(mhp, hp, dead))

	if self.settings.displayShields and msh > 0 and mhp > 0 and hp > 0 then
		frame.wndShieldBar:SetProgress(sh / msh)		
		frame.wndShieldBar:Show(true)
	else
		frame.wndShieldBar:Show(false)
	end
end

-- TODO: i hear vector3 is a thing
function Grid:RangeCheck(unit1, unit2, range)
	local v1 = unit1:GetPosition()
	local v2 = unit2:GetPosition()

	local dx, dy, dz = v1.x - v2.x, v1.y - v2.y, v1.z - v2.z

	return dx*dx + dy*dy + dz*dz <= range*range
end

function Grid:SetCellOpacity(frame, unit)
	local player = GameLib.GetPlayerUnit()
	if player == nil then return end

	local opacity = self.settings.baseOpacity

	if not unit:IsInCombat() then
		opacity = opacity * self.settings.nonCombatOpacity
	end

	if unit ~= player and (unit == nil or not self:RangeCheck(unit, player, self.settings.unitMaxDistance) ) then
		opacity = opacity * self.settings.rangedOpacity
	end

	frame.window:SetOpacity(opacity, 1)
end

function Grid:DrawPixieLine(wnd, x1, y1, x2, y2)
	local loc = {
		fPoints = {0,0,0,0},
		nOffsets = {x1,y1,x2,y2}
	}

	wnd:AddPixie({
		iLayer = 2,
		bLine = true,
		fWidth = self.settings.arrowIndicatorWidth,
		strSprite = "ClientSprites:WhiteFill",
		cr = self.settings.arrowIndicatorColor,
		loc = loc})
end

-- TODO: i hear vector3 is a thing
function Grid:DrawPositionIndicator(frame, upos)
	if upos == nil then return end

	local player = GameLib.GetPlayerUnit()
	if not player then return end

	local ppos = player:GetPosition()

	local pf = player:GetFacing()

	local dx, dz = ppos.x - upos.x, ppos.z - upos.z
	local l = math.sqrt(dx*dx + dz*dz)

	if l < self.settings.arrowIndicatorDistanceThreshold then return end

	dx, dz = dx/l, dz/l
	
	local cx, cy = self:GetInnerCellSize()
	cx, cy = cx/2, cy/2

	local s = math.min(cx, cy) * self.settings.arrowIndicatorScale

	local apf = math.atan2(pf.x, pf.z) -- may be possible to substitute player:GetHeading()?
	local au = math.atan2(dx, dz)
	local facea = apf - au + math.pi/2

	local p1x = cx + s * math.cos(facea)
    local p1y = cy + s * math.sin(facea)

    local a = 3 * math.pi / 8

    local p2x = cx + s * math.cos(facea + a)
    local p2y = cy + s * math.sin(facea + a)

    local p3x = cx + s * math.cos(facea - a)
    local p3y = cy + s * math.sin(facea - a)

    self:DrawPixieLine(frame.wndHealthBar, p1x, p1y, p2x, p2y)
    self:DrawPixieLine(frame.wndHealthBar, p1x, p1y, p3x, p3y)

    -- kinda just doing this here for convenience
    frame.lastKnownPosition = upos
end

local dispellPriorities = {
	["Electric Charge"] = 100, -- Stormtalon - not flagged as dispellable

	-- healing debuffs --
	["Augmented Blade"] = 50,
	["Phlebotomize"] = 50,
	["Unstable Anomaly"] = 50,

	-- roots --
	["Restraint"] = 25,
	["Flash Freeze"] = 25,

	-- blinds --
	["Flash Bang"] = 18,
	["Obstruct Vision"] = 18,

	-- severe slows --
	["Chill"] = 10,

	["Pounce"] = -1, -- Stalker Pounce buff - wrongly flagged as debuff, will just hide it
}

function Grid:UpdateDispellIndicator(frame, unit)
	local debuffs = unit:GetBuffs()
	if debuffs ~= nil then debuffs = debuffs.arHarmful end

	if frame.lastShownDispellIndicator > 0 then
		frame.wndDispellIndicator[frame.lastShownDispellIndicator]:Show(false)
	end

	if not self.settings.enableDispellIndicator then return end

	if debuffs ~= nil then
		local maxTR = 0
		local maxI = -1
		local maxP = 0
		local maxdebuff = math.min(dispellIndicatorCount, #debuffs)
		for i = 1, maxdebuff do
			local name = debuffs[i].splEffect:GetName()
			local P = dispellPriorities[name] or 0
			if (P >= 0 and debuffs[i].splEffect:GetClass() == Spell.CodeEnumSpellClass.DebuffDispellable) or P > 0 then
				if maxI == -1 or P > maxP or (P == maxP and debuffs[i].fTimeRemaining > maxTR) then
					maxI = i
					maxTR = debuffs[i].fTimeRemaining
					maxP = P
				end
			end
		end

		if maxI > 0 then
			frame.wndDispellIndicator[maxI]:SetUnit(unit)
			frame.lastShownDispellIndicator = maxI
			frame.wndDispellIndicator[maxI]:Show(true)
		end
	end
end

function Grid:UpdateAggroIndicator(frame, unit)
	local hasAggro = false
	if self.settings.enableAggroIndicator and unit:IsInCombat() then
		for hkey, h_unit in pairs(self.inCombatMobs) do
			if h_unit:GetTarget() == unit then
				hasAggro = true
				break
			end
		end
	end

	frame.wndAggroIndicator:Show(hasAggro)
end

function Grid:UpdateMiscIndicators(frame, unit)
	local ia = unit:GetInterruptArmorValue()
	local class = unit:GetClassId()
	local iia, icc, ioom = false, false, false
	-- TODO: cleanup, list of CCs to count
	if unit:IsInCCState(Unit.CodeEnumCCState.Stun) or unit:IsInCCState(Unit.CodeEnumCCState.Disable) or unit:IsInCCState(Unit.CodeEnumCCState.Subdue) then
		icc = true
	elseif ia > 0 then
		frame.wndInterruptArmor:SetText(ia)
		iia = true
	elseif class == GameLib.CodeEnumClass.Esper or class == GameLib.CodeEnumClass.Spellslinger or class == GameLib.CodeEnumClass.Medic then
		local f = unit:GetFocus()
		local maxf = unit:GetMaxFocus()

		-- ugly as a duck but GetMaxMana returns 0 for anything but the player. boo.
		if maxf <= 0 then maxf = 1000 end
		if f > maxf then maxf = f end

		local frate = f / maxf
		ioom = frate < self.settings.oomThreshold
		
		frame.wndOOMIndicator:SetOpacity(1 - frate)
	end

	frame.wndInterruptArmor:Show(self.settings.enableIAIndicator and iia)
	frame.wndCCIndicator:Show(self.settings.enableCCIndicator and icc)
	frame.wndOOMIndicator:Show(self.settings.enableOOMIndicator and ioom)
	frame.wndAbsorbIndicator:Show(unit:GetMaxHealth() > 0 and unit:GetAbsorptionValue() / unit:GetMaxHealth() >= 0.1)
end

function Grid:UpdateCellWithUnit(frame, unit)
	local mhp = unit:GetMaxHealth()
	local hp = unit:GetHealth()
	local msh = unit:GetShieldCapacityMax()
	local sh = unit:GetShieldCapacity()
	local classId = unit:GetClassId()
	local name = unit:GetName()

	self:UpdateBar(frame, mhp, hp, msh, sh, classId, name, unit:IsDead())
	self:UpdateMiscIndicators(frame, unit)

	self:SetCellOpacity(frame, unit)

	if GameLib.GetTargetUnit() == unit then
		frame.window:SetBGColor(self.settings.colorFrameSelected)		
	else
		frame.window:SetBGColor(self.settings.colorFrame)
	end

	frame.wndHealthBar:DestroyAllPixies()
	if self.settings.enableArrowIndicator and not unit:IsThePlayer() and (not self.settings.arrowIndicatorTargetOnly or unit == GameLib.GetTargetUnit()) then
		self:DrawPositionIndicator(frame, unit:GetPosition())
	end

	self:UpdateAggroIndicator(frame, unit)
	self:UpdateDispellIndicator(frame, unit)
end

function Grid:UpdateCellWithMemberInfo(frame, grpMember)
	local mhp = grpMember.nHealthMax
	local hp = grpMember.nHealth
	local msh = grpMember.nShieldMax
	local sh = grpMember.nShield
	local classId = grpMember.eClassId
	local name = grpMember.strCharacterName

	self:UpdateBar(frame, mhp, hp, msh, sh, classId, name, hp <= 0 and mhp > 0)

	if not grpMember.bIsOnline and self.settings.displayHealthText then
		frame.wndHealthText:SetText("offline")
	end

	-- cannot be selected
	frame.window:SetBGColor(self.settings.colorFrame)
	-- no unit, no information
	frame.wndInterruptArmor:Show(false)
	frame.wndCCIndicator:Show(false)
	frame.wndAggroIndicator:Show(false)
	frame.wndOOMIndicator:Show(false)
	frame.wndAbsorbIndicator:Show(false)

	frame.wndHealthBar:DestroyAllPixies()
	if self.settings.enableArrowIndicator and self.settings.arrowIndicatorGroupMember and not self.settings.arrowIndicatorTargetOnly then
		self:DrawPositionIndicator(frame, frame.lastKnownPosition)
	end
	-- for now
	frame.wndShieldBar:Show(false)
	-- no unit, thus probably not in range
	frame.window:SetOpacity(self.settings.rangedOpacity, 1)
end

function Grid:UpdateCell(index, unit, grpMember)
	local frame = self.Frame[index]

	if unit ~= nil then
		self:UpdateCellWithUnit(frame, unit)

		if self.settings.displayHealthText and grpMember ~= nil and not grpMember.bIsOnline then
			frame.wndHealthText:SetText("d/c")
		end
	elseif grpMember ~= nil then
		self:UpdateCellWithMemberInfo(frame, grpMember)
	end
end

function Grid:OnFrame()
	if self.clientArea == nil then return end

	local grpSize = self:GetGrpSize()

	if self.settings.hideWithoutGroup and grpSize <= 1 then
		self.clientArea:Show(false)
		return
	end

	self.clientArea:Show(true)

	if grpSize ~= self.prevGroupSize then
		self:Resize()
		self.prevGroupSize = grpSize
	end

	for i = 0, grpSize-1 do
		if i >= self.cellsLoaded then
			self:InitCell(i)
		end
		self.Frame[i].wndHealthBar:SetText(i)

		local unit = self:IndexToUnit(i)
		local grpMember = GroupLib.GetGroupMember(i+1)

		self:UpdateCell(i, unit, grpMember)
	end

	for i = self.cellsShown, grpSize-1 do
		self.Frame[i].window:Show(true)
	end
	self.cellsShown = grpSize
end

local function CPrint(string)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, string, "")
end

function Grid:OnSlashGrid(sCmd, sInput)
	local s = string.lower(sInput)
	if s == nil or s == "" then
		CPrint("Grid Addon")
		CPrint("Valid Commands:")
		CPrint("/grid show")
		CPrint(" > Show the addon (settings may prevent this)")
		CPrint("/grid options")
		CPrint(" > Show the options dialogue")
		CPrint("/grid lock")
		CPrint(" > Lock window position")
		CPrint("/grid unlock")
		CPrint(" > Unlock window position")
		CPrint("/grid reset")
		CPrint(" > Restore default settings")
	elseif s == "show" then
		self.clientArea:Show(true)
	elseif s == "options" then
		self.options:Show()
	elseif s == "lock" then
		self.settings.locked = true
		if self.settings.clickToSelect or self.settings.rightClickMenu then CPrint("Grid Notice: Frames have been locked while the clickToSelect or rightClickMenu setting was enabled. Grid will now swallow mouse inputs.") end
		self:ApplySettings()
	elseif s == "unlock" then
		self.settings.locked = false
		self:ApplySettings()
	elseif s == "reset" then
		self.options:Cancel()

		self.settings = Util.CopyTable(defaultSettings)
		self:ApplySettings()
	end
end
