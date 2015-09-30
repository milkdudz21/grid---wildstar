local Grid = Apollo.GetAddon("Grid")
local GridEnum = Grid.GridEnum
local Util = Grid.Util

Grid.optionCategories = {
	["General"] = {
		{
			setting = "cellWidth",
			description = "Cell width",
			min = 10,
		},
		{
			setting = "cellHeight",
			description = "Cell height",
			min = 10,
		},
		{
			setting = "cellHorizontalSpacing",
			description = "Horizontal spacing",
			min = 0,
		},
		{
			setting = "cellVerticalSpacing",
			description = "Vertical spacing",
			min = 0,
		},
		{
			setting = "cellBorderWidth",
			description = "Border width",
			min = 0,
		},
		{
			setting = "hideWithoutGroup",
			description = "Hide when not in a group",
		},
		{
			setting = "rightClickMenu",
			description = "Show context menu on right click",
		},
		{
			setting = "playersPerRow",
			description = "Players per primary growth direction",
			min = 1,
		},
		{
			setting = "primaryGrowth",
			description = "Primary growth direction",
			enum = "BarGrowth",
			validateOther = { "secondaryGrowth" },
		},
		{
			setting = "secondaryGrowth",
			description = "Secondary growth direction",
			enum = "BarGrowth",
			enumSelector =
				function(settings)
					if Util.IsHorizontal(settings.primaryGrowth) then
						return { [GridEnum.BarGrowth.TopDown] = true, [GridEnum.BarGrowth.BottomUp] = true }
					else
						return { [GridEnum.BarGrowth.LeftToRight] = true, [GridEnum.BarGrowth.RightToLeft] = true }
					end
				end,
			sanitize =
				function(value, settings)
					if Util.IsHorizontal(settings.primaryGrowth) and Util.IsHorizontal(value) then
						return GridEnum.BarGrowth.TopDown
					elseif Util.IsVertical(settings.primaryGrowth) and Util.IsVertical(value) then
						return GridEnum.BarGrowth.LeftToRight
					end

					return value
				end,
		},
	},

	["Bars"] = {
		{
			setting = "displayShields",
			description = "Display shields",
		},
		{
			setting = "shieldHeight",
			description = "Shield bar height",
			min = 1,
		},
		{
			setting = "colorShield",
			description = "Shield color",
			dependencies = { "displayShields" },
		},
		{
			setting = "shieldAnchor",
			description = "Shield bar anchor",
			enum = "LayoutAnchor",
			enumSelector =
				function(settings)
					local vals = {}
					for i = GridEnum.LayoutAnchor.TopLeft, GridEnum.LayoutAnchor.BottomRight do
						if i % 3 ~= 1 then
							vals[i] = true
						end
					end

					return vals
				end,
		},
		{
			setting = "invertHealthBarCols",
			description = "Invert health bar colors",
		},
		{
			setting = "healthBarGrowth",
			description = "Health bar growth",
			enum = "BarGrowth",
		},
		{
			setting = "displayName",
			description = "Display names",
		},
		{
			setting = "colorText",
			description = "Name color",
			dependencies = { "displayName" },
		},
		{
			setting = "nameAnchor",
			description = "Name anchor",
			enum = "LayoutAnchor",
		},
	},
	["Health Text"] = {
		{
			setting = "displayHealthText",
			description = "Display health text",
		},
		{
			setting = "healthPercent",
			description = "Display percentage",
			dependencies = { "displayHealthText" },
		},
		{
			setting = "displayMissingHealth",
			description = "Display missing health",
			dependencies = { "displayHealthText" },
		},
		{
			setting = "colorMissingHealth",
			description = "Health text color",
			dependencies = { "displayHealthText" },
		},
		{
			setting = "healthTextAnchor",
			description = "Text anchor",
			enum = "LayoutAnchor",
		},
	},
	["Targeting"] = {
		{
			setting = "mouseOverSelection",
			description = "Automatically target on mouse-over",
		},
		{
			setting = "rememberPrevTarget",
			description = "Remeber previous target when leaving grid",
			dependencies = { "mouseOverSelection" },
		},
		{
			setting = "clickToSelect",
			description = "Click to select",
		},
	},

	["Arrow"] = {
		{
			setting = "enableArrowIndicator",
			description = "Show arrow",
		},
		{
			setting = "arrowIndicatorTargetOnly",
			description = "Target only",
			dependencies = { "enableArrowIndicator" },
		},
		{
			setting = "arrowIndicatorGroupMember",
			description = "Show at long distance",
			dependencies = { "enableArrowIndicator" },
			-- TODO: disable if !arrowIndicatorTargetOnly
		},
		{
			setting = "arrowIndicatorScale",
			description = "Arrow scale",
			dependencies = { "enableArrowIndicator" },
			min = 0.01,
			max = 1,
		},
		{
			setting = "arrowIndicatorWidth",
			description = "Arrow thickness",
			dependencies = { "enableArrowIndicator" },
			min = 0,
		},
		{
			setting = "colorArrowIndicator",
			description = "Arrow color",
			dependencies = { "enableArrowIndicator" },
		},
		{
			setting = "arrowIndicatorDistanceThreshold",
			description = "Minimum distance to unit",
			dependencies = { "enableArrowIndicator" },
			min = 0.0001,
		},
	},

	["Opacities"] = {
		{
			setting = "baseOpacity",
			description = "Base opacity",
			min = 0,
			max = 1,
		},
		{
			setting = "rangedOpacity",
			description = "Out-of-range opacity",
			min = 0,
			max = 1,
		},
		{
			setting = "unitMaxDistance",
			description = "Range cutoff",
			min = 0,
		},
		{
			setting = "nonCombatOpacity",
			description = "Out-of-combat opacity",
			min = 0,
			max = 1,
		},
	},

	["Indicators"] = {
		{
			setting = "enableAggroIndicator",
			description = "Show aggro indicator",
		},
		{
			setting = "colorAggro",
			description = "Aggro indicator color",
			dependencies = { "enableAggroIndicator" },
		},
		{
			setting = "enableDispellIndicator",
			description = "Show debuff indicator",
		},
		{
			setting = "dispellIndicatorScale",
			description = "Debuff indicator scale",
			dependencies = { "enableDispellIndicator" },
			min = 0,
			max = 1,
		},
		{
			setting = "enableCCIndicator",
			description = "Show crowd control effect",
		},
		{
			setting = "colorCC",
			description = "Crowd control indicator color",
			dependencies = { "enableCCIndicator" },
		},
		{
			setting = "enableIAIndicator",
			description = "Show interrupt armor count",
		},
		{
			setting = "enableOOMIndicator",
			description = "Show when focus below threshold",
		},
		{
			setting = "colorOOM",
			description = "Out of focus indicator color",
			dependencies = { "enableOOMIndicator" },
		},
		{
			setting = "oomThreshold",
			description = "Out-of-focus threshold",
			dependencies = { "enableOOMIndicator" },
		},
	},

	["Colors"] = {
		{
			setting = "classColors",
			description = "Class colors",
		},
		{
			setting = "colorDead",
			description = "Dead player color",
		},
		{
			setting = "colorFrame",
			description = "Frame color",
		},
		{
			setting = "colorFrameSelected",
			description = "Selected frame color",
		},
	},
}
