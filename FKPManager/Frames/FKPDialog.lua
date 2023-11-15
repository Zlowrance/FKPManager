-- LOCAL VARS
local States = {
    IDLE = 1,
    ITEM_SELECTED = 2,
    BIDDING_STARTED = 3,
    BIDDING_ENDED = 4
}
local state = States.IDLE
local players = {}
local currentAuctionItemID = nil
local currentAuctionItemLink =  nil

-- INITIALIZATION
FKPDialog:SetMovable(true)
FKPDialog:EnableMouse(true)
FKPDialog:RegisterForDrag("LeftButton")

local contentParent = CreateFrame("Frame")
local scrollWidth = ScrollFrame1:GetWidth()
ScrollFrame1:SetScrollChild(contentParent)
contentParent:SetWidth(scrollWidth)
contentParent:SetHeight(1)

BiddingButton:Disable()

local dropTargetFrame = CreateFrame("Frame", "ItemDropTargetFrame", FKPDialog)
dropTargetFrame:SetSize(100, 100) 
dropTargetFrame:SetPoint("TOPLEFT", ItemIcon, "TOPLEFT")
dropTargetFrame:SetPoint("BOTTOMRIGHT", ItemIcon, "BOTTOMRIGHT")
FKPDialog:EnableMouse(true)
FKPDialog:RegisterForDrag("LeftButton")

-- LOCAL FUNCTIONS

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

local function GetTopEndRoll(index)
     return 100 - (math.min(index,5) * 10)
end

local function UpdateItemDisplay(itemId)
    Log("displaying item " .. itemId)
    local _, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
    if not itemLink or not itemIcon then
        return
    end
    ItemIcon:SetTexture(itemIcon)
    ItemName:SetText(itemLink)
    currentAuctionItemLink = itemLink
    currentAuctionItemID = itemId
end

local function ClearItemDisplay()
    ItemIcon:SetTexture(nil)
    ItemName:SetText("")
    currentAuctionItemLink = nil
    currentAuctionItemID = nil
end

local function AddBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
    if GetPlayerIndex(playerName) ~= nil then
        return
    end
    table.insert(players, {name = playerName, fkp = FKPHelper:GetFKP(playerName), roll = 0, frame = nil})
    Log(playerName .. " added to the bid list.")
end

local function RemoveBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
	local playerIndex = GetPlayerIndex(playerName)
    if playerIndex == nil then
        return
    end
    table.remove(players, playerIndex)
    Log(playerName .. " removed from the bid list.")
end

local function InitBidderList()
    -- Sort players by fkp
    table.sort(players, function(a, b) return a.fkp > b.fkp end)

    local existingFrames = {contentParent:GetChildren()}

    local buttonHeight = 60
    local buttonSpacing = 5
    local index = 1
    for _, player in ipairs(players) do
        local buttonName = "Button" .. index
        local button
        if index <= #existingFrames then
            -- Reuse existing button
            button = existingFrames[index]
            button:Show()
        else
            -- Create new button
            button = CreateFrame("Frame", buttonName, contentParent, "FKPListTemplate")
            button:SetSize(scrollWidth - 5, buttonHeight)
            -- Offset by amount of buttons + spacing + 1 for spacing at top of list
            local yOffset = -buttonHeight * (index - 1) - buttonSpacing * (index)
            button:SetPoint("TOP", contentParent, "TOP", 0, yOffset)
            existingFrames[index] = button
        end
        player.frame = button

        local playerPortrait = _G[buttonName .. "Portrait"]
        local playerName = _G[buttonName .. "Name"]
        local playerFKP = _G[buttonName .. "FKP"]
        local playerRoll = _G[buttonName .. "Roll"]
        local removeButton = _G[buttonName .. "RemoveButton"]
        local winnerButton = _G[buttonName .. "WinnerButton"]

        removeButton:Show()
        winnerButton:Hide()

        local topEnd = GetTopEndRoll(index - 1)
        playerName:SetText(player.name)
        playerFKP:SetText(player.fkp .. " FKP")
        playerRoll:SetText("rolls 1-" .. topEnd)

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
        index = index + 1
    end
    -- hide remaining frames if there are any
    for i = index, #existingFrames do
        existingFrames[i]:Hide()
    end
end

local function LayoutBidderList()
    -- remove all frames from parent
    local existingFrames = {contentParent:GetChildren()}
    for i = 1, #existingFrames do
        local buttonName = "Button" .. i
        local button = _G[buttonName]
        button:SetParent(nil)
    end

    -- re-add them in order
    for i, player in ipairs(players) do
        local buttonName = player.frame:GetName()
        local button = _G[buttonName]
        button:SetParent(contentParent)
        local playerName = _G[buttonName .. "Name"]
        local playerIndex = GetPlayerIndex(playerName:GetText())
        local yOffset = -button:GetHeight() * (playerIndex - 1) - 5 * (playerIndex)
        button:SetPoint("TOP", contentParent, "TOP", 0, yOffset)
	end
end

local function SubscribeToChat()
    for i = 1, #CHAT_EVENT_TYPES do
         FKPDialog:RegisterEvent(CHAT_EVENT_TYPES[i])
	end
end

