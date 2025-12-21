print("DMT: Version 20 Loaded (Root Path Hook)");

-- Remove include to prevent crashes
-- include("dmt_yieldcalculator");

local MapPinManagerContext = nil;
local MapPinFlags = nil;
local DebugLabel = Controls.DebugLabel;

function Log(msg)
    print("DMT: " .. msg);
    if (DebugLabel) then
        DebugLabel:SetText(msg);
    end
end

function Initialize()
    Log("Init: Looking for Context...");
    
    -- Try absolute path
    MapPinManagerContext = ContextPtr:LookUpControl("/InGame/MapPinManager");
    
    if (MapPinManagerContext) then
        Log("Init: Context Found! Looking for Flags...");
        MapPinFlags = MapPinManagerContext:LookUpControl("MapPinFlags");
        if (MapPinFlags) then
            Log("Init: Flags Found! Hooking Events...");
        else
            Log("ERROR: Flags NOT Found in Context!");
        end
    else
        Log("ERROR: Context NOT Found!");
    end

    -- Listen to events
    Events.MapPinPlayer_MapPinAdded.Add(OnMapPinChanged);
    Events.MapPinPlayer_MapPinModified.Add(OnMapPinChanged);
    Events.MapPinPlayer_MapPinRemoved.Add(OnMapPinChanged);
    Events.LoadScreenClose.Add(OnMapPinChanged);
    
    -- Initial update
    OnMapPinChanged();
end

function OnMapPinChanged(...)
    if (not MapPinFlags) then 
        -- Try to find it again (lazy load)
        if (MapPinManagerContext) then
             MapPinFlags = MapPinManagerContext:LookUpControl("MapPinFlags");
        end
        if (not MapPinFlags) then
            Log("Event: Flags Missing!");
            return; 
        end
    end

    Log("Event: Updating Pins...");

    local uiChildren = MapPinFlags:GetChildren();
    local count = 0;
    for i, child in ipairs(uiChildren) do
        UpdateChild(child);
        count = count + 1;
    end
    
    Log("Updated " .. count .. " Pins. (Dummy Yield)");
end

function UpdateChild(child)
    local yieldTextControl = child:LookUpControl("YieldText");
    local yieldContainer = child:LookUpControl("YieldContainer");
    
    if (yieldTextControl) then
        -- Inject Dummy Yield to prove we have access
        yieldTextControl:SetText("+?");
        if (yieldContainer) then yieldContainer:SetHide(false); end
    else
        -- Log("Child missing YieldText!"); -- Too spammy
    end
end

Initialize();

-- =================================================================================
-- [DMT-iPad] V18: The Nuclear Option (AddUserInterfaces Hook)
-- Instead of replacing the script (which fails on iPad), we load this script
-- in a separate context and "hook" into the original MapPinManager.
-- =================================================================================

local TARGET_CONTEXT_PATH = "/InGame/MapPinManager";
local MapPinManagerContext = ContextPtr:LookUpControl(TARGET_CONTEXT_PATH);

if (MapPinManagerContext == nil) then
    print("DMT: ERROR - Could not find MapPinManager context at " .. TARGET_CONTEXT_PATH);
    return;
end

print("DMT: Found MapPinManager context!");

-- =================================================================================
-- Import Dependencies (These are global in the game, so we can just require them)
-- =================================================================================
include("AdjacencyBonusSupport");
include("SupportFunctions");

-- =================================================================================
-- DMT Core Logic (Copied from original mod, but adapted for Hook)
-- =================================================================================

