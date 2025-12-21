-- ===========================================================================
-- Quick Deals - Unified Tab Manager (iPad Compatible)
-- Single LuaContext that manages three separate tab containers
-- ===========================================================================
include("qd_utils");

-- ===========================================================================
-- Tab Switching Logic
-- ===========================================================================
function OnShowTab(tabType)
    print("QD AllTabs: Switching to tab type:", tabType);
    
    -- Hide all three containers
    Controls.SaleContainer:SetHide(true);
    Controls.PurchaseContainer:SetHide(true);
    Controls.ExchangeContainer:SetHide(true);
    
    -- Show the requested tab
    if tabType == TAB_TYPE.SALE then
        Controls.SaleContainer:SetHide(false);
        -- Notify the sale tab to refresh
        LuaEvents.QD_RefreshSaleTab();
    elseif tabType == TAB_TYPE.PURCHASE then
        Controls.PurchaseContainer:SetHide(false);
        -- Notify the purchase tab to refresh
        LuaEvents.QD_RefreshPurchaseTab();
    elseif tabType == TAB_TYPE.EXCHANGE then
        Controls.ExchangeContainer:SetHide(false);
        -- Notify the exchange tab to refresh
        LuaEvents.QD_RefreshExchangeTab();
    end
end

-- ===========================================================================
-- Initialization
-- ===========================================================================
function Initialize()
    print("QD AllTabs: Initializing unified tab manager");
    
    -- Listen for tab switch events
    LuaEvents.QD_PopupShowTab.Add(OnShowTab);
    
    -- Note: The individual tab lua files (qd_popuptab_*.lua) will
    -- still be loaded - they just need to work within their containers
    -- and listen to the Refresh events we send
end

Initialize();
