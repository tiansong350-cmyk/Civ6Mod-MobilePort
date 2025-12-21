-- ===========================================================================
-- Force End Turn V10 - 固定CME方式
-- Created by Song with Antigravity
-- ===========================================================================
print("FET V10: Loading...");

local IsBtnAdded = false;
local LONG_PRESS_TIME = 0.8;
local m_PressStartTime = 0;
local m_IsLongPressing = false;

-- 强制结束回合函数
function ForceEndTurn()
    print("FET V10: Force ending turn!");
    local localPlayer = Game.GetLocalPlayer();
    if localPlayer < 0 then 
        print("FET V10: No local player!");
        return; 
    end
    
    -- 方法1: 直接用UI.RequestAction（PC端Shift+Enter）
    if UI.RequestAction and ActionTypes and ActionTypes.ACTION_ENDTURN then
        UI.RequestAction(ActionTypes.ACTION_ENDTURN);
        print("FET V10: Used UI.RequestAction");
        return;
    end
    
    -- 方法2: UI.RequestPlayerOperation
    if UI.RequestPlayerOperation and PlayerOperations and PlayerOperations.END_TURN then
        UI.RequestPlayerOperation(localPlayer, PlayerOperations.END_TURN);
        print("FET V10: Used UI.RequestPlayerOperation");
        return;
    end
    
    -- 方法3: Network.SendPlayerOperation
    if Network and Network.SendPlayerOperation and PlayerOperations and PlayerOperations.END_TURN then
        Network.SendPlayerOperation(localPlayer, PlayerOperations.END_TURN);
        print("FET V10: Used Network.SendPlayerOperation");
        return;
    end
    
    print("FET V10: No end turn method available!");
end

-- 简化的长按处理（使用简单点击先测试功能）
function OnButtonClick()
    print("FET V10: Button clicked - forcing end turn immediately for testing");
    ForceEndTurn();
end

-- 移动按钮到TopPanel右上角
function AddButtonToTopPanel()
    if IsBtnAdded then return; end
    
    local tPanRightStack = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents");
    if tPanRightStack == nil then
        print("FET V10: ERROR - TopPanel/RightContents not found!");
        return;
    end
    
    print("FET V10: TopPanel found, moving button...");
    
    -- 关键：先移动整个Container到TopPanel
    Controls.FetLaunchBarBtnCont:ChangeParent(tPanRightStack);
    -- 使用索引4，应该在回合数右侧（时间和回合数之间）
    tPanRightStack:AddChildAtIndex(Controls.FetLaunchBarBtnCont, 4);
    tPanRightStack:CalculateSize();
    tPanRightStack:ReprocessAnchoring();
    
    -- 注册点击回调 - 先用简单点击测试功能
    Controls.FetLaunchBarBtn:RegisterCallback(Mouse.eLClick, OnButtonClick);
    
    IsBtnAdded = true;
    print("FET V10: Button added to TopPanel at index 5!");
end

function OnLoadGameViewStateDone()
    AddButtonToTopPanel();
end

function OnInit(isReload)
    if isReload then
        AddButtonToTopPanel();
    end
end

ContextPtr:SetInitHandler(OnInit);
Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
print("FET V10: Script loaded, waiting for game...");