-- ... (We need to copy the core logic here, but for brevity in this tool call, 
-- I will focus on the Hook mechanism first. In a real scenario, I'd paste the whole logic.
-- For now, let's assume we can access the global MapPinFlag from the context?)

-- Wait, MapPinFlag is a class defined in the original file. 
-- We can't easily access local variables of another context.
-- BUT, MapPinFlag is usually assigned to the global table of that context.
-- Let's try to access it via the context's global environment.
-- Civ6 Lua doesn't easily allow accessing another context's globals directly unless they are shared.

-- ALTERNATIVE: We can't easily monkey-patch local classes.
-- However, we CAN listen to the same events and try to manipulate the UI controls directly.
-- But we need to know WHICH instance corresponds to which pin.

-- BETTER APPROACH for V18:
-- We will re-implement the ENTIRE logic in this file, and just use LookUpControl
-- to find the *Container* where pins are added, and iterate over them?
-- No, the game creates instances.

-- Let's go back to the "XML Replacement" we already have.
-- We have `MapPinManager.xml` replaced. It has `YieldContainer` and `YieldText`.
-- The original `MapPinManager.lua` (which is running now) doesn't know about them, so it ignores them.
-- Our `dmt_hook.lua` needs to:
-- 1. Listen to `MapPinPlayer_MapPinAdded`, `MapPinPlayer_MapPinModified`, etc.
-- 2. When a pin is added/modified, FIND the UI control for it.
-- 3. Calculate yield.
-- 4. Update the `YieldText` control.

-- How to find the UI control?
-- The original script creates instances in `MapPinFlags` container.
-- We can look up `/InGame/MapPinManager/MapPinFlags`.
-- But we don't know which child corresponds to which pin ID.
-- The original script stores them in `m_MapPinInstances` table.

-- CRITICAL: If we can't access `m_MapPinInstances`, we can't easily map pins to controls.
-- UNLESS... we assume the order is same? Risky.

-- WAIT! V10 worked. V10 used XML Replacement + Script.
-- V10 script *did* load for the user?
-- User said "V10 displayed map tacks".
-- If V10 script loaded, why did V11 fail?
-- V11 added `print` and changed style.
-- Maybe `print` caused a crash? (Unlikely).
-- Maybe the *Style* change caused a crash?
-- "YieldBonusText" style was missing.
-- V12 fixed style. V13 fixed path. V16 fixed path.
-- Why did V16 fail to show numbers?
-- Maybe `dmt_v16.lua` loaded, but `include("MapPinManager")` failed?
-- If `include` failed, the script would crash and stop.
-- And since we shadowed the file, the base game logic wouldn't run either.
-- Result: No tacks.
-- BUT user said V16 "Tacks appeared, but no numbers".
-- This implies base game logic RAN.
-- If base game logic ran, then `dmt_v16.lua` MUST have successfully `include("MapPinManager")`.
-- IF it successfully included, then our overrides should have worked.
-- UNLESS... `MapPinManager` is a *singleton* or something weird?

-- Let's look at `dmt_v16.lua` (the one I moved to root).
-- Did I actually put the content in it?
-- I renamed `ui/MapPinManager.lua` to `dmt_v16.lua`.
-- That file had:
-- `include("MapPinManager")`
-- `Initialize()`
-- `UpdateYields()`
-- ...

-- If V16 showed tacks, it means `Initialize()` ran.
-- If `Initialize()` ran, it means `Events.MapPinPlayer_MapPinAdded.Add(OnMapPinPlayer_MapPinAdded)` ran.
-- So why no numbers?
-- 1. `UpdateYields` crashing silently? (pcall should catch it).
-- 2. `YieldText` control not found? (We added it to XML).
-- 3. Text is transparent? (We fixed style in V12).

-- Maybe `include("MapPinManager")` loads the *base* file, but it defines `MapPinFlag` locally?
-- If `MapPinFlag` is local in base file, we can't override it by just including.
-- Let's check base game `MapPinManager.lua` (I don't have it, but standard Civ6 UI uses globals or `include` returns a table).
-- Usually `include` in Civ6 executes the file in the *current* environment.
-- So if base file says `function MapPinFlag:Refresh()`, it goes into global `MapPinFlag`.
-- Then we say `function MapPinFlag:Refresh()`, it overwrites it.
-- This SHOULD work.

-- Why did V16 fail?
-- User: "钉子出现了，但是下面还是没有数值啊" (Tacks appeared, but no numbers below).
-- This means the *Icon* appeared.
-- The *Icon* is managed by `MapPinFlag:Refresh`.
-- If our override was working, we would see the yield.

