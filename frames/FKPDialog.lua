-- LOCAL VARS
local BASE_ANIM_TIME = .3
local QUICK_ANIM_TIME = .15
local SHARE_POPUP_NAME = "FKPMANAGER_ENTER_PLAYER_NAME"
local CLEAR_POPUP_NAME = "FKPMANAGER_CLEAR_HISTORY"
local States = {
    IDLE = "IDLE",
    ITEM_SELECTED = "ITEM_SELECTED",
    BIDDING_STARTED = "BIDDING_STARTED",
    BIDDING_ENDED = "BIDDING_ENDED"
}

local Events = {
    BID_BUTTON_PRESS = "BID_BUTTON_PRESS",
    CHAT_MSG_RECEIVED = "CHAT_MSG_RECEIVED",
    SYSTEM_MSG_RECEIVED = "SYSTEM_MSG_RECEIVED",
    ITEM_AREA_CLICKED = "ITEM_AREA_CLICKED",
    ITEM_ALT_CLICKED = "ITEM_ALT_CLICKED"
}

local fsm = nil
local players = {}
local currentItem = {}
local unusedFrames = {}
local FKPFrameHeight = 60
local FKPFrameSpacing = 5
local historyShown = true
local shareMessage = nil
local addonVersion = C_AddOns.GetAddOnMetadata("FKPManager", "Version")
local dropTargetFrame = nil
local contentParent = nil
local scrollWidth = nil

-- LOCAL FUNCTIONS

local function InitHistory()
    local historyContent = GetChildOfFrame(HistoryScrollView, "HistoryContentParent") or CreateFrame("Frame", "HistoryContentParent")
    HistoryScrollView:SetScrollChild(historyContent)
    local historyWidth = HistoryScrollView:GetWidth()
    historyContent:SetWidth(HistoryScrollView:GetWidth())
    historyContent:SetHeight(1)
    
    ClearFrame(historyContent)
    
    local history = FKPHelper:GetPastBids()
    local historyItemSize = historyWidth - 5
    local historyItemSpacing = 5
    local yOffset = -historyItemSpacing
    -- show textures for each history item
    for i = #history, 1, -1 do
        local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(history[i].itemID)
        if not itemLink or not itemIcon then
            return
        end
        local historyItem = CreateFrame("Frame", "HistoryItem" .. i, historyContent)
        historyItem:SetSize(historyItemSize, historyItemSize)
        historyItem:SetPoint("TOP", historyContent, "TOP", 0, yOffset)
        local historyIcon = historyContent:CreateTexture("HistoryItem" .. i, "BACKGROUND")
        historyIcon:SetTexture(itemIcon)
        historyIcon:SetAllPoints(historyItem)
        yOffset = yOffset - historyItemSize - historyItemSpacing
        historyItem:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(itemName)
            for _, roll in ipairs(history[i].rolls) do
                local icon
                if roll.won then
                    icon = "Interface\\GROUPFRAME\\UI-Group-LeaderIcon"
                end
                local iconString = icon and "|T" .. icon .. ":0|t" or nil
                if iconString then
                    GameTooltip:AddLine(iconString .. roll.playerName, 1, 1, 1)
                else
                    GameTooltip:AddLine(roll.playerName, 1, 1, 1)
                end
                if roll.won then
                    GameTooltip:AddLine("    rolled " .. roll.roll, 1, 1, 0)
                else
                    GameTooltip:AddLine("    rolled " .. roll.roll, .5, .5, .5)
                end
            end
            GameTooltip:Show()
        end)
        
        historyItem:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
end

local function GetPlayerIndex(playerName)
    for i = 1, #players do
        if players[i].name == playerName then
		    return i
		end
	end
    return nil
end

local function GetPlayerData(playerName)
    local index = GetPlayerIndex(playerName)
    if index == nil then
	    return nil
	end
    return players[index]
end

local function GetFKPListFrame()
	if #unusedFrames > 0 then
        -- Reuse existing button
        button = table.remove(unusedFrames, 1)
    else
        -- Create new button
        button = CreateFrame("Frame", "FKPFrame", contentParent, "FKPListTemplate")
        button:SetSize(scrollWidth - 5, FKPFrameHeight)
    end
    button:Show()
	return button
end

local function ReleaseFKPListFrame(frame)
    if frame == nil then
	    return
	end
    frame:Hide()
    table.insert(unusedFrames, frame)
end

