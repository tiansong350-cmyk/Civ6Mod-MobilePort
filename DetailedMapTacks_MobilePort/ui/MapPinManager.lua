-- ===========================================================================
--	Map Pin Manager
--	Manages all the map pins on the world map.
-- ===========================================================================

include( "InstanceManager" );
include( "SupportFunctions" );
include( "Colors" );
include( "MapTacks" );

-- [DMT] Includes
include("PopupDialog");
include("dmt_mappinsubjectmanager");
include("dmt_yieldcalculator"); -- V24: Manually include logic since AddUserInterfaces fails

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local ALPHA_DIM					:number = 0.45;
local COLOR_RED					:number = UI.GetColorValueFromHexLiteral(0xFF0101F5);
local COLOR_YELLOW				:number = UI.GetColorValueFromHexLiteral(0xFF2DFFF8);
local COLOR_GREEN				:number = UI.GetColorValueFromHexLiteral(0xFF4CE710);
local COLOR_WHITE				:number = UI.GetColorValueFromHexLiteral(0xFFFFFFFF);
local FLAGSTATE_NORMAL			:number= 0;
local FLAGSTATE_FORTIFIED		:number= 1;
local FLAGSTATE_EMBARKED		:number= 2;
local FLAGSTYLE_MILITARY		:number= 0;
local FLAGSTYLE_CIVILIAN		:number= 1;
local FLAGTYPE_UNIT				:number= 0;
local TEXTURE_BASE				:string = "MapPinFlag";
local TEXTURE_MASK_BASE			:string = "MapPinFlagMask";

-- [DMT] Constants
local AUTO_DELETE_CONFIG_KEY = "DMT_AUTO_DELETE"; -- nil => NOT_SET, 0 => NO, 1 => YES.

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

-- A link to a container that is rendered after the Unit/City flags.  This is used
-- so that selected units will always appear above the other objects.
local m_SelectedContainer			:table = ContextPtr:LookUpControl( "../SelectedMapPinContainer" );

local m_InstanceManager		:table = InstanceManager:new( "MapPinFlag",	"Anchor", Controls.MapPinFlags );

local m_MapPinInstances				:table  = {};
local m_MapPinStacks				:table  = {};

-- [DMT] Variables
local m_IsShiftDown = false;
local m_RememberChoice = true;
local m_AddMapTackId:number = Input.GetActionId("AddMapTack");
local m_DeleteMapTackId:number = Input.GetActionId("DeleteMapTack");
local m_ToggleMapTackVisibilityId:number = Input.GetActionId("ToggleMapTackVisibility");
local m_MapPinListBtn = nil;
local m_MapPinFlags = nil; -- Will be set to Controls.MapPinFlags or looked up

-- The meta table definition that holds the function pointers
hstructure MapPinFlagMeta
	-- Pointer back to itself.  Required.
	__index							: MapPinFlagMeta

	new								: ifunction;
	destroy							: ifunction;			-- Destroys the map pin flag.  This does not delete the map pin data in the player's configuration.
	Initialize						: ifunction;
	GetMapPin						: ifunction;
	SetInteractivity				: ifunction;
	SetFogState						: ifunction;
	SetHide							: ifunction;
	SetForceHide					: ifunction;
	SetFlagUnitEmblem				: ifunction;
	SetColor						: ifunction;
	SetDim							: ifunction;
	Refresh							: ifunction;			-- Retreives data from the map pin configuration and refeashes the visual state.
	OverrideDimmed					: ifunction;
	UpdateDimmedState				: ifunction;
	UpdateFlagType					: ifunction;
	UpdateCurrentlyVisible			: ifunction;			-- Updates the currently visible flag based on map pin visibility.
	UpdateVisibility				: ifunction;			-- Update the map pin icon based on current visibility flags.
	UpdateSelected					: ifunction;
	UpdateName						: ifunction;
	UpdatePosition					: ifunction;
	SetPosition						: ifunction;
end

-- The structure that holds the banner instance data
hstructure MapPinFlag
	meta							: MapPinFlagMeta;

	m_InstanceManager				: table;				-- The instance manager that made the control set.
    m_Instance						: table;				-- The instanced control set.

    m_Type							: number;				-- Pin type
    m_IsSelected					: boolean;
    m_IsCurrentlyVisible			: boolean;
	m_IsForceHide					: boolean;
    m_IsDimmed						: boolean;
	m_OverrideDimmed				: boolean;
	m_OverrideDim					: boolean;

    m_Player						: table;
    m_pinID							: number;				-- The pin ID.  Keeping just the ID, rather than a reference because there will be times when we need the value, but the pin instance will not exist.
end

-- Create one instance of the meta object as a global variable with the same name as the data structure portion.
-- This allows us to do a MapPinFlag:new, so the naming looks consistent.
MapPinFlag = hmake MapPinFlagMeta {};

-- Link its __index to itself
MapPinFlag.__index = MapPinFlag;



