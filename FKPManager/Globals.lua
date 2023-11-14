DEBUG=true

CHAT_TYPE_RAID = "SAY" -- RAID
CHAT_EVENT_TYPE = "CHAT_MSG_".. BASE_CHAT_TYPE

function GetCharacterName(fullName)
    -- Find the position of the hyphen
    local hyphenPos = string.find(fullName, "-")
    if hyphenPos then
        -- Extract and return the character name part
        return string.sub(fullName, 1, hyphenPos - 1)
    else
        -- If there's no hyphen, return the full name
        return fullName
    end
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
    for _, child in ipairs({parentFrame:GetChildren()}) do
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