--- Returns the top end of the roll range for the player
--- @param player table
--- @return number
local function GetTopEndRoll(player)
     return 100 - (math.min(player.fkpIndex,5) * 10)
end

local function UpdateItemDisplay(itemId)
    Log("displaying item " .. itemId)
    local _, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
    if not itemLink or not itemIcon then
        return
    end
    ItemIcon:SetTexture(itemIcon)
    ItemName:SetText(itemLink)
    currentItem = { id = itemId, link = itemLink }
end

local function ClearItemDisplay()
    ItemIcon:SetTexture(nil)
    ItemName:SetText("")
    currentItem = nil
end

local function AddBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
    if GetPlayerIndex(playerName) ~= nil then
        return
    end
    table.insert(players, {name = playerName, fkp = FKPHelper:GetFKP(playerName), roll = 0, frame = nil, fkpIndex = 0})
    Log(playerName .. " added to the bid list.")
end

local function RemoveBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
	local playerIndex = GetPlayerIndex(playerName)
    if playerIndex == nil then
        return
    end
    local player = players[playerIndex]
    if player.frame ~= nil then
        ReleaseFKPListFrame(player.frame)
        player.frame = nil
	end
    table.remove(players, playerIndex)
    Log(playerName .. " removed from the bid list.")
end

local function LayoutBidderList()
    for i, player in ipairs(players) do
        local button = player.frame
        local yOffset = -button:GetHeight() * (i - 1) - FKPFrameSpacing * i
        button:SetPoint("TOP", contentParent, "TOP", 0, yOffset)
        if fsm:getState() == States.BIDDING_ENDED and player.roll > 0 then
            local playerRoll = GetChildOfFrame(button, "Roll")
            if i == 1 then
                playerRoll:SetTextColor(1, 1, 0)
            else
                playerRoll:SetTextColor(1, 1, 1)
            end
        end
	end
end

local function InitBidderList()
    -- Sort players by fkp
    table.sort(players, function(a, b) return a.fkp > b.fkp end)
    local fkpIndex = 0
    local currentFkp = nil
    for index, player in ipairs(players) do
        if currentFkp == nil then
            currentFkp = player.fkp
        end
        
        if player.fkp < currentFkp then
            fkpIndex = fkpIndex + 1
            currentFkp = player.fkp
        end
        
        local button = player.frame or GetFKPListFrame()
        player.frame = button
        player.fkpIndex = fkpIndex
        
        local playerPortrait = GetChildOfFrame(button, "Portrait")
        local playerName = GetChildOfFrame(button, "Name")
        local playerFKP = GetChildOfFrame(button, "FKP")
        local playerRoll = GetChildOfFrame(button, "Roll")
        local removeButton = GetChildOfFrame(button, "RemoveButton")
        local winnerButton = GetChildOfFrame(button, "WinnerButton")

        removeButton:Show()
        winnerButton:Hide()

        local topEnd = GetTopEndRoll(player)
        playerName:SetText(player.name)
        playerFKP:SetText(player.fkp)
        playerRoll:SetText("rolls 1-" .. topEnd)
        playerRoll:SetTextColor(0.878, 0.878, 0.878)
        
        local unitID = GetRaidMemberUnitIDFromName(player.name)
        if unitID then
            SetPortraitTexture(playerPortrait, unitID)
        else
            playerPortrait:SetTexture(nil)
        end

        removeButton:SetScript("OnClick", function(self, button, down)
            RemoveBid(player.name)
            InitBidderList()
        end)
    end

    LayoutBidderList()
end

local function SubscribeToChat()
    for i = 1, #CHAT_EVENT_TYPES do
         FKPDialog:RegisterEvent(CHAT_EVENT_TYPES[i])
	end
    FKPDialog:RegisterEvent("CHAT_MSG_SYSTEM")
end

local function UnsubscribeToChat()
    for i = 1, #CHAT_EVENT_TYPES do
         FKPDialog:UnregisterEvent(CHAT_EVENT_TYPES[i])
	end
    FKPDialog:UnregisterEvent("CHAT_MSG_SYSTEM")
end