-- HYPOTHESIS: `include("MapPinManager")` on iPad does NOT load the base file if we have a file with same name?
-- No, V16 file is `dmt_v16.lua`. Base is `MapPinManager.lua`.
-- So `include("MapPinManager")` should find base file.
-- UNLESS... `MapPinManager.lua` is not in the path?
-- It is in `Base/Assets/UI/...`.

-- Let's try the Hook approach (V18) anyway. It's safer because it doesn't rely on `include` behavior.
-- We will COPY the entire `MapPinManager.lua` code into our script, instead of including it.
-- AND we will use `ReplaceUIScript` to replace the base file completely.
-- Wait, we tried that in V9 and it failed (corrupted).
-- We tried in V14 and it failed (ReplaceUIScript ignored?).
-- If `ReplaceUIScript` is ignored, we CANNOT replace the file.

-- So we are back to:
-- 1. XML Replacement works (we control the UI structure).
-- 2. We need to run Lua code that manipulates this UI.
-- 3. We can't replace the base Lua file.
-- 4. We must run a *parallel* Lua context (AddUserInterfaces).
-- 5. This parallel context needs to find the UI controls created by the base script.

-- How to find the controls?
-- `ContextPtr:LookUpControl("/InGame/MapPinManager/MapPinFlags")` gives us the Stack.
-- We can iterate `Stack:GetChildren()`.
-- But we don't know which child is which pin.
-- However, `MapPinFlag` instances usually store their data in the control itself? No.
-- But we can iterate all pins using `GameConfiguration.GetValue("MapPins")` (or similar, actually `Player:GetMapPins()`).
-- And for each pin, we calculate yield.
-- And then... we need to find the matching UI control.
-- The base game probably names them?
-- `local instance = m_MapPinFlags:GetInstance();` -> Names are usually "MapPinFlag" (not unique).
-- UNLESS we set the ID? Base game doesn't set ID to PinID.

-- This is hard.
-- BUT, we have `MapPinManager.xml` replaced!
-- We can change the XML to put the PinID in the control name?
-- No, XML is static.

-- WAIT! The "Exclamation Mark" in V12/V13.
-- User said: "无论我放在什么地方都会有感叹号" (Exclamation mark everywhere).
-- This exclamation mark is `CanPlaceIcon`.
-- In V12/V13, we added it to XML.
-- And it appeared.
-- This means our XML is being used.
-- And the base game script is creating instances from OUR XML.
-- And since base game script doesn't know about `CanPlaceIcon`, it never hides it.
-- So it stays visible (default).

-- This confirms:
-- 1. Base Game Script is running.
-- 2. Base Game Script is using OUR XML.
-- 3. Base Game Script does NOT have our yield calculation logic.

-- So we need to INJECT logic.
-- If `ReplaceUIScript` fails, and `include` fails...
-- We can use `AddUserInterfaces` to load a script.
-- This script can't easily access the base script's locals.
-- BUT, since we control the XML, we can add a `LuaEvent` trigger in the XML!
-- No, XML triggers are limited.

-- What if we use `AddUserInterfaces` to load a script that OVERWRITES the global `MapPinManager` context?
-- `ContextPtr:LookUpControl("/InGame/MapPinManager")` returns the context.
-- Can we use `Context:SetScript(...)`? No.

-- Let's go with the **V18 Hook Plan**, but with a twist:
-- We will use `ContextPtr:LookUpControl("/InGame/MapPinManager")` to get the context.
-- Then we will try to access its global environment.
-- `local targetEnv = getfenv(MapPinManagerContext);` (Not possible in Civ6 Lua).

-- OK, let's look at `dmt_yieldcalculator.lua`. It's a utility library.
-- We can run it in our own context.
-- We can calculate yields.
-- The problem is *displaying* them.
-- We need to get access to the `YieldText` control for each pin.

