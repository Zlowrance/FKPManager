-- LOCAL VARS
local States = {
    IDLE = 1,
    ITEM_SELECTED = 2,
    BIDDING_STARTED = 3,
    BIDDING_ENDED = 4
}
local state = States.IDLE
local bids = {}
local sortedBids = {}
local rolls = {}
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
    if bids[playerName] ~= nil then
        return
    end
    bids[playerName] = FKPHelper:GetFKP(playerName)
    Log(playerName .. " added to the bid list.")
end

local function RemoveBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
    if bids[playerName] == nil then
        return
    end
    bids[playerName] = nil
    Log(playerName .. " removed from the bid list.")
end

local function InitBidderList()
    sortedBids = {}
    for name, fkp in pairs(bids) do
        table.insert(sortedBids, {name = name, fkp = fkp})
    end
    -- Sort the array by value in descending order
    table.sort(sortedBids, function(a, b) return a.fkp > b.fkp end)

    local existingFrames = {contentParent:GetChildren()}

    local buttonHeight = 60
    local buttonSpacing = 5
    local index = 1
    for _, bid in ipairs(sortedBids) do
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
        Log(bid.name .. bid.fkp)

        local playerPortrait = _G[buttonName .. "Portrait"]
        local playerName = _G[buttonName .. "Name"]
        local playerFKP = _G[buttonName .. "FKP"]
        local playerRoll = _G[buttonName .. "Roll"]
        local removeButton = _G[buttonName .. "RemoveButton"]
        local winnerButton = _G[buttonName .. "WinnerButton"]

        removeButton:Show()
        winnerButton:Hide()

        local topEnd = GetTopEndRoll(index - 1)
        playerName:SetText(bid.name)
        playerFKP:SetText(bid.fkp .. " FKP")
        playerRoll:SetText("rolls 1-" .. topEnd)

        local unitID = GetRaidMemberUnitIDFromName(bid.name)
        if unitID then
            SetPortraitTexture(playerPortrait, unitID)
        else
            playerPortrait:SetTexture(nil)
        end

        removeButton:SetScript("OnClick", function(self, button, down)
            RemoveBid(bid.name)
            InitBidderList()
        end)
        index = index + 1
    end
    -- hide remaining frames if there are any
    for i = index, #existingFrames do
        existingFrames[i]:Hide()
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
        bids = {}
        rolls = {}
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
        if #sortedBids == 0 then
		    SetState(States.IDLE)
			return
		end
        BiddingButton:Disable()
        ItemName:SetText("vv Select Winner vv")

        -- flip all entries from remove to pick winner button
        local existingFrames = {contentParent:GetChildren()}
        for i = 1, #existingFrames do
            local buttonName = "Button" .. i
            local removeButton = _G[buttonName .. "RemoveButton"]
            local winnerButton = _G[buttonName .. "WinnerButton"]
            local playerRoll = _G[buttonName .. "Roll"]

            playerRoll:SetText("Awaiting Roll...")

            removeButton:Hide()
            winnerButton:Show()

            winnerButton:SetScript("OnClick", function(self, button, down)
                FKPHelper:SpendFKP(sortedBids[i].name, FKP_ITEM_COST)
                SetState(States.IDLE)
            end)
        end

        -- register to chat msgs to monitor rolls
        FKPDialog:RegisterEvent("CHAT_MSG_SYSTEM")
	end
end

local function SetPlayerRoll(playerName, roll, topEnd)
    if rolls[playerName] ~= nil then
        Log(playerName .. " tried to roll again")
	    return
	end
    local existingFrames = {contentParent:GetChildren()}
    for i = 1, #existingFrames do
        if sortedBids[i].name == playerName then
            local targetTopEnd = tostring(GetTopEndRoll(i - 1))

            if topEnd ~= targetTopEnd then  
			    SendToRaid(playerName .. " ROLLED OUT OF " .. topEnd .. " INSTEAD OF " .. targetTopEnd .. "!! SHAME!!")
                return
			end

            rolls[playerName] = roll

            local buttonName = "Button" .. i
            local playerRoll = _G[buttonName .. "Roll"]

            playerRoll:SetText("Rolled " .. roll)
		end
    end
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
    for name, _ in pairs(bids) do
        local topEnd = GetTopEndRoll(index)
        SendToRaid("1-" .. topEnd .. "  " .. name)
        index = index + 1
    end

    index = 0
    for name, _ in pairs(bids) do
        local topEnd = GetTopEndRoll(index)
        SendToPlayer("roll 1-" .. topEnd, name)
        index = index + 1
    end

    SendToRaid("======================")
    SetState(States.BIDDING_ENDED)
end)

FKPDialog:SetScript("OnEvent", function(self, event, message, playerName)
    if event == "CHAT_MSG_SYSTEM" then
        local player, roll, minRoll, maxRoll = string.match(message, "(.+) rolls (%d+) %((%d+)-(%d+)%)")
        if player and roll and minRoll and maxRoll then
            SetPlayerRoll(player, roll, maxRoll)
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