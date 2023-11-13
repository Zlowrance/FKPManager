

local parentFrame = _G["Frame1"]

local function OnCloseButtonClicked(self, button, down)
    parentFrame:Hide()
end

local closeButton = _G["CloseButton"]
closeButton:SetScript("OnClick", OnCloseButtonClicked);

-- Assuming 'MyScrollFrame' is your scroll frame's name
local scrollFrame = _G["ScrollFrame1"]
-- The height of each button
local buttonHeight = 30

local contentParent = CreateFrame("Frame")
scrollFrame:SetScrollChild(contentParent)
contentParent:SetWidth(scrollFrame:GetWidth())
contentParent:SetHeight(1)

-- Create and set up 20 buttons
for i = 1, 20 do
    local button = CreateFrame("Button", "MyButton" .. i, contentParent, "UIPanelButtonTemplate")
    button:SetSize(100, buttonHeight) -- Set the size of the button
    button:SetPoint("TOP", 0, -buttonHeight * (i - 1)) -- Position the button

    button:SetText("Button " .. i) -- Set button text

    -- Set up an OnClick script for the button
    button:SetScript("OnClick", function()
        Log("Button " .. i .. " clicked!")
    end)
end

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