require "Window"

local GridOptions = {}

local defaultSettings
local optionCategories
local GridEnum
local Util

function GridOptions:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

local Grid = Apollo.GetAddon("Grid")
Grid.options = GridOptions:new()

function GridOptions:OnLoad()
	optionCategories = Grid.optionCategories
	defaultSettings = Grid.defaultSettings
	GridEnum = Grid.GridEnum
	Util = Grid.Util

	self.colorPicker:OnLoad()
end

function GridOptions:Show()
	self.settings = Grid.settings

	if self.xmlOpt == nil then
		self.xmlOpt = XmlDoc.CreateFromFile("Options.xml")
		self.wndOpt = Apollo.LoadForm(self.xmlOpt, "OptionWindow", nil, self)
	end

	self.oldSettings = Util.CopyTable(self.settings)

	self:BuildOptionWindow()

	self.wndOpt:Show(true)
	self:ApplySettingsToOptionDialogue()
end

function GridOptions:BuildOptionWindow()
	if self.optCatWnd ~= nil then return end

	self.optCatWnd = {}

	local catid = 1
	for catname, cat in pairs(optionCategories) do
		local catwnd = Apollo.LoadForm(self.xmlOpt, "OptionTabs", self.wndOpt, self)

		catwnd:SetText(catname)

		for optorderidx, opt in pairs(cat) do
			local optname = opt.setting
			local t = type(defaultSettings[optname])

			local optwnd
			if t == "boolean" then
				optwnd = Apollo.LoadForm(self.xmlOpt, "BoolOpt", catwnd, self)

				local bb = optwnd:FindChild("Checkbox")
				bb:SetText(opt.description)
			elseif t == "number" then
				if opt.enum ~= nil then
					optwnd = Apollo.LoadForm(self.xmlOpt, "EnumOpt", catwnd, self)
					optwnd:SetText(opt.description)

					local cbox = optwnd:FindChild("EnumValue")
					for ename, evalue in pairs(GridEnum[opt.enum]) do
						cbox:AddItem(ename, "", evalue)
					end
				else
					optwnd = Apollo.LoadForm(self.xmlOpt, "NumOpt", catwnd, self)
					optwnd:SetText(opt.description)
				end
			elseif t == "string" then
				if string.match(optname, "color") then
					optwnd = Apollo.LoadForm(self.xmlOpt, "ColOpt", catwnd, self)
					optwnd:SetText(opt.description)
				end
			elseif t == "table" then
				if optname == "classColors" then
					opt.wnd = {}

					Apollo.LoadForm(self.xmlOpt, "OptHeader", catwnd, self):SetText(opt.description)
					for class, color in pairs(self.settings.classColors) do
						local cwnd = Apollo.LoadForm(self.xmlOpt, "ColOpt", catwnd, self)

						for cek, cev in pairs(GameLib.CodeEnumClass) do
							if cev == class then
								-- dont tell a sould what you have seen here
								cwnd:SetText("     " .. cek)
								break
							end
						end

						cwnd:SetData(optname .. "." .. class)
						opt.wnd[class] = cwnd
					end
				end
			end

			if optwnd ~= nil then
				if opt.dependencies ~= nil then
					local indent = #opt.dependencies * 10
					local l,t,r,b = optwnd:GetAnchorOffsets()
					optwnd:SetAnchorOffsets(l + indent, t, r - indent, b)
				end

				optwnd:SetData(optname)
				opt.wnd = optwnd
			end
		end

		catwnd:ArrangeChildrenVert()

		if catid ~= 1 then
			self.optCatWnd[1]:AttachTab(catwnd)
		end

		self.optCatWnd[catid] = catwnd
		catid = catid + 1
	end
end

function GridOptions:ApplySettingsToOptionDialogue()
	if self.wndOpt == nil or not self.wndOpt:IsShown() then return end

	for catname, cat in pairs(optionCategories) do
		for optorderidx, opt in pairs(cat) do
			local optname = opt.setting
			local t = type(defaultSettings[optname])

			local enablechild
			if t == "boolean" then
				enablechild = opt.wnd:FindChild("Checkbox")
				if enablechild:IsChecked() ~= self.settings[optname] then
					enablechild:SetCheck(self.settings[optname])
				end
			elseif t == "number" then
				if opt.enum ~= nil then
					enablechild = opt.wnd:FindChild("EnumValue")

					if opt.enumSelector ~= nil then
						enablechild:DeleteAll()
						local valid = opt.enumSelector(self.settings)
						for ename, evalue in pairs(GridEnum[opt.enum]) do
							if valid[evalue] then
								enablechild:AddItem(ename, "", evalue)
							end
						end
					end

					enablechild:SelectItemByData(self.settings[optname])
				else
					enablechild = opt.wnd:FindChild("NumValue")
					if tonumber(enablechild:GetText()) ~= self.settings[optname] then
						enablechild:SetText(self.settings[optname])
					end

					-- not pretty but need to reset the color to "valid" state here
					enablechild:SetBGColor("black")
				end
			elseif t == "string" then
				if string.match(optname, "color") then
					enablechild = opt.wnd:FindChild("ColValue")
					enablechild:SetBGColor(Util.StringToCColor(self.settings[optname], { a = 1.0 }))
				end
			elseif t == "table" then
				if optname == "classColors" then
					for class, color in pairs(self.settings.classColors) do
						opt.wnd[class]:FindChild("ColValue"):SetBGColor(Util.StringToCColor(color, { a = 1.0 }))
					end
				end
			end

			-- all extremely pretty
			if enablechild ~= nil then
				local enable = true
				if opt.dependencies ~= nil then
					for idep = 1, #opt.dependencies do
						if not self.settings[opt.dependencies[idep]] then
							enable = false
							break
						end
					end
				end

				if enablechild:IsEnabled() ~= enable then
					enablechild:Enable(enable)

					if enable then
						enablechild:SetTextColor("white")
						if t ~= "boolean" then enablechild:GetParent():SetTextColor("white") end
					else
						enablechild:SetTextColor("gray")
						if t ~= "boolean" then enablechild:GetParent():SetTextColor("gray") end
					end
				end
			end
		end
	end
