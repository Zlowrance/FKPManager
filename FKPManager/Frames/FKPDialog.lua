local biddingStarted = false
local bids = {}
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
    ClearItemButton:Show()
    BiddingButton:Enable()
    Instructions:Hide()
    currentAuctionItemLink = itemLink
    currentAuctionItemID = itemId
end

local function ClearItemDisplay()
    ItemIcon:SetTexture(nil)
    ItemName:SetText("")
    ClearItemButton:Hide()
    BiddingButton:Disable()
    Instructions:Show()
    FKPDialog:UnregisterEvent(CHAT_EVENT_TYPE)
    currentAuctionItemLink = nil
    currentAuctionItemID = nil
end

local function GetFKP(playerName)
    local fkp = FKPData[playerName]
    if fkp == nil then
        return 0
    end
    return fkp
end

local function AddBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
    if bids[playerName] ~= nil then
        return
    end
    bids[playerName] = GetFKP(playerName)
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
    local sortedBids = {}
    for name, fkp in pairs(bids) do
        table.insert(sortedBids, {name = name, fkp = fkp})
    end
    -- Sort the array by value in descending order
    table.sort(sortedBids, function(a, b) return a.fkp > b.fkp end)

    local existingFrames = {contentParent:GetChildren()}

    local buttonHeight = 80
    local buttonSpacing = 5
    local index = 1
    for _, bid in ipairs(sortedBids) do
        local buttonName = "Button" .. index
        local button
        if index <= #existingFrames then
            -- Reuse existing button
            button = existingFrames[index]
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

        local topEnd = GetTopEndRoll(index - 1)
        playerName:SetText(bid.name)
        playerFKP:SetText(bid.fkp .. " FKP")
        playerRoll:SetText("rolls 1-" .. topEnd)

        local unitID = GetRaidMemberUnitIDFromName(bid.name)
        if unitID then
            SetPortraitTexture(playerPortrait, unitID)
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

-- BUTTON HANDLERS

ClearItemButton:SetScript("OnClick", function(self, button, down)
    ClearItemDisplay()
end)

BiddingButton:SetScript("OnClick", function(self, button, down)
    if not biddingStarted then
        FKPDialog:RegisterEvent(CHAT_EVENT_TYPE)
        SendToRaid("BIDDING START: " .. currentAuctionItemLink)
        biddingStarted = true
        BiddingButton:SetText("End Bidding")
        return
    end


    SendToRaid(" BIDDERS ")
    SendToRaid("=========")

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
end)

FKPDialog:SetScript("OnEvent", function(self, event, ...)
    if event == CHAT_EVENT_TYPE then
        local message, playerName = ...

        if not string.match(message, "%f[%a]bid%f[%A]") then
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
    end
end)

FKPDialog:SetScript("OnShow", function(self)
    InitBidderList()
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