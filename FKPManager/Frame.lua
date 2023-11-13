local bids = {}

Container:RegisterEvent(CHAT_TYPE)
Container:SetMovable(true)
Container:EnableMouse(true)
Container:RegisterForDrag("LeftButton")
Container:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)
Container:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
end)

local function GetTopEndRoll(index)
     return 100 - (math.min(index,5) * 10)
end

EndBiddingButton:SetScript("OnClick", function(self, button, down)
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

-- setup scroller content
local contentParent = CreateFrame("Frame")
local scrollWidth = ScrollFrame1:GetWidth()
ScrollFrame1:SetScrollChild(contentParent)
contentParent:SetWidth(scrollWidth)
contentParent:SetHeight(1)

local function InitBidderList() 
    local buttonHeight = 30
    local index = 0
    for name, _ in pairs(bids) do
        local button = CreateFrame("Button", name, contentParent, "UIPanelButtonTemplate")
        button:SetSize(scrollWidth - 5, buttonHeight) -- Set the size of the button
        button:SetPoint("TOP", 0, -buttonHeight * (index)) -- Position the button

        local topEnd = GetTopEndRoll(index)

        button:SetText(name) -- Set button text

        -- Set up an OnClick script for the button
        button:SetScript("OnClick", function()
            Log("Rolled " .. math.random(1,topEnd))
        end)
        index = index + 1
    end
end

Container:SetScript("OnEvent", function(self, event, ...)
    if event == CHAT_TYPE then
        local message, playerName = ...

        if not string.match(message, "%f[%a]bid%f[%A]") then
            return
        end
        playerName = GetCharacterName(playerName)
        if not bids[playerName] then
            bids[playerName] = true
            print(playerName .. " added to the bid list.")
            InitBidderList() 
        end
    end
end)

InitBidderList()

local itemTexture = _G["ItemIcon"]
local itemNameFontString = _G["ItemName"]

function UpdateItemDisplay(itemId)
    Log("displaying item " .. itemId)
    local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
    if itemName and itemIcon then
        itemTexture:SetTexture(itemIcon)
        itemNameFontString:SetText(itemName)
    end
end

local scanTooltip = CreateFrame("GameTooltip", "ScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

function GetItemIDFromBagSlot(bag, slot)
    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)
    local _, itemLink = scanTooltip:GetItem()
    if itemLink then
        local _, _, itemIDString = string.find(itemLink, "item:(%d+):")
        local itemID = tonumber(itemIDString)
        return itemID
    end
    return nil
end

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    Log("clicked bags button: " .. button)
    if not Container:IsVisible() then
        Log("frame not visible, exiting")
        return
    end
    if button ~= "LeftButton" then
        Log("not left button, exiting")
	    return
	end
    local bag = self:GetParent():GetID()
    local slot = self:GetID()
    local itemID = GetItemIDFromBagSlot(bag, slot)
    Log("item id " .. tostring(itemID))
    if itemID then
        UpdateItemDisplay(itemID)
    end
end)


SLASH_FKP1 = "/fkp"

SlashCmdList["FKP"] = function(msg)
    if Container:IsVisible() then
        Container:Hide()
    else
        Container:Show()
    end
    Log('slash command triggered')
end

Container:Hide()