end

function GridOptions:OnSettingsBoolButtonSignal(wndHandler, wndControl)
	local s = wndControl:GetParent():GetData()

	if s ~= nil and self.settings[s] ~= nil then
		self.settings[s] = wndControl:IsChecked()

		self:ApplySettings()
	end
end

function GridOptions:SettingToParams(setting)
	for ck,cv in pairs(optionCategories) do
		for ok, ov in pairs(cv) do
			if ov.setting == setting then return ov end
		end
	end
end

function GridOptions:OnSettingsNumChanged(wndHandler, wndControl, strText)
	local s = wndControl:GetParent():GetData()

	if s ~= nil and self.settings[s] ~= nil then
		local n = tonumber(strText)
		local valid = false
		
		if n ~= nil then
			local opt = self:SettingToParams(s)

			if opt ~= nil then
				valid = (not opt.min or n >= opt.min) and (not opt.max or n <= opt.max)
			end
		end

		if valid then
			wndControl:SetBGColor("black")

			self.settings[s] = n
			self:ApplySettings()
		else
			wndControl:SetBGColor("red")
		end
	end
end

function GridOptions:OnSettingsColorMouseDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	if not wndControl:IsEnabled() then return end

	local settingname = wndControl:GetParent():GetData()

	local dot = string.find(settingname, ".", 1, true)
	local sett, idx
	if dot == nil then
		sett = self.settings[settingname]
	else
		idx = tonumber(string.sub(settingname, dot + 1))
		settingname = string.sub(settingname, 1, dot - 1)
		sett = self.settings[settingname][idx]
	end

	local param = self:SettingToParams(settingname)
	if dot ~= nil then param.tempIdx = idx end

	self.colorPicker:Pick(Util.StringToCColor(sett), self.OnSettingsColorChanged, param, self)
end

function GridOptions:OnSettingsColorChanged(color, param)
	-- prevents an issue when applying settings without having closed the color picker dialogue
	if self.oldSettings == nil then return end

	if param.tempIdx == nil then
		self.settings[param.setting] = Util.CColorToString(color)
	else
		self.settings[param.setting][param.tempIdx] = Util.CColorToString(color)
	end

	self:ApplySettings()
end

function GridOptions:OnSettingsEnumChanged(wndHandler, wndControl)
	local settingname = wndControl:GetParent():GetData()
	local param = self:SettingToParams(settingname)

	local val = wndControl:GetSelectedText()
	local n = GridEnum[param.enum][val]

	if param.onChanging ~= nil then
		param.onChanging(self.settings[settingname], n, Grid)
	end

	self.settings[settingname] = n

	if param.validateOther then
		for k,v in pairs(param.validateOther) do
			local other = self:SettingToParams(v)
			if other.sanitize ~= nil then
				self.settings[v] = other.sanitize(self.settings[v], self.settings)
			end
		end

		self:ApplySettingsToOptionDialogue()
	end

	self:ApplySettings()
end

function GridOptions:OnSettingsWindowClosed()
	if self.oldSettings ~= nil then
		self:OnSettingsCancel()
	end
end

function GridOptions:CloseSettings()
	if self.wndOpt == nil then return end

	self.oldSettings = nil

	self.colorPicker:Cancel()

	self.wndOpt:Show(false)
end

function GridOptions:OnSettingsOK()
	self:CloseSettings()
end

function GridOptions:Cancel()
	if self.oldSettings ~= nil then
		self.settings = Util.CopyTable(self.oldSettings)
		self:ApplySettings()
	end

	self:CloseSettings()
end

function GridOptions:OnSettingsRevert()
	self.settings = Util.CopyTable(defaultSettings)

	self:ApplySettings()
end

function GridOptions:ApplySettings()
	if self.settings ~= Grid.settings then
		Grid.settings = self.settings
	end

	Grid:ApplySettings()
end
