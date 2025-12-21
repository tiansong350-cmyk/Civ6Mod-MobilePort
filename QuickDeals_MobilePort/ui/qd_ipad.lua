-- ===========================================================================
-- Quick Deals - iPad Version (Simplified Single File)
-- All three tabs in one file, simple Container switching
-- ===========================================================================
include("InstanceManager");
include("LeaderIcon");
include("qd_dealmanager"); -- This includes qd_utils
include("qd_common");

-- ===========================================================================
-- Variables
-- ===========================================================================
local m_CurrentTab = TAB_TYPE.SALE;
local m_LocalPlayer;
local m_AIPlayers;
local m_LeaderUniqueness;

-- Instance Managers (separate for each tab to avoid conflicts)
local ms_SaleIconOnlyIM:table = InstanceManager:new("IconOnly", "SelectButton", Controls.Sale_MyInventoryStack);
local ms_SaleAIOfferIM:table = InstanceManager:new("AISaleOfferInstance", "OfferContainer", Controls.Sale_AIOffersStack);
local ms_PurchaseAIOfferIM:table = InstanceManager:new("AIPurchaseOfferRowInstance", "OfferRowContainer", Controls.Purchase_AIOffersStack);
local ms_ExchangeAIOfferIM:table = InstanceManager:new("AIExchangeOfferRowInstance", "OfferRowContainer", Controls.Exchange_AIOffersStack);

-- ===========================================================================
-- Tab Switching (SIMPLE - just SetHide!)
-- ===========================================================================
function SwitchToTab(tabType)
    print("QD iPad: Switching to tab", tabType);
    
    -- Hide all tabs
    Controls.SaleContent:SetHide(true);
    Controls.PurchaseContent:SetHide(true);
    Controls.ExchangeContent:SetHide(true);
    
    -- Show selected tab
    m_CurrentTab = tabType;
    if tabType == TAB_TYPE.SALE then
        Controls.SaleContent:SetHide(false);
        RefreshSaleTab();
    elseif tabType == TAB_TYPE.PURCHASE then
        Controls.PurchaseContent:SetHide(false);
        RefreshPurchaseTab();
    elseif tabType == TAB_TYPE.EXCHANGE then
        Controls.ExchangeContent:SetHide(false);
        RefreshExchangeTab();
    end
end

-- ===========================================================================
-- Sale Tab Logic
-- ===========================================================================
function RefreshSaleTab()
    print("QD iPad: Refreshing Sale tab");
    ms_SaleIconOnlyIM:ResetInstances();
    ms_SaleAIOfferIM:ResetInstances();
    
    -- Just fetch AI offers for now
    UpdateSaleAIOffers();
end

function PopulateSaleInventory()
    -- Clear first
    ms_SaleIconOnlyIM:ResetInstances();
    
    -- Show "Fetching" label initially
    Controls.Sale_FetchingDealLabel:SetHide(false);
    Controls.Sale_NoAvailableDealLabel:SetHide(true);
    
    print("QD iPad Sale: Populating inventory");
    
    -- For now, just hide the "loading" label immediately
    -- The real content will come from OnSaleAIOffersFetched
    Controls.Sale_FetchingDealLabel:SetHide(true);
end

function UpdateSaleAIOffers()
    Controls.Sale_FetchingDealLabel:SetHide(false);
    Controls.Sale_NoAvailableDealLabel:SetHide(true);
    
    -- Request AI offers from backend
    LuaEvents.QD_StartAIOfferFetch(m_LocalPlayer:GetID(), m_AIPlayers, {});
end