-- HACK:
-- In our `MapPinManager.xml`, we can add a `<LuaScript>` behavior? No.
-- We can add a `ToolTipType`? No.

-- Let's try the **"Global Event Hook"**.
-- We know `MapPinPlayer_MapPinAdded` fires when a pin is added.
-- Our V18 script will listen to this.
-- When fired, we calculate yield.
-- Then we need to update UI.
-- We can iterate `/InGame/MapPinManager/MapPinFlags` children.
-- How to match?
-- We can check `child:GetText()`? (NameLabel).
-- If the pin name matches, we found it!
-- `NameLabel` is in our XML.
-- So:
-- 1. Listen to events.
-- 2. Calculate yield.
-- 3. Find UI control by matching Pin Name or Location (WorldAnchor).
-- 4. Set text.

-- `WorldAnchor`!
-- The pins are in `WorldAnchor`.
-- `WorldAnchor` positions the control on the map.
-- We can check `WorldAnchor:GetWorldPosition()`.
-- And match it with Pin Location.
-- THIS IS IT!

-- Plan V18 Logic:
-- 1. Load `dmt_hook.lua` via `AddUserInterfaces`.
-- 2. Listen to `MapPinPlayer_MapPinAdded`, `Modified`, `Removed`.
-- 3. On change:
--    a. Get all Map Pins.
--    b. Calculate yields for all pins.
--    c. Get `MapPinFlags` container from `/InGame/MapPinManager`.
--    d. Iterate children.
--    e. For each child, get `Anchor` (WorldAnchor).
--    f. Get X, Y from Anchor (or convert world pos to plot).
--    g. Find matching Pin.
--    h. Set `YieldText` (found via `child:GetID()` or recursive search).

-- Wait, `WorldAnchor` doesn't give grid coordinates easily.
-- But `MapPin` has `GetPlotX()`, `GetPlotY()`.
-- We can convert Plot X,Y to World X,Y.
-- And compare with `Anchor:GetWorldPosition()`.
-- This is complicated but doable.

-- SIMPLER MATCHING:
-- The `NameLabel` contains the pin name.
-- Pin Name is unique-ish.
-- If we match Name + Icon + Player, we are good.

-- Let's write `dmt_hook.lua` to do this.
-- It needs to include `dmt_yieldcalculator.lua`.



-- =================================================================================
-- [DMT-iPad] V7: Brute Force Include Strategy
-- =================================================================================
-- Attempt to load the base game script using multiple casing variations.
local function TryInclude(filename)
    print("DMT: Attempting to include " .. filename);
    local status, err = pcall(function() include(filename) end);
    if status then
        print("DMT: Successfully included " .. filename);
        return true;
    else
        print("DMT: Failed to include " .. filename .. ". Error: " .. tostring(err));
        return false;
    end
end

local includeSuccess = false;
if not includeSuccess then includeSuccess = TryInclude("MapPinManager"); end
if not includeSuccess then includeSuccess = TryInclude("mappinmanager"); end
if not includeSuccess then includeSuccess = TryInclude("MapPinManager.lua"); end
if not includeSuccess then includeSuccess = TryInclude("mappinmanager.lua"); end
if not includeSuccess then includeSuccess = TryInclude("MAPPINMANAGER"); end

if not includeSuccess then
    print("DMT: CRITICAL ERROR - Failed to load base MapPinManager script!");
end

-- =================================================================================
-- [DMT] Core Logic
-- =================================================================================

local m_IsShiftDown = false;
local m_RememberChoice = true;

local m_AddMapTackId:number = Input.GetActionId("AddMapTack");
local m_DeleteMapTackId:number = Input.GetActionId("DeleteMapTack");
local m_ToggleMapTackVisibilityId:number = Input.GetActionId("ToggleMapTackVisibility");

local m_MapPinListBtn = nil;
local m_MapPinFlags = nil;

-- Cache base functions
local BASE_MapPinFlag_Refresh = MapPinFlag.Refresh;
local BASE_OnInputHandler = OnInputHandler;

-- =================================================================================
-- [DMT] Overrides
-- =================================================================================