local function SetPlayerRoll(playerName, roll, topEnd)
    local playerIndex = GetPlayerIndex(playerName)
    if playerIndex == nil then
	    Log(playerName .. " tried to roll but they aren't in the list")
	    return
	end
    local player = GetPlayerData(playerName)
    if player.roll > 0 then
        Log(playerName .. " tried to roll again")
	    return
	end
    local targetTopEnd = GetTopEndRoll(player)

    if topEnd ~= targetTopEnd then  
		SendToRaid(playerName .. " ROLLED OUT OF " .. topEnd .. " INSTEAD OF " .. targetTopEnd .. "!! SHAME!!")
        return
	end

    player.roll = roll

    local playerRoll = GetChildOfFrame(player.frame, "Roll")

    playerRoll:SetText("Rolled " .. roll)

    table.sort(players, function(a, b) return a.roll > b.roll end)
    LayoutBidderList()
end

local function ItemSelected(itemId)
    if itemId == nil then
        return
    end
    UpdateItemDisplay(itemId)
    fsm:setState(States.ITEM_SELECTED)
end

-- STATE FUNCS

local function IDLE_Enter(fsm)
    SubscribeToChat()
    ClearItemDisplay()
    ClearItemButton:Hide()
    BiddingButton:Disable()
    Instructions:Show()
    BiddingButtonText:SetText("Start Bidding")
    for _, player in ipairs(players) do
        ReleaseFKPListFrame(player.frame)
    end
    players = {}
    InitBidderList()
end

local function IDLE_ITEM_AREA_CLICKED(fsm, button)
    if button ~= "LeftButton" then
        return
    end
    
    local cursorType, itemId, link = GetCursorInfo()
    if itemId == nil then
		return
	end
    Log(cursorType .. itemId .. link)
    if cursorType == "item" then
        ItemSelected(itemId)
        ClearCursor() 
    end
end

local function IDLE_ITEM_ALT_CLICKED(fsm, itemID)
    if not FKPDialog:IsShown() then
        FKPDialog:Show()
    end
    ItemSelected(itemID)
end

local function ITEM_SELECTED_Enter(fsm)
    ClearItemButton:Show()
    BiddingButton:Enable()
    Instructions:Hide()
end

local function ITEM_SELECTED_BID_BUTTON_PRESS(fsm)
     fsm:setState(States.BIDDING_STARTED)
end

local function BIDDING_STARTED_Enter(fsm)
    SendToRaid("BIDDING START: " .. currentItem.link)
    SendToRaid("TO BID SAY: " .. BID_MSG)
    BiddingButtonText:SetText("End Bidding")
end

local function BIDDING_STARTED_BID_BUTTON_PRESS(fsm)
    fsm:setState(States.BIDDING_ENDED)
end

local function BIDDING_STARTED_CHAT_MSG_RECEIVED(fsm, message, playerName)
    local lowerCase = string.lower(message)
    local bidMsg = string.lower(BID_MSG)
    if not string.match(lowerCase, "^" .. bidMsg .. "$") then
        -- Debug feature for test bids
        if DEBUG and string.match(message, "testbid (%a+)") then
            AddBid(string.match(message, "testbid (%a+)"))
            InitBidderList()
        end
        return
    end
    AddBid(playerName)
    InitBidderList()
end

local function BIDDING_ENDED_Enter(fsm)
    if #players == 0 then
		fsm:setState(States.IDLE)
		return
	end

    -- Send status to chat and players
    SendToRaid("ROLL FOR " .. currentItem.link)
    SendToRaid("======================")

    -- separate these so players get their whisper after the raid dump
	local index = 0
    for _, player in ipairs(players) do
        local topEnd = GetTopEndRoll(player)
        SendToRaid("1-" .. topEnd .. "  " .. player.name)
        index = index + 1
    end
    SendToRaid("======================")

    --index = 0
    --for _, player in ipairs(players) do
    --    local topEnd = GetTopEndRoll(player)
    --    SendToPlayer("roll 1-" .. topEnd, player.name)
    --    index = index + 1
    --end
    
    BiddingButton:Disable()
    ItemName:SetText("vv Select Winner vv")

    -- flip all entries from remove to pick winner button
    for i, player in ipairs(players) do
        local removeButton = GetChildOfFrame(player.frame, "RemoveButton")
        local winnerButton = GetChildOfFrame(player.frame, "WinnerButton")
        local playerRoll = GetChildOfFrame(player.frame, "Roll")

        playerRoll:SetText("Awaiting Roll...")

        removeButton:Hide()
        winnerButton:Show()

        winnerButton:SetScript("OnClick", function(self, button, down)
            FKPHelper:SpendFKP(player.name, FKP_ITEM_COST)
            SendToRaid(player.name .. " wins " .. currentItem.link .. "!!")
            local rolls = {}
            for i = 1, #players do
                if players[i].roll > 0 then
                    table.insert(rolls, {playerName = players[i].name, roll = players[i].roll, won = players[i].name == player.name})
                end
            end
            FKPHelper:AddPastBid(currentItem.id, rolls)
            InitHistory()
            fsm:setState(States.IDLE)
        end)
	end
