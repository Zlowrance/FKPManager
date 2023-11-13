DEBUG=true

CHAT_TYPE = "CHAT_MSG_SAY" -- "CHAT_MSG_RAID"

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
    SendChatMessage(message, "SAY")
end