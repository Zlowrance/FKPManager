

local parentFrame = _G["Frame1"]
local bids = {}

parentFrame:RegisterEvent(CHAT_TYPE)

-- setup scroller content
local scrollFrame = _G["ScrollFrame1"]

local contentParent = CreateFrame("Frame")
local scrollWidth = scrollFrame:GetWidth()
scrollFrame:SetScrollChild(contentParent)
contentParent:SetWidth(scrollWidth)
contentParent:SetHeight(1)

local function InitBidderList() 
    local buttonHeight = 30
    local index = 0
    for name, _ in pairs(bids) do
        local button = CreateFrame("Button", name, contentParent, "UIPanelButtonTemplate")
        button:SetSize(scrollWidth - 5, buttonHeight) -- Set the size of the button
        button:SetPoint("TOP", 0, -buttonHeight * (index)) -- Position the button

        local topEnd = 100 - (math.min(index,5) * 10)

        button:SetText(name .. " | Roll 1 - " .. topEnd) -- Set button text

        -- Set up an OnClick script for the button
        button:SetScript("OnClick", function()
            Log("Rolled " .. math.random(1,topEnd))
        end)
        index = index + 1
    end
end

parentFrame:SetScript("OnEvent", function(self, event, ...)
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

local function OnCloseButtonClicked(self, button, down)
    parentFrame:Hide()
end

local closeButton = _G["CloseButton"]
closeButton:SetScript("OnClick", OnCloseButtonClicked);

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
    if not parentFrame:IsVisible() then
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
    if parentFrame:IsVisible() then
        parentFrame:Hide()
    else
        parentFrame:Show()
    end
    Log('slash command triggered')
end

parentFrame:Hide()