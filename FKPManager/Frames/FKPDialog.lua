local bids = {}

-- INITIALIZATION

Container:RegisterEvent(CHAT_EVENT_TYPE)
Container:SetMovable(true)
Container:EnableMouse(true)
Container:RegisterForDrag("LeftButton")
Container:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)
Container:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
end)

local contentParent = CreateFrame("Frame")
local scrollWidth = ScrollFrame1:GetWidth()
ScrollFrame1:SetScrollChild(contentParent)
contentParent:SetWidth(scrollWidth)
contentParent:SetHeight(1)

Container:Hide()
BiddingButton:Disable()

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

dropTarget:SetScript("OnReceiveDrag", function(self)
    local cursorType, itemId, itemLink = GetCursorInfo()
    if cursorType == "item" then
        UpdateItemDisplay(itemId)
        ClearCursor()
    end
end)

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

local function InitBidderList()
    local buttonHeight = 80
    local index = 0
    local sortedBids = {}
    for name, fkp in pairs(bids) do
        table.insert(sortedBids, {name = name, fkp = fkp})
    end
    -- Sort the array by value in descending order
    table.sort(sortedBids, function(a, b) return a.fkp > b.fkp end)

    ClearFrame(contentParent)

    for _, bid in ipairs(sortedBids) do
        Log(bid.name .. bid.fkp)
        local button = CreateFrame("Frame", bid.name, contentParent, "FKPListTemplate")
        button:SetSize(scrollWidth - 5, buttonHeight) -- Set the size of the button
        button:SetPoint("TOP", 0, -buttonHeight * (index)) -- Position the button

        local playerPortrait = _G[bid.name .. "Portrait"]
        local playerName = _G[bid.name .. "Name"]
        local playerFKP = _G[bid.name .. "FKP"]
        local playerRoll = _G[bid.name .. "Roll"]
        local removeButton = _G[bid.name .. "RemoveButton"]

        local topEnd = GetTopEndRoll(index)
        playerName:SetText(bid.name)
        playerFKP:SetText(bid.fkp)
        playerRoll:SetText("rolls 1-" .. topEnd)

        local unitID = GetRaidMemberUnitIDFromName(bid.name)
        if unitID then
            SetPortraitTexture(playerPortrait, unitID)
        end

        removeButton:SetScript("OnClick", function(self, button, down)
            RemoveBid(bid.name)
        end)

        index = index + 1
    end
end

local function AddBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
    if bids[playerName] ~= nil then
        return
    end
    bids[playerName] = GetFKP(playerName)
    Log(playerName .. " added to the bid list.")
    InitBidderList()
end

local function RemoveBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
    if bids[playerName] == nil then
        return
    end
    bids[playerName] = nil
    Log(playerName .. " removed from the bid list.")
    InitBidderList()
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

Container:SetScript("OnEvent", function(self, event, ...)
    if event == CHAT_EVENT_TYPE then
        local message, playerName = ...

        if not string.match(message, "%f[%a]bid%f[%A]") then
            if DEBUG then
                local testBidName = string.match(message, "testbid (%a+)")
                if testBidName then
                    AddBid(testBidName)
	            end
            end
            return
        end
        AddBid(playerName)
    end
end)

Container:SetScript("OnShow", function(self)
    InitBidderList()
end)

-- SLASH COMMANDS

SLASH_FKP1 = "/fkp"

SlashCmdList["FKP"] = function(msg)
    if Container:IsVisible() then
        Container:Hide()
    else
        Container:Show()
    end
    Log('slash command triggered')
end