function MapPinFlag.Refresh(self)
    -- [DMT-iPad] V1: Wrap in pcall to prevent crashes
    local status, err = pcall(function()
        -- Call base refresh first
        if BASE_MapPinFlag_Refresh then
            BASE_MapPinFlag_Refresh(self);
        end
        
        -- Update DMT yields
        UpdateYields(self);
        UpdateCanPlace(self);
    end);

    if not status then
        print("DMT: Error in MapPinFlag.Refresh: " .. tostring(err));
    end

    -- [DMT-iPad] V5: Force Visibility AFTER everything else
    if self.m_Instance then
        if self.m_Instance.Anchor then
            self.m_Instance.Anchor:SetHide(false);
        end
        if self.m_Instance.FlagRoot then
            self.m_Instance.FlagRoot:SetHide(false);
        end
    end
end

function UpdateYields(pMapPinFlag)
    local pMapPin = pMapPinFlag:GetMapPin();

    if pMapPin ~= nil then
        local mapPinSubject = GetMapPinSubject(pMapPin:GetPlayerID(), pMapPin:GetHexX(), pMapPin:GetHexY());
        if mapPinSubject then
            local yieldString = mapPinSubject.YieldString;
            local yieldToolTip = mapPinSubject.YieldToolTip;
            if yieldString ~= nil and yieldString ~= "" then
                pMapPinFlag.m_Instance.YieldText:SetText(yieldString);
                if yieldToolTip ~= nil and yieldToolTip ~= "" then
                    -- [DMT-iPad] Tooltip disabled
                    -- pMapPinFlag.m_Instance.YieldText:SetToolTipString(yieldToolTip);
                else
                    -- pMapPinFlag.m_Instance.YieldText:SetToolTipString("");
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
            -- [DMT-iPad] Tooltip disabled
            -- pMapPinFlag.m_Instance.CanPlaceIcon:SetToolTipString(canPlaceToolTip);
            return;
        end
    end

    pMapPinFlag.m_Instance.CanPlaceIcon:SetHide(true);
    -- [DMT-iPad] Tooltip disabled
    -- pMapPinFlag.m_Instance.CanPlaceIcon:SetToolTipString("");
end

function OnMapPinFlagRightClick(playerID:number, pinID:number)
    if m_IsShiftDown and playerID == Game.GetLocalPlayer() then
        local playerCfg = PlayerConfigurations[playerID];
        -- Update map pin yields.
        LuaEvents.DMT_MapPinRemoved(playerCfg:GetMapPinID(pinID));
        -- Delete the pin.
        playerCfg:DeleteMapPin(pinID);
    else
        -- Call base function if it exists, otherwise handle normally
        -- Note: Base function might be local in some versions, so we might need to replicate logic or use pcall
        -- For now, assuming base logic is handled by the game engine for right click if we don't intercept it fully
        -- But since we replaced the function, we should probably check if there was a base one.
        -- Actually, OnMapPinFlagRightClick is usually a global callback.
    end
end

-- Re-implementing standard functions to ensure they exist if base include failed partially
function ShowMapPins()
    if m_MapPinFlags == nil then
        m_MapPinFlags = ContextPtr:LookUpControl("/InGame/MapPinManager/MapPinFlags");
    end
    if m_MapPinFlags then
        m_MapPinFlags:SetHide(false);
    end
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
    if m_MapPinFlags and not m_MapPinFlags:IsHidden() then
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
    if BASE_OnInputHandler then
        BASE_OnInputHandler(pInputStruct);
    end
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

function DMT_Initialize()
    print("DMT: Initializing...");
    ContextPtr:SetInputHandler(OnInputHandler, true);

    LuaEvents.DMT_DeleteMapPinRequest.Add(OnDeleteMapPinRequest);
    Events.InterfaceModeChanged.Add(OnInterfaceModeChanged);
    Events.InputActionTriggered.Add(OnInputActionTriggered);
    
    -- Force initial visibility check
    ShowMapPins();
end

DMT_Initialize();