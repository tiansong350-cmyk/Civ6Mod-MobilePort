-- =================================================================================
-- Import base file
-- =================================================================================
local files = {
    "mappinpopup.lua",
}

for _, file in ipairs(files) do
    include(file)
    if Initialize then
        print("DMT_MapPinPopup Loading " .. file .. " as base file");
        break
    end
end

local previousTime = 0;
local previousControl = nil;

-- =================================================================================
-- Cache base functions
-- =================================================================================
BASE_OnDelete = OnDelete;
BASE_OnOk = OnOk;
-- BASE_UpdateIconOptionColors = UpdateIconOptionColors; -- [DMT-iPad] Removed override

function OnDelete()
    LuaEvents.DMT_MapPinRemoved(GetEditPinConfig());
    BASE_OnDelete();
end

function OnOk()
    print("DMT_DEBUG: OnOk called"); -- [DMT-iPad] Debug log
    BASE_OnOk();
    LuaEvents.DMT_MapPinAdded(GetEditPinConfig());
end

-- [DMT-iPad] Removed UpdateIconOptionColors override entirely to fix auto-close bug.
-- The original mod used this to implement double-click detection, which misfires on iPad.

-- ===========================================================================
function DMT_Initialize()
    print("DMT_DEBUG: DMT_Initialize called"); -- [DMT-iPad] Debug log
    Controls.DeleteButton:RegisterCallback(Mouse.eLClick, OnDelete);
    Controls.OkButton:RegisterCallback(Mouse.eLClick, OnOk);
end
DMT_Initialize()
