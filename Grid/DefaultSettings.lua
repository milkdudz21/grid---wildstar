local Grid = Apollo.GetAddon("Grid")
local GridEnum = Grid.GridEnum

Grid.defaultSettings =
{
	top = 500,
	left = 500,
	
	padding = 10,
	
	playersPerRow = 5, -- playersPerPrimaryGrowthDirection
	primaryGrowth = GridEnum.BarGrowth.LeftToRight,
	secondaryGrowth = GridEnum.BarGrowth.TopDown,
	
	cellHeight = 40,
	cellWidth = 60,
	cellHorizontalSpacing = 2,
	cellVerticalSpacing = 2,
	cellBorderWidth = 2,

	classColors =
	{
		[GameLib.CodeEnumClass.Warrior] 			= "FFAB855E",
		[GameLib.CodeEnumClass.Engineer] 			= "FFA41A31", -- DB6B09 - orange
		[GameLib.CodeEnumClass.Esper]				= "FF74ddff", -- 5DAECD
		[GameLib.CodeEnumClass.Medic]				= "FFFFFFFF",
		[GameLib.CodeEnumClass.Stalker] 			= "FFDDD45F",
		[GameLib.CodeEnumClass.Spellslinger]	 	= "FF826FAC" 
	},
	colorDead = "FF706D6D",
	colorText = "xkcdLightGold",
	colorTextDead = "FF908D8D",
	colorFrame = "FF000000",
	colorFrameSelected = "FFAAAAAA",
	colorAggro = "77FF0000",
	colorOOM = "blue",
	colorCC = "xkcdBarneyPurple",
	colorShield = "ff68ffba",
	colorMissingHealth = "white",

	hideWithoutGroup = false,

	enableAggroIndicator = true,
	aggroIndicatorSprite = "GridSprites:FrameIndicatorBleed",

	enableDispellIndicator = true,
	dispellIndicatorScale = 0.5,

	oomThreshold = 0.25,

	unitMaxDistance = 25.0,

	-- all these stack multiplicatively
	baseOpacity = 1.0,
	rangedOpacity = 0.3,
	nonCombatOpacity = 0.7,

	invertHealthBarCols = true,
	healthBarGrowth = GridEnum.BarGrowth.LeftToRight,
	
	displayShields = true,
	shieldHeight = 2,
	shieldAnchor = GridEnum.LayoutAnchor.BottomCenter,

	mouseOverSelection = true,
	rememberPrevTarget = true,
	clickToSelect = true,
	rightClickMenu = true,

	enableArrowIndicator = true,
	arrowIndicatorTargetOnly = false,
	arrowIndicatorGroupMember = true,
	arrowIndicatorWidth = 3.0,
	arrowIndicatorScale = 0.7,
	colorArrowIndicator = "white",
	arrowIndicatorDistanceThreshold = 0.01,

	displayName = true,
	nameAnchor = GridEnum.LayoutAnchor.BottomLeft,

	displayHealthText = true,
	displayMissingHealth = true,
	healthPercent = false,
	healthTextAnchor = GridEnum.LayoutAnchor.MiddleRight,

	enableIAIndicator = true,
	enableCCIndicator = true,
	enableOOMIndicator = true,

	locked = false,
}
