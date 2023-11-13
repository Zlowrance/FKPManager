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