local function UnsubscribeToChat()
    for i = 1, #CHAT_EVENT_TYPES do
         FKPDialog:UnregisterEvent(CHAT_EVENT_TYPES[i])
	end
end

local function SetState(newState)
    state = newState
    UnsubscribeToChat()
    FKPDialog:UnregisterEvent("CHAT_MSG_SYSTEM")
    if state == States.IDLE then
	    ClearItemDisplay()
        ClearItemButton:Hide()
        BiddingButton:Disable()
        Instructions:Show()
        BiddingButtonText:SetText("Start Bidding")
        players = {}
        InitBidderList()
	elseif state == States.ITEM_SELECTED then
	    ClearItemButton:Show()
        BiddingButton:Enable()
        Instructions:Hide()
	elseif state == States.BIDDING_STARTED then
        ClearItemButton:Hide()
        SubscribeToChat()
        SendToRaid("BIDDING START: " .. currentAuctionItemLink)
        SendToRaid("TO BID SAY: " .. BID_MSG)
        BiddingButtonText:SetText("End Bidding")
	elseif state == States.BIDDING_ENDED then 
        if #players == 0 then
		    SetState(States.IDLE)
			return
		end
        BiddingButton:Disable()
        ItemName:SetText("vv Select Winner vv")

        -- flip all entries from remove to pick winner button
        for i, player in ipairs(players) do
            local buttonName = player.frame:GetName()
            local removeButton = _G[buttonName .. "RemoveButton"]
            local winnerButton = _G[buttonName .. "WinnerButton"]
            local playerRoll = _G[buttonName .. "Roll"]

            playerRoll:SetText("Awaiting Roll...")

            removeButton:Hide()
            winnerButton:Show()

            winnerButton:SetScript("OnClick", function(self, button, down)
                FKPHelper:SpendFKP(player.name, FKP_ITEM_COST)
                SetState(States.IDLE)
            end)
		end

        -- register to chat msgs to monitor rolls
        FKPDialog:RegisterEvent("CHAT_MSG_SYSTEM")
	end
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
    local targetTopEnd = GetTopEndRoll(playerIndex - 1)

    if topEnd ~= targetTopEnd then  
		SendToRaid(playerName .. " ROLLED OUT OF " .. topEnd .. " INSTEAD OF " .. targetTopEnd .. "!! SHAME!!")
        return
	end

    player.roll = roll

    local buttonName = "Button" .. playerIndex
    local playerRoll = _G[buttonName .. "Roll"]

    playerRoll:SetText("Rolled " .. roll)

    table.sort(players, function(a, b) return a.roll > b.roll end)
    LayoutBidderList()
end

-- BUTTON HANDLERS

ClearItemButton:SetScript("OnClick", function(self, button, down)
    SetState(States.IDLE)
end)

BiddingButton:SetScript("OnClick", function(self, button, down)
    if state ~= States.BIDDING_STARTED then
        SetState(States.BIDDING_STARTED)
        return
    end

    SendToRaid("ROLL FOR " .. currentAuctionItemLink)
    SendToRaid("======================")

    -- separate these so players get their whisper after the raid dump
	local index = 0
    for _, player in ipairs(players) do
        local topEnd = GetTopEndRoll(index)
        SendToRaid("1-" .. topEnd .. "  " .. player.name)
        index = index + 1
    end

    index = 0
    for _, player in ipairs(players) do
        local topEnd = GetTopEndRoll(index)
        SendToPlayer("roll 1-" .. topEnd, player.name)
        index = index + 1
    end

    SendToRaid("======================")
    SetState(States.BIDDING_ENDED)
end)

FKPDialog:SetScript("OnEvent", function(self, event, message, playerName)
    if event == "CHAT_MSG_SYSTEM" then
        local player, roll, minRoll, maxRoll = string.match(message, "(.+) rolls (%d+) %((%d+)-(%d+)%)")
        if player and roll and minRoll and maxRoll then
            SetPlayerRoll(player, tonumber(roll), tonumber(maxRoll))
        end
        return
    end

    for i = 1, #CHAT_EVENT_TYPES do
        if event == CHAT_EVENT_TYPES[i] then
            if not string.match(message, "^" .. BID_MSG .. "$") then
                if DEBUG then
                    local testBidName = string.match(message, "testbid (%a+)")
                    if testBidName then
                        AddBid(testBidName)
                        InitBidderList()
	                end
                end
                return
            end
            AddBid(playerName)
            InitBidderList()
            return
        end
    end
end)

FKPDialog:SetScript("OnShow", function(self)
    SetState(States.IDLE)
end)

FKPDialog:SetScript("OnHide", function(self)
    SetState(States.IDLE)
end)

FKPDialog:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)

FKPDialog:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
end)

dropTargetFrame:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then
        return
    end
    local cursorType, itemId, link = GetCursorInfo()
    if itemId == nil then
		return
	end
    Log(cursorType .. itemId .. link)
    if cursorType == "item" then
        UpdateItemDisplay(itemId)
        SetState(States.ITEM_SELECTED)
        ClearCursor() 
    end
end)

dropTargetFrame:SetScript("OnEnter", function(self)
    if currentAuctionItemID == nil then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(currentAuctionItemID)
    GameTooltip:Show()
end)

dropTargetFrame:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)