-- ===========================================================================
--	Obtain the unit flag associate with a player and unit.
--	RETURNS: flag object (if found), nil otherwise
-- ===========================================================================
function GetMapPinFlag(playerID:number, pinID:number)
	if m_MapPinInstances[playerID]==nil then
		return nil;
	end
	return m_MapPinInstances[playerID][pinID];
end

------------------------------------------------------------------
-- constructor
------------------------------------------------------------------
function MapPinFlag.new( self : MapPinFlagMeta, playerID: number, pinID : number, flagType : number )
    local o = hmake MapPinFlag { };
    setmetatable( o, self );

	o:Initialize(playerID, pinID, flagType);

	if (m_MapPinInstances[playerID] == nil) then
		m_MapPinInstances[playerID] = {};
	end

	m_MapPinInstances[playerID][pinID] = o;
end

------------------------------------------------------------------
function MapPinFlag.destroy( self : MapPinFlag )
    if ( self.m_InstanceManager ~= nil ) then
        self:UpdateSelected( false );

		if (self.m_Instance ~= nil) then
			self.m_InstanceManager:ReleaseInstance( self.m_Instance );
			m_MapPinInstances[ self.m_Player:GetID() ][ self.m_pinID ] = nil;
		end
    end
end

------------------------------------------------------------------
function MapPinFlag.GetMapPin( self : MapPinFlag )
	local playerCfg :table = PlayerConfigurations[self.m_Player:GetID()];
	local playerMapPins :table = playerCfg:GetMapPins();
	return playerMapPins[self.m_pinID];
end

------------------------------------------------------------------
function MapPinFlag.Initialize( self : MapPinFlag, playerID: number, pinID : number, flagType : number)
	if (flagType == FLAGTYPE_UNIT) then
		self.m_InstanceManager = m_InstanceManager;

		self.m_Instance = self.m_InstanceManager:GetInstance();
		self.m_Type = flagType;

		self.m_IsSelected = false;
		self.m_IsCurrentlyVisible = false;
		self.m_IsForceHide = false;
		self.m_IsDimmed = false;
		self.m_OverrideDimmed = false;

		self.m_Player = Players[playerID];
		self.m_pinID = pinID;

		self:Refresh();
	end
end