function OnSaleAIOffersFetched(aiOffers:table)
    print("QD iPad SALE: OnSaleAIOffersFetched called, m_CurrentTab=", m_CurrentTab, "TAB_TYPE.SALE=", TAB_TYPE.SALE);
    if m_CurrentTab ~= TAB_TYPE.SALE then 
        print("QD iPad SALE: Skipping because tab mismatch");
        return; 
    end
    
    print("QD iPad SALE: aiOffers count=", #aiOffers);
    
    ms_SaleAIOfferIM:ResetInstances();
    Controls.Sale_FetchingDealLabel:SetHide(true);
    
    if #aiOffers == 0 then
        print("QD iPad SALE: No offers, showing NoAvailableLabel");
        Controls.Sale_NoAvailableDealLabel:SetHide(false);
        return;
    end
    
    print("QD iPad SALE: Creating", #aiOffers, "offer instances");
    for _, offer in ipairs(aiOffers) do
        if offer.OneTimeGold ~= 0 or offer.MultiTurnGold ~= 0 or offer.HasNonGoldItem then
            local instance = ms_SaleAIOfferIM:GetInstance();
            PopulateAIOffer(offer, instance);  -- Use simple version
        end
    end
end

function PopulateSaleOffer(offer, offerControl)
    -- Set leader icon
    local leaderTypeName = PlayerConfigurations[offer.PlayerId]:GetLeaderTypeName();
    local leaderIcon = LeaderIcon:AttachInstance(offerControl.LeaderTargetIcon);
    local leaderIconName = "ICON_" .. leaderTypeName;
    leaderIcon:UpdateIcon(leaderIconName, offer.PlayerId, m_LeaderUniqueness[leaderTypeName]);
    leaderIcon:RegisterCallback(Mouse.eLClick, function() 
        LuaEvents.QD_RequestDealScreen(offer.PlayerId);
    end);
    
    -- Gold balance
    local goldBalance = math.floor(Players[offer.PlayerId]:GetTreasury():GetGoldBalance());
    offerControl.GoldBalance:SetText(tostring(goldBalance));
    
    -- Set gold amounts
    SetIconToSize(offerControl.OneTimeGold.Icon, "ICON_YIELD_GOLD_5");
    offerControl.OneTimeGold.Icon:SetColor(1,1,1);
    if offer.OneTimeGold == 0 then offerControl.OneTimeGold.Icon:SetColor(0.5, 0.5, 0.5); end
    offerControl.OneTimeGold.AmountText:SetText(offer.OneTimeGold);
    offerControl.OneTimeGold.RemoveButton:SetHide(true);
    offerControl.OneTimeGold.SelectButton:SetHide(false);
    offerControl.OneTimeGold.SelectButton:SetDisabled(offer.OneTimeGold == 0);
    
    SetIconToSize(offerControl.MultiTurnGold.Icon, "ICON_YIELD_GOLD_5");
    offerControl.MultiTurnGold.Icon:SetColor(1,1,1);
    if offer.MultiTurnGold == 0 then offerControl.MultiTurnGold.Icon:SetColor(0.5, 0.5, 0.5); end
    offerControl.MultiTurnGold.AmountText:SetText(offer.MultiTurnGold);
    offerControl.MultiTurnGold.IconText:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_FOR_TURNS", 30);
    offerControl.MultiTurnGold.ValueText:SetHide(true);
    offerControl.MultiTurnGold.RemoveButton:SetHide(true);
    offerControl.MultiTurnGold.SelectButton:SetDisabled(offer.MultiTurnGold == 0);
    
    -- MTG arrows
    offerControl.IncreaseMTG:SetDisabled(offer.OneTimeGold == 0);
    offerControl.DecreaseMTG:SetDisabled(offer.MultiTurnGold == 0);
    offerControl.IncreaseMTG:RegisterCallback(Mouse.eLClick, function() 
        LuaEvents.QD_StartMultiTurnGoldUpdate(m_LocalPlayer:GetID(), offer.PlayerId, 1, offerControl, false);
    end);
    offerControl.DecreaseMTG:RegisterCallback(Mouse.eLClick, function() 
        LuaEvents.QD_StartMultiTurnGoldUpdate(m_LocalPlayer:GetID(), offer.PlayerId, -1, offerControl, false);
    end);
    
    -- Unknown type
    if offer.HasNonGoldItem then
        SetIconToSize(offerControl.UnknownType.Icon, "ICON_CIVILIZATION_UNKNOWN", 36);
        offerControl.UnknownType.Icon:SetColor(1,1,1);
        offerControl.UnknownType.AmountText:SetText("");
        offerControl.UnknownType.RemoveButton:SetHide(true);
        offerControl.UnknownType.SelectButton:SetHide(false);
        offerControl.UnknownType.SelectButton:SetDisabled(true);
    else
        offerControl.UnknownType.SelectButton:SetHide(true);
    end
    
    -- Offered items
    local iconOnlyIM = InstanceManager:new("IconOnly", "SelectButton", offerControl.OfferedItemsStack);
    iconOnlyIM:ResetInstances();
    for _, item in ipairs(offer.OfferedItems) do
        local uiIcon = iconOnlyIM:GetInstance();
        SetIconToSize(uiIcon.Icon, GetItemTypeIcon(item));
        if item.Type == DealItemTypes.GREATWORK then
            uiIcon.AmountText:SetText(nil);
        else
            uiIcon.AmountText:SetText(item.Amount);
        end
        uiIcon.RemoveButton:SetHide(true);
        uiIcon.SelectButton:SetHide(false);
        uiIcon.SelectButton:SetDisabled(true);
        uiIcon.SelectButton:LocalizeAndSetToolTip(GetItemToolTip(item));
    end
    offerControl.OfferedItemsStack:CalculateSize();
    
    -- Action buttons
    if offer.HasNonGoldItem then
        offerControl.AcceptDeal:SetHide(true);
        offerControl.DealDetails:SetHide(false);
        offerControl.DealDetails:RegisterCallback(Mouse.eLClick, function() 
            LuaEvents.QD_RequestDealScreen(offer.PlayerId);
        end);
    else
        offerControl.DealDetails:SetHide(true);
        offerControl.AcceptDeal:SetHide(false);
        offerControl.AcceptDeal:RegisterCallback(Mouse.eLClick, function() 
            OnAcceptDeal(offer.PlayerId);
        end);
    end
    
    -- Extra indicator
    if offer.Equalized == false then
        offerControl.ExtraIndicator:SetHide(false);
        offerControl.ExtraIndicator:LocalizeAndSetToolTip("LOC_QD_ALL_GOLD_HINT");
    else
        offerControl.ExtraIndicator:SetHide(true);
    end
end

-- ===========================================================================
-- Purchase Tab Logic
-- ===========================================================================
local m_PurchaseItemType = ITEM_TYPE.LUXURY_RESOURCES;
local m_PurchaseSortBy = SORT_BY.EACH;

function RefreshPurchaseTab()
    print("QD iPad: Refreshing Purchase tab");
    ms_PurchaseAIOfferIM:ResetInstances();
    
    Controls.Purchase_FetchingDealLabel:SetHide(false);
    Controls.Purchase_NoAvailableDealLabel:SetHide(true);
    
    -- Request purchase offers
    LuaEvents.QD_StartAIOfferFetch(m_LocalPlayer:GetID(), m_AIPlayers, {}, m_PurchaseItemType, nil);
end

function OnPurchaseAIOffersFetched(aiOffers:table)
    if m_CurrentTab ~= TAB_TYPE.PURCHASE then return; end
    
    aiOffers = SortOffers(aiOffers, m_PurchaseSortBy, false);
    ms_PurchaseAIOfferIM:ResetInstances();
    Controls.Purchase_FetchingDealLabel:SetHide(true);
    
    if #aiOffers == 0 then
        Controls.Purchase_NoAvailableDealLabel:SetHide(false);
        return;
    end
    
    for _, offer in ipairs(aiOffers) do
        if offer.OneTimeGold ~= 0 or offer.MultiTurnGold ~= 0 or offer.HasNonGoldItem then
            local instance = ms_PurchaseAIOfferIM:GetInstance();
            PopulateAIOffer(offer, instance);  -- Use simple version
        end
    end
end

function PopulatePurchaseOffer(offer, offerControl)
    -- Set leader icon
    local leaderTypeName = PlayerConfigurations[offer.PlayerId]:GetLeaderTypeName();
    local leaderIcon = LeaderIcon:AttachInstance(offerControl.LeaderTargetIcon);
    local leaderIconName = "ICON_" .. leaderTypeName;
    leaderIcon:UpdateIcon(leaderIconName, offer.PlayerId, m_LeaderUniqueness[leaderTypeName]);
    leaderIcon:RegisterCallback(Mouse.eLClick, function() 
        LuaEvents.QD_RequestDealScreen(offer.PlayerId);
    end);
    
    -- Set gold amounts
    SetIconToSize(offerControl.OneTimeGold.Icon, "ICON_YIELD_GOLD_5");
    offerControl.OneTimeGold.Icon:SetColor(1,1,1);
    if offer.OneTimeGold == 0 then offerControl.OneTimeGold.Icon:SetColor(0.5, 0.5, 0.5); end
    offerControl.OneTimeGold.AmountText:SetText(offer.OneTimeGold);
    offerControl.OneTimeGold.RemoveButton:SetHide(true);
    offerControl.OneTimeGold.SelectButton:SetHide(false);
    offerControl.OneTimeGold.SelectButton:SetDisabled(offer.OneTimeGold == 0);
    
    SetIconToSize(offerControl.MultiTurnGold.Icon, "ICON_YIELD_GOLD_5");
    offerControl.MultiTurnGold.Icon:SetColor(1,1,1);
    if offer.MultiTurnGold == 0 then offerControl.MultiTurnGold.Icon:SetColor(0.5, 0.5, 0.5); end
    offerControl.MultiTurnGold.AmountText:SetText(offer.MultiTurnGold);
    offerControl.MultiTurnGold.IconText:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_FOR_TURNS", 30);
    offerControl.MultiTurnGold.ValueText:SetHide(true);
    offerControl.MultiTurnGold.RemoveButton:SetHide(true);
    offerControl.MultiTurnGold.SelectButton:SetDisabled(offer.MultiTurnGold == 0);
    
    -- MTG arrows
    offerControl.IncreaseMTG:SetDisabled(offer.OneTimeGold == 0);
    offerControl.DecreaseMTG:SetDisabled(offer.MultiTurnGold == 0);
    offerControl.IncreaseMTG:RegisterCallback(Mouse.eLClick, function() 
        LuaEvents.QD_StartMultiTurnGoldUpdate(m_LocalPlayer:GetID(), offer.PlayerId, 1, offerControl, true);
    end);
    offerControl.DecreaseMTG:RegisterCallback(Mouse.eLClick, function() 
        LuaEvents.QD_StartMultiTurnGoldUpdate(m_LocalPlayer:GetID(), offer.PlayerId, -1, offerControl, true);
    end);
    
    -- Unknown type
    if offer.HasNonGoldItem then
        SetIconToSize(offerControl.UnknownType.Icon, "ICON_CIVILIZATION_UNKNOWN", 36);
        offerControl.UnknownType.Icon:SetColor(1,1,1);
        offerControl.UnknownType.AmountText:SetText("");
        offerControl.UnknownType.RemoveButton:SetHide(true);
        offerControl.UnknownType.SelectButton:SetHide(false);
        offerControl.UnknownType.SelectButton:SetDisabled(true);
    else
        offerControl.UnknownType.SelectButton:SetHide(true);
    end
    
    -- Offered items
    local iconOnlyIM = InstanceManager:new("IconOnly", "SelectButton", offerControl.OfferedItemsStack);
    iconOnlyIM:ResetInstances();
    for _, item in ipairs(offer.OfferedItems) do
        local uiIcon = iconOnlyIM:GetInstance();
        SetIconToSize(uiIcon.Icon, GetItemTypeIcon(item));
        if item.Type == DealItemTypes.GREATWORK then
            uiIcon.AmountText:SetText(nil);
        else
            uiIcon.AmountText:SetText(item.Amount);
        end
        uiIcon.RemoveButton:SetHide(true);
        uiIcon.SelectButton:SetHide(false);
        uiIcon.SelectButton:SetDisabled(true);
        uiIcon.SelectButton:LocalizeAndSetToolTip(GetItemToolTip(item));
    end
    offerControl.OfferedItemsStack:CalculateSize();
    
    -- Action buttons
    if offer.HasNonGoldItem then
        offerControl.AcceptDeal:SetHide(true);
        offerControl.DealDetails:SetHide(false);
        offerControl.DealDetails:RegisterCallback(Mouse.eLClick, function() 
            LuaEvents.QD_RequestDealScreen(offer.PlayerId);
        end);
    else
        offerControl.DealDetails:SetHide(true);
        offerControl.AcceptDeal:SetHide(false);
        offerControl.AcceptDeal:RegisterCallback(Mouse.eLClick, function() 
            OnAcceptDeal(offer.PlayerId);
        end);
    end
    
    -- Extra indicator
    if offer.Equalized == false then
        offerControl.ExtraIndicator:SetHide(false);
        offerControl.ExtraIndicator:LocalizeAndSetToolTip("LOC_QD_ALL_GOLD_HINT");
    else
        offerControl.ExtraIndicator:SetHide(true);
    end
end

-- ===========================================================================
-- Exchange Tab Logic
-- ===========================================================================
function RefreshExchangeTab()
    print("QD iPad: Refreshing Exchange tab");
    ms_ExchangeAIOfferIM:ResetInstances();
    
    Controls.Exchange_FetchingDealLabel:SetHide(false);
    Controls.Exchange_NoAvailableDealLabel:SetHide(true);
    
    -- Request exchange offers
    LuaEvents.QD_StartAIOfferFetch(m_LocalPlayer:GetID(), m_AIPlayers, {});
end

function OnExchangeAIOffersFetched(aiOffers:table)
    if m_CurrentTab ~= TAB_TYPE.EXCHANGE then return; end
    
    ms_ExchangeAIOfferIM:ResetInstances();
    Controls.Exchange_FetchingDealLabel:SetHide(true);
    
    if #aiOffers == 0 then
        Controls.Exchange_NoAvailableDealLabel:SetHide(false);
        return;
    end
    
    for _, offer in ipairs(aiOffers) do
        local instance = ms_ExchangeAIOfferIM:GetInstance();
        PopulateAIOffer(offer, instance);
    end
end

-- ===========================================================================
-- Common: Populate AI Offer
-- ===========================================================================
function PopulateAIOffer(offer, offerControl)
    -- Set leader icon
    local leaderTypeName = PlayerConfigurations[offer.PlayerId]:GetLeaderTypeName();
    local leaderIcon = LeaderIcon:AttachInstance(offerControl.LeaderTargetIcon);
    local leaderIconName = "ICON_" .. leaderTypeName;
    leaderIcon:UpdateIcon(leaderIconName, offer.PlayerId, m_LeaderUniqueness[leaderTypeName]);
    
    -- Set gold amounts
    SetIconToSize(offerControl.OneTimeGold.Icon, "ICON_YIELD_GOLD_5");
    offerControl.OneTimeGold.AmountText:SetText(offer.OneTimeGold or 0);
    
    -- Set accept button
    offerControl.AcceptDeal:RegisterCallback(Mouse.eLClick, function()
        OnAcceptDeal(offer.PlayerId);
    end);
end

function OnAcceptDeal(otherPlayerId)
    print("QD iPad: Accept deal with player", otherPlayerId);
    if DealManager.AreWorkingDealsEqual(m_LocalPlayer:GetID(), otherPlayerId) then
        LuaEvents.QD_StartAIOfferAccept(m_LocalPlayer:GetID(), otherPlayerId);
    end
end

-- ===========================================================================
-- Initialization
-- ===========================================================================
function OnInit(isReload)
    if Game.GetLocalPlayer() == -1 then return; end
    
    m_LocalPlayer = Players[Game.GetLocalPlayer()];
    m_AIPlayers = GetAIPlayersToCheck(m_LocalPlayer);
    m_LeaderUniqueness = GetLeaderUniqueness(m_AIPlayers);
    
    print("QD iPad: Initialized");
end

function Initialize()
    ContextPtr:SetInitHandler(OnInit);
    ContextPtr:SetAutoSize(true);
    ContextPtr:SetHide(true);
    
    -- Listen for tab switch events from main popup
    LuaEvents.QD_PopupShowTab.Add(SwitchToTab);
    
    -- Listen for AI offer fetch results
    LuaEvents.QD_EndAIOfferFetch.Add(function(aiOffers)
        print("QD iPad: QD_EndAIOfferFetch event received, m_CurrentTab=", m_CurrentTab);
        print("QD iPad: aiOffers count=", #aiOffers);
        
        -- Route to correct tab handler
        if m_CurrentTab == TAB_TYPE.SALE then
            print("QD iPad: Routing to SALE handler");
            OnSaleAIOffersFetched(aiOffers);
        elseif m_CurrentTab == TAB_TYPE.PURCHASE then
            print("QD iPad: Routing to PURCHASE handler");
            OnPurchaseAIOffersFetched(aiOffers);
        elseif m_CurrentTab == TAB_TYPE.EXCHANGE then
            print("QD iPad: Routing to EXCHANGE handler");
            OnExchangeAIOffersFetched(aiOffers);
        else
            print("QD iPad: ERROR - Unknown tab type:", m_CurrentTab);
        end
    end);
    
    print("QD iPad: Event listeners registered");
end

Initialize();