end

local function BIDDING_ENDED_SYSTEM_MSG_RECEIVED(fsm, message)
    local player, roll, minRoll, maxRoll = string.match(message, "(.+) rolls (%d+) %((%d+)-(%d+)%)")
    if player and roll and minRoll and maxRoll then
        SetPlayerRoll(player, tonumber(roll), tonumber(maxRoll))
    end
end

local function ShowHistoryPanel()
    if historyShown then
        return
    end
    AnimationHelper:MoveBy(History, BASE_ANIM_TIME, -90, 0)
    HistoryOpenButton:Hide()
    HistoryCloseButton:Show()
    historyShown = true
end

local function HideHistoryPanel(instant)
    if not historyShown then
        return
    end
    local duration = instant and 0 or BASE_ANIM_TIME
    AnimationHelper:MoveBy(History, duration, 90, 0)
    HistoryOpenButton:Show()
    HistoryCloseButton:Hide()
    historyShown = false
end

local function ApplyButtonPressAnimation(frame)
    -- AnimationHelper:PunchScale(frame, 1.1, QUICK_ANIM_TIME)
end

function FKPDialog_OnLoad()
    -- INITIALIZATION
    FKPDialog:EnableMouse(true)
    FKPDialog:RegisterForDrag("LeftButton")
    FKPDialog:SetClampedToScreen(false)
    FKPDialog:SetMovable(false)

    BiddingButton:Disable()
    
    InitHistory()
    HideHistoryPanel(true)
    
    local versionText = "v" .. addonVersion
    VersionDisplay:SetText(versionText)

    dropTargetFrame = CreateFrame("Frame", "ItemDropTargetFrame", FKPDialog)
    dropTargetFrame:SetSize(100, 100)
    dropTargetFrame:SetPoint("TOPLEFT", ItemIcon, "TOPLEFT")
    dropTargetFrame:SetPoint("BOTTOMRIGHT", ItemIcon, "BOTTOMRIGHT")
    contentParent = CreateFrame("Frame")
    scrollWidth = ScrollFrame1:GetWidth()
    ScrollFrame1:SetScrollChild(contentParent)
    contentParent:SetWidth(scrollWidth)
    contentParent:SetHeight(1)

    fsm:setState(States.IDLE)
    
    -- FRAME EVENT HANDLERS
    CloseButton:SetScript("OnClick", function(self, button, down)
        FKPDialog:SetClampedToScreen(false)
        FKPDialog:SetMovable(false)
        local startX, startY = FKPDialog:GetCenter()
        local handle = AnimationHelper:SlideOut(FKPDialog, BASE_ANIM_TIME, AnimationDirection.DOWN, nil, function()
            FKPDialog:Hide()
            FKPDialog:ClearAllPoints()
            FKPDialog:SetPoint("CENTER", UIParent, "BOTTOMLEFT", startX, startY)
        end)
        ApplyButtonPressAnimation(CloseButton)
    end)

    ClearItemButton:SetScript("OnClick", function(self, button, down)
        fsm:setState(States.IDLE)
        ApplyButtonPressAnimation(ClearItemButton)
    end)

    BiddingButton:SetScript("OnClick", function(self, button, down)
        fsm:handleEvent(Events.BID_BUTTON_PRESS)
        ApplyButtonPressAnimation(BiddingButton)
    end)

    HistoryOpenButton:SetScript("OnClick", function(self, button, down)
        ShowHistoryPanel()
        ApplyButtonPressAnimation(HistoryOpenButton)
    end)

    HistoryCloseButton:SetScript("OnClick", function(self, button, down)
        HideHistoryPanel()
        ApplyButtonPressAnimation(HistoryCloseButton)
    end)

    HistoryClearButton:SetScript("OnClick", function(self, button, down)
        StaticPopup_Show(CLEAR_POPUP_NAME)
        ApplyButtonPressAnimation(HistoryClearButton)
    end)

    HistoryShareButton:SetScript("OnClick", function(self, button, down)
        local history = FKPHelper:GetPastBids()
        shareMessage = "WINNERS: "
        for i = #history, 1, -1 do
            local _, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(history[i].itemID)
            if not itemLink or not itemIcon then
                return
            end
            shareMessage = shareMessage .. itemLink .. ":"
            local winnerFound = false
            for _, roll in ipairs(history[i].rolls) do
                if roll.won then
                    shareMessage = shareMessage .. roll.playerName
                    winnerFound = true
                    break
                end
            end

            if not winnerFound then
                shareMessage = shareMessage .. "No winner"
            end
            shareMessage = shareMessage .. ", "
        end
        StaticPopup_Show(SHARE_POPUP_NAME)
        ApplyButtonPressAnimation(HistoryShareButton)
    end)

    FKPDialog:SetScript("OnEvent", function(self, event, message, playerName)
        if event == "CHAT_MSG_SYSTEM" then
            fsm:handleEvent(Events.SYSTEM_MSG_RECEIVED, message)
            return
        end

        local shouldHandle = false

        for index, value in ipairs(CHAT_EVENT_TYPES) do
            if value == event then
                shouldHandle = true
                break
            end
        end

        if not shouldHandle then
            return
        end

        fsm:handleEvent(Events.CHAT_MSG_RECEIVED, message, playerName)
    end)

    FKPDialog:SetScript("OnShow", function(self)
        AnimationHelper:SlideIn(FKPDialog, BASE_ANIM_TIME, AnimationDirection.UP, nil, function()
            FKPDialog:SetClampedToScreen(true)
            FKPDialog:SetMovable(true)
        end)
    end)
    
    FKPDialog:SetScript("OnMouseDown", function(self)
        if not FKPDialog:IsMovable() then
            return
        end
        self:StartMoving()
    end)

    FKPDialog:SetScript("OnMouseUp", function(self)
        if not FKPDialog:IsMovable() then
            return
        end
        self:StopMovingOrSizing()
    end)
    
    dropTargetFrame:SetScript("OnMouseDown", function(self, button)
        fsm:handleEvent(Events.ITEM_AREA_CLICKED, button)
    end)

    dropTargetFrame:SetScript("OnEnter", function(self)
        if currentItem == nil then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(currentItem.id)
        GameTooltip:Show()
    end)

    dropTargetFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    hooksecurefunc("HandleModifiedItemClick", function(itemLink)
        if IsAltKeyDown() then
            local _, id = string.match(itemLink, "(%a+):(%d+)")
            fsm:handleEvent(Events.ITEM_ALT_CLICKED, id)
        end
    end)