------------------------------------------------------------------
function MapPinFlag.Refresh( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
	if(pMapPin ~= nil) then
        -- [DMT] Force visibility
        if self.m_Instance.Anchor then self.m_Instance.Anchor:SetHide(false); end

		self:UpdateCurrentlyVisible();
		self:SetFlagUnitEmblem();
		self:SetColor();
		self:SetInteractivity();
		self:UpdateFlagType();
		self:UpdateName();
		self:UpdatePosition();
		self:UpdateVisibility();
		self:UpdateDimmedState();

        -- [DMT] Update Yields and CanPlace
        local status, err = pcall(UpdateYields, self);
        if not status then print("DMT Error in UpdateYields: ", err); end
        
        -- [DMT V35] Safe UpdateCanPlace
        local status2, err2 = pcall(UpdateCanPlace, self);
        if not status2 then print("DMT Error in UpdateCanPlace: ", err2); end

	else
		self:destroy();
	end
end

-- ===========================================================================
function OnMapPinFlagLeftClick( playerID : number, pinID : number )
	-- If we are the owner of this pin, open up the map pin popup
	if(playerID == Game.GetLocalPlayer()) then
		local flagInstance = GetMapPinFlag( playerID, pinID );
		if (flagInstance ~= nil) then
			local pMapPin = flagInstance:GetMapPin();
			if(pMapPin ~= nil) then
				LuaEvents.MapPinPopup_RequestMapPin(pMapPin:GetHexX(), pMapPin:GetHexY());
			end
		end
	end
end

------------------------------------------------------------------
function OnMapPinFlagRightClick( playerID : number, pinID : number )
    -- [DMT] Shift+Right Click to delete
    if m_IsShiftDown and playerID == Game.GetLocalPlayer() then
        local playerCfg = PlayerConfigurations[playerID];
        -- Update map pin yields.
        LuaEvents.DMT_MapPinRemoved(playerCfg:GetMapPinID(pinID));
        -- Delete the pin.
        playerCfg:DeleteMapPin(pinID);
        Network.BroadcastPlayerInfo();
        UI.PlaySound("Map_Pin_Remove");
    end
end

------------------------------------------------------------------
-- Set the user interativity for the flag.
function MapPinFlag.SetInteractivity( self : MapPinFlag )

    local localPlayerID :number = Game.GetLocalPlayer();
    local flagPlayerID	:number = self.m_Player:GetID();
	local pinID			:number = self.m_pinID;


    self.m_Instance.NormalButton:SetVoid1( flagPlayerID );
    self.m_Instance.NormalButton:SetVoid2( pinID );
    self.m_Instance.NormalButton:RegisterCallback( Mouse.eLClick, OnMapPinFlagLeftClick );
	self.m_Instance.NormalButton:RegisterCallback( Mouse.eRClick, OnMapPinFlagRightClick );
end

------------------------------------------------------------------
-- Set the flag color based on the player colors.
function MapPinFlag.SetColor( self : MapPinFlag )
	local primaryColor, secondaryColor = UI.GetPlayerColors(self.m_Player:GetID());

	local darkerFlagColor   :number = UI.DarkenLightenColor(primaryColor,  -85, 255);
	local brighterFlagColor :number = UI.DarkenLightenColor(primaryColor,   90, 255);
	local brighterIconColor :number = UI.DarkenLightenColor(secondaryColor, 20, 255);

	local iconType = MapTacks.IconType(self:GetMapPin()) or MapTacks.STOCK;
	-- set icon tint appropriate for the icon color
	if iconType <= MapTacks.WHITE then
		-- stock & white map pins
		self.m_Instance.UnitIcon:SetColor( brighterIconColor );
	elseif iconType == MapTacks.GRAY then
		-- shaded icons: match midtones to stock pin color
		local tintedIconColor = MapTacks.IconTint(brighterIconColor);
		self.m_Instance.UnitIcon:SetColor(tintedIconColor);
	else
		-- full color
		self.m_Instance.UnitIcon:SetColor(COLOR_WHITE);
	end
	self.m_Instance.FlagBase:SetColor( primaryColor );
	self.m_Instance.FlagBaseOutline:SetColor( primaryColor );
	self.m_Instance.FlagBaseDarken:SetColor( darkerFlagColor );
	self.m_Instance.FlagBaseLighten:SetColor( primaryColor );

	self.m_Instance.FlagOver:SetColor( brighterFlagColor );
	self.m_Instance.NormalSelect:SetColor( brighterFlagColor );
	self.m_Instance.NormalSelectPulse:SetColor( brighterFlagColor );
end

------------------------------------------------------------------
-- Set the flag texture based on the unit's type
function MapPinFlag.SetFlagUnitEmblem( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
    if pMapPin ~= nil then
		local iconName = pMapPin:GetIconName();
		local iconType = MapTacks.IconType(pMapPin);
		if iconType == MapTacks.HEX then
			-- district icons are embedded into the tack head (HexIcon)
			if not self.m_Instance.HexIcon:SetIcon(iconName) then
				self.m_Instance.HexIcon:SetIcon(MapTacks.UNKNOWN);
			end
			self.m_Instance.HexIcon:SetHide(false);
			self.m_Instance.UnitIcon:SetHide(true);
		else
			-- other icons sit on top of the tack (UnitIcon)
			local size = MapTacks.iconSizes[iconType];
			self.m_Instance.UnitIcon:SetSizeVal(size, size);
			if not self.m_Instance.UnitIcon:SetIcon(iconName) then
				self.m_Instance.UnitIcon:SetIcon(MapTacks.UNKNOWN);
			end
			self.m_Instance.UnitIcon:SetHide(false);
			self.m_Instance.HexIcon:SetHide(true);
		end

	end
end

------------------------------------------------------------------
function MapPinFlag.SetDim( self : MapPinFlag, bDim : boolean )
	if (self.m_IsDimmed ~= bDim) then
		self.m_IsDimmed = bDim;
		self:UpdateDimmedState();
	end
end

-----------------------------------------------------------------
-- Set whether or not the dimmed state for the flag is overridden
function MapPinFlag.OverrideDimmed( self : MapPinFlag, bOverride : boolean )
	self.m_OverrideDimmed = bOverride;
    self:UpdateDimmedState();
end

-----------------------------------------------------------------
-- Set the flag's alpha state, based on the current dimming flags.
function MapPinFlag.UpdateDimmedState( self : MapPinFlag )
	if( self.m_IsDimmed and not self.m_OverrideDimmed ) then
        self.m_Instance.FlagRoot:SetAlpha( ALPHA_DIM );
	else
        self.m_Instance.FlagRoot:SetAlpha( 1.0 );
    end
end

-----------------------------------------------------------------
-- Change the flag's overall visibility
function MapPinFlag.SetHide( self : MapPinFlag, bHide : boolean )
	self.m_IsCurrentlyVisible = not bHide;
	self:UpdateVisibility();
end

------------------------------------------------------------------
-- Change the flag's force hide
function MapPinFlag.SetForceHide( self : MapPinFlag, bHide : boolean )
	self.m_IsForceHide = bHide;
	self:UpdateVisibility();
end

------------------------------------------------------------------
-- Update the flag's type.  This adjust the look of the flag based
-- on the state of the unit.
function MapPinFlag.UpdateFlagType( self : MapPinFlag )
    local textureName:string;
    local maskName:string;

    textureName = TEXTURE_BASE;
    maskName	= TEXTURE_MASK_BASE;

	self.m_Instance.FlagBaseDarken:SetTexture( textureName );
	self.m_Instance.FlagBaseLighten:SetTexture( textureName );
    self.m_Instance.FlagBase:SetTexture( textureName );
    self.m_Instance.FlagBaseOutline:SetTexture( textureName );
	self.m_Instance.NormalSelectPulse:SetTexture( textureName );
    self.m_Instance.NormalSelect:SetTexture( textureName );
	self.m_Instance.FlagOver:SetTexture( textureName );
    self.m_Instance.LightEffect:SetTexture( textureName );

   self.m_Instance.NormalScrollAnim:SetMask( maskName );
end

------------------------------------------------------------------
function MapPinFlag.UpdateCurrentlyVisible( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
	if(pMapPin ~= nil) then
		local localPlayerID = Game.GetLocalPlayer();
		local showMapPin = pMapPin:IsVisible(localPlayerID);
		self:SetHide(not showMapPin);
	end
end

------------------------------------------------------------------
-- Update the visibility of the flag based on the current state.
function MapPinFlag.UpdateVisibility( self : MapPinFlag )

	local bVisible = self.m_IsCurrentlyVisible and not self.m_IsForceHide;
	self.m_Instance.Anchor:SetHide(not bVisible);

end

------------------------------------------------------------------
-- Update the unit name / tooltip
function MapPinFlag.UpdateName( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
	if(pMapPin ~= nil) then
		local nameString = pMapPin:GetName();
		self.m_Instance.NormalButton:SetToolTipString( nameString );
		self.m_Instance.NameLabel:SetText( nameString );
		self.m_Instance.NameContainer:SetHide( nameString == nil );
	end
end

------------------------------------------------------------------
-- The selection state has changed.
function MapPinFlag.UpdateSelected( self : MapPinFlag, isSelected : boolean )
    self.m_IsSelected = isSelected;

	self.m_Instance.NormalSelect:SetHide( not self.m_IsSelected );


	-- If selected, change our parent to the selection container so we are on top in the drawing order
    if( self.m_IsSelected ) then
        self.m_Instance.Anchor:ChangeParent( m_SelectedContainer );
    else
		-- Re-attach back to the manager parent
		self.m_Instance.Anchor:ChangeParent( self.m_InstanceManager.m_ParentControl );
    end

    self:OverrideDimmed( self.m_IsSelected );
end

------------------------------------------------------------------
-- Update the position of the flag to match the current unit position.
function MapPinFlag.UpdatePosition( self : MapPinFlag )
	local pMapPin : table = self:GetMapPin();
	if (pMapPin ~= nil) then
		self:SetPosition( UI.GridToWorld( pMapPin:GetHexX(), pMapPin:GetHexY() ) );
	end
end

------------------------------------------------------------------
-- Set the position of the flag.
function MapPinFlag.SetPosition( self : MapPinFlag, worldX : number, worldY : number, worldZ : number )

	local mapPinStackXOffset = 0;
	if (self ~= nil ) then
		local pMapPin : table = self:GetMapPin();
		if (pMapPin ~= nil) then
			-- If there are multiple map pins sharing a hex, recenter them
			local kStack : table = GetPinStack(pMapPin);
			local found : boolean = false;
			local depth : number = 0;
			for i, pin in ipairs(kStack) do
				if pin == pMapPin then
					found = true;
					break;
				else
					depth = depth + 1;
				end
			end
			if not found then
				StackMapPin(pMapPin);
			end
			mapPinStackXOffset = 5.0 * depth;
		end
	end

	local yOffset = 0;	--offset for 2D strategic view
	local zOffset = 0;	--offset for 3D world view
	local xOffset = mapPinStackXOffset;
	self.m_Instance.Anchor:SetWorldPositionVal( worldX+xOffset, worldY+yOffset, worldZ+zOffset );
end


-- ===========================================================================
--	Creates a unit flag (if one doesn't exist).
-- ===========================================================================
function CreateMapPinFlag(mapPinCfg : table)
	if(mapPinCfg ~= nil) then
		local playerID: number = mapPinCfg:GetPlayerID();
		local pinID : number = mapPinCfg:GetID();

		-- If a flag already exists for this player/unit combo... just return.
		local flagInstance = GetMapPinFlag( playerID, pinID );
		if(flagInstance ~= nil) then
			-- Flag already exists, we're probably just reusing the pinID, refresh the pin.
			flagInstance:UpdateName();
			flagInstance:UpdatePosition();
			return;
		end

		-- Allocate a new flag.
		MapPinFlag:new( playerID, pinID, FLAGTYPE_UNIT );
	end
end

-- ===========================================================================
--	Engine Event
-- ===========================================================================
------------------------------------------------------------------
function OnPlayerConnectChanged(iPlayerID)
	-- When a human player connects/disconnects, their unit flag tooltips need to be updated.
	local pPlayer = Players[ iPlayerID ];
	if (pPlayer ~= nil) then
		if (m_MapPinInstances[ iPlayerID ] == nil) then
			return;
		end

		local playerFlagInstances = m_MapPinInstances[ iPlayerID ];
		for id, flag in pairs(playerFlagInstances) do
			if (flag ~= nil) then
				flag:UpdateName();
			end
		end
    end
end

------------------------------------------------------------------
function SetForceHideForID( id : table, bState : boolean)
	if (id ~= nil) then
		if (id.componentType == ComponentType.UNIT) then
		    local flagInstance = GetMapPinFlag( id.playerID, id.componentID );
			if (flagInstance ~= nil) then
				flagInstance:SetForceHide(bState);
				flagInstance:UpdatePosition();
			end
		end
    end
end
-------------------------------------------------
-- Combat vis is beginning
-------------------------------------------------
function OnCombatVisBegin( kVisData )

	SetForceHideForID( kVisData[CombatVisType.ATTACKER], true );
	SetForceHideForID( kVisData[CombatVisType.DEFENDER], true );
	SetForceHideForID( kVisData[CombatVisType.INTERCEPTOR], true );
	SetForceHideForID( kVisData[CombatVisType.ANTI_AIR], true );

end

-------------------------------------------------
-- Combat vis is ending
-------------------------------------------------
function OnCombatVisEnd( kVisData )

	SetForceHideForID( kVisData[CombatVisType.ATTACKER], false );
	SetForceHideForID( kVisData[CombatVisType.DEFENDER], false );
	SetForceHideForID( kVisData[CombatVisType.INTERCEPTOR], false );
	SetForceHideForID( kVisData[CombatVisType.ANTI_AIR], false );

end

-- ===========================================================================
--	Refresh the contents of the flags.
--	This does not include the flags' positions in world space; those are
--	updated on another event.
-- ===========================================================================
function Refresh()
	local players :table = Game.GetPlayers{Alive = true, Human = true};
	local iW, iH = Map.GetGridSize();

	-- Reset all flags.
	m_InstanceManager:ResetInstances();
	m_MapPinInstances = {};

	-- Build stacks of pins, with the active player on top of the stacks.
	m_MapPinStacks = {};  -- indexed by [y][x] coordinates
	for y = 0, iH-1 do  -- create empty rows
		m_MapPinStacks[y] = {};
	end
	for i, player in ipairs(players) do
		local playerID		:number = player:GetID();
		local playerCfg		:table  = PlayerConfigurations[playerID];
		local playerPins	:table  = playerCfg:GetMapPins();
		for ii, mapPinCfg in pairs(playerPins) do
			StackMapPin(mapPinCfg);
		end
	end

	-- Sort pin stacks and calculate maximum depth
	local maxdepth = 0;
	for i, row in pairs(m_MapPinStacks) do
		for j, stack in pairs(row) do
			maxdepth = math.max(maxdepth, #stack);
			SortPinStack(stack);
		end
	end

	-- Refresh pins north to south, bottom to top, for best z-order
	-- Note: invisible pins can still cause odd overlapping
	for y = iH-1, 0, -1 do
		local row = m_MapPinStacks[y];
		if next(row) ~= nil then  -- skip empty rows
			for depth = 1, maxdepth do
				for x, stack in pairs(row) do
					if depth <= #stack then
						CreateMapPinFlag(stack[depth]);
					end
				end
			end
		end
	end
end

function SortPinStack(stack :table)
	-- put active player on top of visible pins, invisible pins after that
	local activePlayerID = Game.GetLocalPlayer();
	local activeStack = {};
	local invisibleStack = {};
	local i = 1;
	-- sort out active-player and invisible pins
	while i <= #stack do
		local pin = stack[i];
		if pin:GetPlayerID() == activePlayerID then
			activeStack[#activeStack + 1] = pin;
			table.remove(stack, i);
		elseif pin:IsVisible(activePlayerID) then
			i = i + 1;
		else
			invisibleStack[#invisibleStack + 1] = pin;
			table.remove(stack, i);
		end
	end
	-- stack pins for the active player on top
	for i, pin in ipairs(activeStack) do
		stack[#stack + 1] = pin
	end
	-- stack invisible pins at the end
	for i, pin in ipairs(invisibleStack) do
		stack[#stack + 1] = pin
	end
end

function StackMapPin(pMapPin :table)
	-- Constrain pin coordinates to map coordinates, in case of generated pins
	-- outside the normal bounds. This works well for wraparound maps, where
	-- pins stack up modulo the world size. It works less well for bounded
	-- maps, but standard map pins will not go outside the bounds anyway.
	local iW, iH = Map.GetGridSize();
	local y = pMapPin:GetHexY() % iH;
	local x = pMapPin:GetHexX() % iW;
	local stack = m_MapPinStacks[y][x];
	if stack then
		stack[#stack + 1] = pMapPin;
	else
		m_MapPinStacks[y][x] = { pMapPin };
	end
end

function GetPinStack(pMapPin :table)
	-- constrain pin coordinates to map coordinates
	local iW, iH = Map.GetGridSize();
	row = m_MapPinStacks[pMapPin:GetHexY() % iH] or {}
	return row[pMapPin:GetHexX() % iW] or {}
end

------------------------------------------------------------------
function OnPlayerInfoChanged(playerID)
    -- [DMT V29] Force update when player info changes (pins added/removed)
    if playerID == Game.GetLocalPlayer() then
        local status, err = pcall(ForceUpdateAllPins, playerID);
        if not status then print("DMT V29 Error: " .. tostring(err)); end
    end
	Refresh();
end

------------------------------------------------------------------
function OnLoadGameViewStateDone()
    print("DMT V29: OnLoadGameViewStateDone Triggered");
    if Controls.DebugLabel then Controls.DebugLabel:SetText("DMT V29: Game Loaded"); end
    
    -- [DMT V29] Force initial calculation safely with pcall
    local status, err = pcall(ForceUpdateAllPins, Game.GetLocalPlayer());
    if not status then
        print("DMT V29 Error in ForceUpdateAllPins: " .. tostring(err));
        if Controls.DebugLabel then Controls.DebugLabel:SetText("Error: " .. tostring(err)); end
    end

	Refresh();
end

-------------------------------------------------
-- Position the flags appropriately in 2D and 3D view
-------------------------------------------------
function PositionFlagsToView()
	local players = Game.GetPlayers{Alive = true, Human = true};
	for i, player in ipairs(players) do
		local playerID = player:GetID();
		local playerCfg = PlayerConfigurations[playerID];
		local playerPins = playerCfg:GetMapPins();
		for ii, pin in pairs(playerPins) do
			local pinID = pin:GetID();
			local flagInstance = GetMapPinFlag( playerID, pinID );
			if (flagInstance ~= nil) then
				local pMapPin : table = flagInstance:GetMapPin();
				flagInstance:SetPosition( UI.GridToWorld( pMapPin:GetHexX(), pMapPin:GetHexY() ) );

			end
		end
	end
end

-- ===========================================================================
function OnContextInitialize(isHotload : boolean)
	-- If hotloading, rebuild from scratch.
	if isHotload then
		Refresh();
	end
end

----------------------------------------------------------------
function OnLocalPlayerChanged()
	Refresh();
end

-- ===========================================================================
function OnBeginWonderReveal()
	ContextPtr:SetHide( true );
end

-- ===========================================================================
function OnEndWonderReveal()
	ContextPtr:SetHide( false );
end

----------------------------------------------------------------
-- Handle the UI shutting down.
function OnShutdown()
	m_InstanceManager:ResetInstances();
end


-- ===========================================================================
-- [DMT] New Functions
-- ===========================================================================

-- [DMT V38] Force update all pins from PlayerConfig to bypass broken event system
function ForceUpdateAllPins(playerID)
    if playerID ~= Game.GetLocalPlayer() then return end
    
    if Controls.DebugLabel then Controls.DebugLabel:SetText("V38: Step 1 (Start)"); end
    
    local playerConfig = PlayerConfigurations[playerID];
    local playerPins = playerConfig:GetMapPins();
    local pinsToUpdate = {};

    if Controls.DebugLabel then Controls.DebugLabel:SetText("V36: Step 2 (GotPins)"); end

    for i, mapPin in pairs(playerPins) do
        -- [DMT V36] Trace Loop
        if Controls.DebugLabel then Controls.DebugLabel:SetText("V36: Step 3 (Loop " .. tostring(i) .. ")"); end
        
        local status, pinSubject = pcall(CreateMapPinSubject, mapPin);
        if status and pinSubject then
            table.insert(pinsToUpdate, pinSubject);
        else
            print("DMT Error in CreateMapPinSubject: " .. tostring(pinSubject));
            if Controls.DebugLabel then Controls.DebugLabel:SetText("V36: Err CreateSubj"); end
        end
    end
    
    if Controls.DebugLabel then Controls.DebugLabel:SetText("V36: Step 4 (Call Update)"); end

    -- [DMT] Update Yields
    local status, err = pcall(UpdatePinYields, playerID, pinsToUpdate);
    if not status then
        print("DMT Error in UpdatePinYields: " .. tostring(err));
        if Controls.DebugLabel then Controls.DebugLabel:SetText("Err: " .. tostring(err)); end
    else
        if Controls.DebugLabel then Controls.DebugLabel:SetText("V38: Step 5 (Done)"); end
    end
end

function UpdateYields(pMapPinFlag)
    local pMapPin = pMapPinFlag:GetMapPin();

    if pMapPin ~= nil then
        local mapPinSubject = GetMapPinSubject(pMapPin:GetPlayerID(), pMapPin:GetHexX(), pMapPin:GetHexY());
        
        -- [DMT V31] Debug Print
        if mapPinSubject == nil then
            if Controls.DebugLabel then Controls.DebugLabel:SetText("NoSubj: " .. pMapPin:GetHexX() .. "," .. pMapPin:GetHexY()); end
        else
            -- print("DMT V25: Pin at " .. pMapPin:GetHexX() .. "," .. pMapPin:GetHexY() .. " Yield: " .. tostring(mapPinSubject.YieldString));
            if Controls.DebugLabel then 
                Controls.DebugLabel:SetText("Yield: " .. tostring(mapPinSubject.YieldString)); 
            end
        end

        if mapPinSubject then
            local yieldString = mapPinSubject.YieldString;
            local yieldToolTip = mapPinSubject.YieldToolTip;
            if yieldString ~= nil and yieldString ~= "" then
                pMapPinFlag.m_Instance.YieldText:SetText(yieldString);
                if yieldToolTip ~= nil and yieldToolTip ~= "" then
                    -- [DMT V39] Tooltip enabled for iPad long-press
                    pMapPinFlag.m_Instance.YieldText:SetToolTipString(yieldToolTip);
                else
                    pMapPinFlag.m_Instance.YieldText:SetToolTipString("");
                end
                pMapPinFlag.m_Instance.YieldContainer:SetHide(false);
                return;
            end
        end
    end

    pMapPinFlag.m_Instance.YieldText:SetText("");
    pMapPinFlag.m_Instance.YieldContainer:SetHide(true);
end

function UpdateCanPlace(pMapPinFlag)
    local pMapPin = pMapPinFlag:GetMapPin();

    if pMapPin ~= nil then
        local mapPinSubject = GetMapPinSubject(pMapPin:GetPlayerID(), pMapPin:GetHexX(), pMapPin:GetHexY());
        if mapPinSubject then
            local canPlace = mapPinSubject.CanPlace;
            local canPlaceToolTip = mapPinSubject.CanPlaceToolTip;
            pMapPinFlag.m_Instance.CanPlaceIcon:SetHide(canPlace);
            -- [DMT V39] Tooltip enabled for iPad long-press
            pMapPinFlag.m_Instance.CanPlaceIcon:SetToolTipString(canPlaceToolTip);
            return;
        end
    end

    pMapPinFlag.m_Instance.CanPlaceIcon:SetHide(true);
    -- [DMT V39] Tooltip enabled
    pMapPinFlag.m_Instance.CanPlaceIcon:SetToolTipString("");
end

function ToggleMapPinVisibility()
    if m_MapPinListBtn == nil then
        m_MapPinListBtn = ContextPtr:LookUpControl("/InGame/MinimapPanel/MapPinListButton");
    end
    if not m_MapPinListBtn:IsSelected() then
        if m_MapPinFlags == nil then
            m_MapPinFlags = ContextPtr:LookUpControl("/InGame/MapPinManager/MapPinFlags");
        end
        -- Only toggle the map pin visibility if MapPinListButton is not selected. i.e. not trying to add new pins.
        m_MapPinFlags:SetHide(not m_MapPinFlags:IsHidden());
    end
end

function ShowMapPins()
    if m_MapPinFlags == nil then
        m_MapPinFlags = ContextPtr:LookUpControl("/InGame/MapPinManager/MapPinFlags");
    end
    m_MapPinFlags:SetHide(false);
end

function AddMapPin()
    -- Make sure the map pins are shown before adding.
    ShowMapPins();
    local plotX, plotY = UI.GetCursorPlotCoord();
    LuaEvents.MapPinPopup_RequestMapPin(plotX, plotY);
end

function DeleteMapPin()
    if m_MapPinFlags == nil then
        m_MapPinFlags = ContextPtr:LookUpControl("/InGame/MapPinManager/MapPinFlags");
    end
    if not m_MapPinFlags:IsHidden() then
        -- Only delete if the map pins are not hidden.
        local plotX, plotY = UI.GetCursorPlotCoord();
        DeleteMapPinAtPlot(Game.GetLocalPlayer(), plotX, plotY);
    end
end

function DeleteMapPinAtPlot(playerID, plotX, plotY)
    local playerCfg = PlayerConfigurations[playerID];
    local mapPin = playerCfg and playerCfg:GetMapPin(plotX, plotY);
    if mapPin then
        -- Update map pin yields.
        LuaEvents.DMT_MapPinRemoved(mapPin);
        -- Delete the pin.
        playerCfg:DeleteMapPin(mapPin:GetID());
        Network.BroadcastPlayerInfo();
        UI.PlaySound("Map_Pin_Remove");
    end
end

function OnDeleteMapPinRequest(playerID, plotX, plotY)
    local playerCfg = PlayerConfigurations[playerID];
    local autoDeleteConfig = playerCfg and playerCfg:GetValue(AUTO_DELETE_CONFIG_KEY);
    if autoDeleteConfig == 0 then
        -- Don't auto delete.
    elseif autoDeleteConfig == 1 then
        -- Auto delete.
        DeleteMapPinAtPlot(playerID, plotX, plotY);
    else
        -- Not set, show popup.
        local popupDialog = PopupDialog:new("DMT_AutoDelete_PopupDialog");
        popupDialog:AddTitle("");
        popupDialog:AddText(Locale.Lookup("LOC_DMT_AUTO_DELETE_MAP_TACK_HINT"));
        popupDialog:AddCheckBox(Locale.Lookup("LOC_REMEMBER_MY_CHOICE"), m_RememberChoice, OnAutoDeleteRememberChoice);
        popupDialog:AddButton(Locale.Lookup("LOC_YES"), function() OnAutoDeleteChooseYes(playerID, plotX, plotY); end);
        popupDialog:AddButton(Locale.Lookup("LOC_NO"), function() OnAutoDeleteChooseNo(playerID, plotX, plotY); end);
        popupDialog:Open();
    end
end

function OnAutoDeleteRememberChoice(checked)
    m_RememberChoice = checked;
end

function OnAutoDeleteChooseYes(playerID, plotX, plotY)
    local playerCfg = PlayerConfigurations[playerID];
    if m_RememberChoice and playerCfg then
        playerCfg:SetValue(AUTO_DELETE_CONFIG_KEY, 1);
        Network.BroadcastPlayerInfo();
    end
    DeleteMapPinAtPlot(playerID, plotX, plotY);
end

function OnAutoDeleteChooseNo(playerID, plotX, plotY)
    local playerCfg = PlayerConfigurations[playerID];
    if m_RememberChoice and playerCfg then
        playerCfg:SetValue(AUTO_DELETE_CONFIG_KEY, 0);
        Network.BroadcastPlayerInfo();
    end
end

function OnInputHandler(pInputStruct:table)
    -- **Inspired by CQUI. Credits to infixo.**
    if pInputStruct:GetKey() == Keys.VK_SHIFT then
        m_IsShiftDown = pInputStruct:GetMessageType() == KeyEvents.KeyDown;
    end
    return false;
end

function OnInterfaceModeChanged(eNewMode:number)
    if UI.GetInterfaceMode() == InterfaceModeTypes.PLACE_MAP_PIN then
        ShowMapPins();
    end
end

function OnInputActionTriggered(actionId:number)
    if actionId == m_AddMapTackId then
        AddMapPin();
    elseif actionId == m_DeleteMapTackId then
        DeleteMapPin();
    elseif actionId == m_ToggleMapTackVisibilityId then
        ToggleMapPinVisibility();
    end
end

-- ===========================================================================
-- ===========================================================================
function Initialize()
    print("DMT V38: Initialize Start");
    
    -- [DMT V38] Environment Check
    local luaVer = _VERSION or "Unknown";
    local hasLS = (loadstring ~= nil) and "Yes" or "No";
    local envMsg = "V38: " .. luaVer .. " LS:" .. hasLS .. " CleanFile:Yes";
    print(envMsg);
    if Controls.DebugLabel then Controls.DebugLabel:SetText(envMsg); end

    -- Wrap initialization in pcall
    local status, err = pcall(function()
        ContextPtr:SetInitHandler( OnContextInitialize );
        ContextPtr:SetShutdown( OnShutdown );

        Events.BeginWonderReveal.Add( OnBeginWonderReveal );
        Events.CombatVisBegin.Add( OnCombatVisBegin );
        Events.CombatVisEnd.Add( OnCombatVisEnd );
        Events.EndWonderReveal.Add( OnEndWonderReveal );
        Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
        Events.MultiplayerPlayerConnected.Add( OnPlayerConnectChanged );
        Events.MultiplayerPostPlayerDisconnected.Add( OnPlayerConnectChanged );
        Events.WorldRenderViewChanged.Add(PositionFlagsToView);
        Events.PlayerInfoChanged.Add(OnPlayerInfoChanged);
        Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );

        -- [DMT] Event Registrations
        ContextPtr:SetInputHandler(OnInputHandler, true);
        LuaEvents.DMT_DeleteMapPinRequest.Add(OnDeleteMapPinRequest);
        Events.InterfaceModeChanged.Add(OnInterfaceModeChanged);
        Events.InputActionTriggered.Add(OnInputActionTriggered);
        
        -- [DMT V26] Removed forced call to prevent freeze
        -- if OnLocalPlayerTurnBegin then
        --     print("DMT V25: Forcing OnLocalPlayerTurnBegin(true)");
        --     OnLocalPlayerTurnBegin(true);
        -- else
        --     print("DMT V25: OnLocalPlayerTurnBegin NOT FOUND!");
        -- end
    end);

    if status then
        print("DMT V38: Initialize Success");
    else
        print("DMT V38: Initialize Failed: " .. tostring(err));
        if Controls.DebugLabel then Controls.DebugLabel:SetText("ERROR: " .. tostring(err)); end
    end
end
Initialize();
