DEBUG=false

BID_MSG = "bid"
CHAT_TYPE_RAID = "RAID"
CHAT_EVENT_TYPES = {"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER"} -- , "CHAT_MSG_SAY"
ADDON_NAME = "FKPManager"
FKP_ITEM_COST = 10

function ToUnqualifiedCharacterName(fullName)
    -- Find the position of the hyphen
    local hyphenPos = string.find(fullName, "-")
    if hyphenPos then
        -- Extract and return the character name part
        return string.sub(fullName, 1, hyphenPos - 1)
    end
    -- If there's no hyphen, return the full name
    return fullName
end

function SendToPlayer(message, playerName)
    -- message: The whisper message you want to send
    -- playerName: The recipient's character name
    SendChatMessage(message, "WHISPER", nil, playerName)
end

function SendToRaid(message)
    -- message: The message you want to send to raid
    SendChatMessage(message, CHAT_TYPE_RAID)
end

function ClearFrame(parentFrame)
    local children = {parentFrame:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
end

function ShowError(message)
    UIErrorsFrame:AddMessage(message, 1.0, 0.1, 0.1, 1.0)
end

function GetChildOfFrame(parentFrame, childName)
    -- Log("searching " .. parentFrame:GetName() .. " for " .. childName)
    for _, child in ipairs({parentFrame:GetChildren()}) do
        -- Log(">> " .. child:GetName())
        if child:GetName() == childName then
            return child
        end
    end

    for _, child in ipairs({parentFrame:GetRegions()}) do
        -- Log(">> " .. child:GetName())
        if child:GetName() == childName then
            return child
        end
    end
    return nil
end

function GetRaidMemberUnitIDFromName(name)
    for i = 1, 40 do
        if UnitName("raid" .. i) == name then
            return "raid" .. i
        end
    end
    return nil
end

function DumpTable(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. DumpTable(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end