end

-- FSM SETUP

local states = {
    [States.IDLE] = {
        enter = IDLE_Enter,
        events = {
            [Events.ITEM_AREA_CLICKED] = IDLE_ITEM_AREA_CLICKED,
            [Events.ITEM_ALT_CLICKED] = IDLE_ITEM_ALT_CLICKED
        }
    },
    [States.ITEM_SELECTED] = {
        enter = ITEM_SELECTED_Enter,
        events = {
			[Events.BID_BUTTON_PRESS] = ITEM_SELECTED_BID_BUTTON_PRESS,
            [Events.ITEM_ALT_CLICKED] = IDLE_ITEM_ALT_CLICKED
		}
    },
    [States.BIDDING_STARTED] = {
        enter = BIDDING_STARTED_Enter,
		events = {
			[Events.BID_BUTTON_PRESS] = BIDDING_STARTED_BID_BUTTON_PRESS,
            [Events.CHAT_MSG_RECEIVED] = BIDDING_STARTED_CHAT_MSG_RECEIVED
		}
    },
    [States.BIDDING_ENDED] = {
        enter = BIDDING_ENDED_Enter,
        events = {
			[Events.SYSTEM_MSG_RECEIVED] = BIDDING_ENDED_SYSTEM_MSG_RECEIVED
		}
    },
}
fsm = FSM:new(states)

-- POPUP SETUP

StaticPopupDialogs[SHARE_POPUP_NAME] = {
    text = "Enter player name to share winners with:",
    button1 = "OK",
    button2 = "Cancel",
    OnAccept = function(self)
        local playerName = self.editBox:GetText()
        SendToPlayer(shareMessage, playerName)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- Avoids some UI taint issues
    hasEditBox = true
}

StaticPopupDialogs[CLEAR_POPUP_NAME] = {
    text = "Are you sure you want to clear the history?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self)
        FKPHelper:ClearPastBids()
        InitHistory()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- Avoids some UI taint issues
}