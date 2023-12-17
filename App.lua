-- Author      : zachl
-- Create Date : 11/14/2023 11:42:58 AM

local MSG_PREFIX = "FKPManager"
local receivedChunks = {}
local expectedTotal = nil

-- SLASH COMMANDS

SLASH_FKP1 = "/fkp"

SlashCmdList["FKP"] = function(msg)
    if FKPDialog:IsVisible() then
        FKPDialog:Hide()
    else
        FKPDialog:Show()
    end
end

-- create hidden frame to get event callbacks
local eventFrame = CreateFrame("Frame", nil, UIParent)
eventFrame:Hide()  

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

local function SendChunksToGuild(chunks)
    for _, chunk in ipairs(chunks) do
        C_ChatInfo.SendAddonMessage(MSG_PREFIX, chunk, ADDON_MSG_CHANNEL, nil)
    end
end

local function OnLoaded()
    if FKPManagerData == nil then
        FKPManagerData = {DataTimestamp = 0, FKPSpent = {}, PastBids = {}}
    end

    if FKPManagerData.DataTimestamp < FKPDataLastUpdated then
        FKPManagerData.DataTimestamp = FKPDataLastUpdated
        FKPManagerData.FKPSpent = {}
        Log("Data updated, cleared cache. Sending updated data to guild.")
        local chunks = FKPHelper:SerializeAndChunk()
        SendChunksToGuild(chunks)
    end

    C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)

    Log("FKPManager loaded: ")
    Log(DumpTable(FKPManagerData))
end

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= MSG_PREFIX then
        return
    end
    
    if DEBUG then
        Log("Received addon message: " .. message)
    end
    
    local part, total, chunk = string.match(message, "(%d+)/(%d+):(.*)")
    part, total = tonumber(part), tonumber(total)

    -- Initialize when first chunk is received
    if part == 1 then
        receivedChunks = {}
        expectedTotal = total
    end

    -- Ignore if total doesn't match expected
    if total ~= expectedTotal then 
        return 
    end

    -- Store the chunk
    receivedChunks[part] = chunk

    -- Check if all chunks are received
    if #receivedChunks < total then
        return
    end

    local fullMessage = table.concat(receivedChunks)
    local deserialized = FKPHelper:Deserialize(fullMessage)
    if not deserialized then
        Log("Failed to deserialize message")
        return
    end
    if deserialized.DataTimestamp <= FKPManagerData.DataTimestamp then
        Log("Received data is older than current data. New timestamp: " .. deserialized.DataTimestamp .. ", current timestamp: " .. FKPManagerData.DataTimestamp)
        return
    end
    Log("Received new data")
    -- for each player in the new data, apply an FKP delta to local storage for the difference between the new and old FKP
    FKPManagerData.FKPSpent = {}
    FKPManagerData.DataTimestamp = deserialized.DataTimestamp
    for playerName, fkp in pairs(deserialized.FKPData) do
        local oldFKP = FKPHelper:GetFKP(playerName)
        local delta = fkp - oldFKP
        FKPManagerData.FKPSpent[playerName] = -delta
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            OnLoaded()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        OnAddonMessage(prefix, message, channel, sender)
    end
end)