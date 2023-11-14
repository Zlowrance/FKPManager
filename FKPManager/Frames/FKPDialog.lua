local bids = {}

-- INITIALIZATION

FKPDialog:RegisterEvent(CHAT_EVENT_TYPE)
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
dropTargetFrame:SetFrameStrata("HIGH")

-- LOCAL FUNCTIONS

local function GetTopEndRoll(index)
     return 100 - (math.min(index,5) * 10)
end

local function UpdateItemDisplay(itemId)
    Log("displaying item " .. itemId)
    local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
    if not itemName or not itemIcon then
        return
    end
    ItemIcon:SetTexture(itemIcon)
    ItemName:SetText(itemName)
    ClearItemButton:Show()
    BiddingButton:Enable()
end

local function ClearItemDisplay()
    ItemIcon:SetTexture(nil)
    ItemName:SetText("")
    ClearItemButton:Hide()
    BiddingButton:Disable()
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
    local buttonHeight = 80
    
    local sortedBids = {}
    for name, fkp in pairs(bids) do
        table.insert(sortedBids, {name = name, fkp = fkp})
    end
    -- Sort the array by value in descending order
    table.sort(sortedBids, function(a, b) return a.fkp > b.fkp end)

    local existingFrames = {contentParent:GetChildren()}

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
            local yOffset = -buttonHeight * (index - 1)
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
        playerFKP:SetText(bid.fkp)
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
    local cursorType, itemId, itemLink = GetCursorInfo()
    if itemId == nil then
		return
	end
    Log(cursorType .. itemId .. itemLink)
    if cursorType == "item" then
        UpdateItemDisplay(itemId)
        ClearCursor() 
    end
end)