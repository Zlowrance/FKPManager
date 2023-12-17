-- Author      : zachl
-- Create Date : 11/14/2023 2:58:00 PM

FKPManagerData = {DataTimestamp = 0, FKPSpent = {}, PastBids = {}}

local DATA_UPDATED_KEY = "DATALASTUPDATED"

FKPHelper = {}

function FKPHelper:GetFKP(playerName)
    local fkp = FKPData[playerName] or 0
    local fkpSpent = FKPManagerData.FKPSpent[playerName] or 0
    return fkp - fkpSpent
end

function FKPHelper:SpendFKP(playerName, fkp)
    local currentSpent = FKPManagerData.FKPSpent[playerName] or 0
    FKPManagerData.FKPSpent[playerName] = currentSpent + fkp
end

function FKPHelper:ClearSpentFKP()
    FKPManagerData.FKPSpent = {}
end

function FKPHelper:AddPastBid(itemID, rolls)
    if FKPManagerData.PastBids == nil then
        FKPManagerData.PastBids = {}
    end
    table.insert(FKPManagerData.PastBids, {itemID = itemID, rolls = rolls})
end 

function FKPHelper:ClearPastBids()
    FKPManagerData.PastBids = {}
end

function FKPHelper:GetPastBids()
    return FKPManagerData.PastBids or {}
end


function FKPHelper:SerializeAndChunk()
    local serialized = DATA_UPDATED_KEY .. ":" .. FKPDataLastUpdated .. ";"
    for key, value in pairs(FKPData) do
        serialized = serialized .. key .. ":" .. value .. ";"
    end

    -- 255 - 10 chunk size for header and safety
    local chunkSize = 245
    local chunks = {}
    local part = 1
    local total = math.ceil(#serialized / chunkSize)

    for i = 1, #serialized, chunkSize do
        local chunk = part .. "/" .. total .. ":" .. string.sub(serialized, i, i + chunkSize - 1)
        table.insert(chunks, chunk)
        part = part + 1
    end

    return chunks
end

function FKPHelper:Deserialize(serializedString)
    local newData = {}
    local timestamp = 0

    for key, value in string.gmatch(serializedString, "(%w+):(-?%d+);") do
        if key == DATA_UPDATED_KEY then
            timestamp = tonumber(value)
        else
            newData[key] = tonumber(value)
        end
    end

    return {FKPData = newData, DataTimestamp = timestamp}
end