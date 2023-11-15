-- LOCAL VARS
local States = {
    IDLE = "IDLE",
    ITEM_SELECTED = "ITEM_SELECTED",
    BIDDING_STARTED = "BIDDING_STARTED",
    BIDDING_ENDED = "BIDDING_ENDED"
}

local Events = {
    BID_BUTTON_PRESS = "BID_BUTTON_PRESS",
    CHAT_MSG_RECEIVED = "CHAT_MSG_RECEIVED",
    SYSTEM_MSG_RECEIVED = "SYSTEM_MSG_RECEIVED",
    ITEM_AREA_CLICKED = "ITEM_AREA_CLICKED"
}

local fsm = nil
local players = {}
local currentItem = {}
local unusedFrames = {}
local FKPFrameHeight = 60
local FKPFrameSpacing = 5
local initialized = false

-- INITIALIZATION
FKPDialog:SetMovable(true)
FKPDialog:EnableMouse(true)
FKPDialog:RegisterForDrag("LeftButton")

local contentParent = CreateFrame("Frame")
local scrollWidth = ScrollFrame1:GetWidth()
ScrollFrame1:SetScrollChild(contentParent)
contentParent:SetWidth(scrollWidth)
contentParent:SetHeight(1)

BiddingButton:Disable()

local dropTargetFrame = CreateFrame("Frame", "ItemDropTargetFrame", FKPDialog)
dropTargetFrame:SetSize(100, 100) 
dropTargetFrame:SetPoint("TOPLEFT", ItemIcon, "TOPLEFT")
dropTargetFrame:SetPoint("BOTTOMRIGHT", ItemIcon, "BOTTOMRIGHT")
FKPDialog:EnableMouse(true)
FKPDialog:RegisterForDrag("LeftButton")

-- LOCAL FUNCTIONS

local function GetPlayerIndex(playerName)
    for i = 1, #players do
        if players[i].name == playerName then
		    return i
		end
	end
    return nil
end

local function GetPlayerData(playerName)
    local index = GetPlayerIndex(playerName)
    if index == nil then
	    return nil
	end
    return players[index]
end

local function GetFKPListFrame()
	if #unusedFrames > 0 then
        -- Reuse existing button
        button = table.remove(unusedFrames, 1)
    else
        -- Create new button
        button = CreateFrame("Frame", "FKPFrame", contentParent, "FKPListTemplate")
        button:SetSize(scrollWidth - 5, FKPFrameHeight)
    end
    button:Show()
	return button
end

local function ReleaseFKPListFrame(frame)
    if frame == nil then
	    return
	end
    frame:Hide()
    table.insert(unusedFrames, frame)
end

local function GetTopEndRoll(index)
     return 100 - (math.min(index,5) * 10)
end

local function UpdateItemDisplay(itemId)
    Log("displaying item " .. itemId)
    local _, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
    if not itemLink or not itemIcon then
        return
    end
    ItemIcon:SetTexture(itemIcon)
    ItemName:SetText(itemLink)
    currentItem = { id = itemId, link = itemLink }
end

local function ClearItemDisplay()
    ItemIcon:SetTexture(nil)
    ItemName:SetText("")
    currentItem = nil
end

local function AddBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
    if GetPlayerIndex(playerName) ~= nil then
        return
    end
    table.insert(players, {name = playerName, fkp = FKPHelper:GetFKP(playerName), roll = 0, frame = nil})
    Log(playerName .. " added to the bid list.")
end

local function RemoveBid(playerName)
    playerName = ToUnqualifiedCharacterName(playerName)
	local playerIndex = GetPlayerIndex(playerName)
    if playerIndex == nil then
        return
    end
    local player = players[playerIndex]
    if player.frame ~= nil then
        ReleaseFKPListFrame(player.frame)
        player.frame = nil
	end
    table.remove(players, playerIndex)
    Log(playerName .. " removed from the bid list.")
end

local function LayoutBidderList()
    for i, player in ipairs(players) do
        local button = player.frame
        local playerName = GetChildOfFrame(button, "Name")
        local playerIndex = GetPlayerIndex(playerName:GetText())
        local yOffset = -button:GetHeight() * (playerIndex - 1) - FKPFrameSpacing * (playerIndex)
        button:SetPoint("TOP", contentParent, "TOP", 0, yOffset)
	end
end

local function InitBidderList()
    -- Sort players by fkp
    table.sort(players, function(a, b) return a.fkp > b.fkp end)

    for index, player in ipairs(players) do
        local button = player.frame or GetFKPListFrame()
        player.frame = button

        local playerPortrait = GetChildOfFrame(button, "Portrait")
        local playerName = GetChildOfFrame(button, "Name")
        local playerFKP = GetChildOfFrame(button, "FKP")
        local playerRoll = GetChildOfFrame(button, "Roll")
        local removeButton = GetChildOfFrame(button, "RemoveButton")
        local winnerButton = GetChildOfFrame(button, "WinnerButton")

        removeButton:Show()
        winnerButton:Hide()

        local topEnd = GetTopEndRoll(index - 1)
        playerName:SetText(player.name)
        playerFKP:SetText(player.fkp .. " FKP")
        playerRoll:SetText("rolls 1-" .. topEnd)

        local unitID = GetRaidMemberUnitIDFromName(player.name)
        if unitID then
            SetPortraitTexture(playerPortrait, unitID)
        else
            playerPortrait:SetTexture(nil)
        end

        removeButton:SetScript("OnClick", function(self, button, down)
            RemoveBid(player.name)
            InitBidderList()
        end)
    end

    LayoutBidderList()
end

local function SubscribeToChat()
    for i = 1, #CHAT_EVENT_TYPES do
         FKPDialog:RegisterEvent(CHAT_EVENT_TYPES[i])
	end
    FKPDialog:RegisterEvent("CHAT_MSG_SYSTEM")
end

local function UnsubscribeToChat()
    for i = 1, #CHAT_EVENT_TYPES do
         FKPDialog:UnregisterEvent(CHAT_EVENT_TYPES[i])
	end
    FKPDialog:UnregisterEvent("CHAT_MSG_SYSTEM")
end

local function SetPlayerRoll(playerName, roll, topEnd)
    local playerIndex = GetPlayerIndex(playerName)
    if playerIndex == nil then
	    Log(playerName .. " tried to roll but they aren't in the list")
	    return
	end
    local player = GetPlayerData(playerName)
    if player.roll > 0 then
        Log(playerName .. " tried to roll again")
	    return
	end
    local targetTopEnd = GetTopEndRoll(playerIndex - 1)

    if topEnd ~= targetTopEnd then  
		SendToRaid(playerName .. " ROLLED OUT OF " .. topEnd .. " INSTEAD OF " .. targetTopEnd .. "!! SHAME!!")
        return
	end

    player.roll = roll

    local playerRoll = GetChildOfFrame(player.frame, "Roll")

    playerRoll:SetText("Rolled " .. roll)

    table.sort(players, function(a, b) return a.roll > b.roll end)
    LayoutBidderList()
end

-- STATE FUNCS

local function IDLE_Enter(fsm)
    SubscribeToChat()
    ClearItemDisplay()
    ClearItemButton:Hide()
    BiddingButton:Disable()
    Instructions:Show()
    BiddingButtonText:SetText("Start Bidding")
    players = {}
    InitBidderList()
end

local function IDLE_ITEM_AREA_CLICKED(fsm, button)
    if button ~= "LeftButton" then
        return
    end
    
    local cursorType, itemId, link = GetCursorInfo()
    if itemId == nil then
		return
	end
    Log(cursorType .. itemId .. link)
    if cursorType == "item" then
        UpdateItemDisplay(itemId)
        fsm:setState(States.ITEM_SELECTED)
        ClearCursor() 
    end
end

local function ITEM_SELECTED_Enter(fsm)
    ClearItemButton:Show()
    BiddingButton:Enable()
    Instructions:Hide()
end

local function ITEM_SELECTED_BID_BUTTON_PRESS(fsm)
     fsm:setState(States.BIDDING_STARTED)
end

local function BIDDING_STARTED_Enter(fsm)
    ClearItemButton:Hide()
    SendToRaid("BIDDING START: " .. currentItem.link)
    SendToRaid("TO BID SAY: " .. BID_MSG)
    BiddingButtonText:SetText("End Bidding")
end

local function BIDDING_STARTED_BID_BUTTON_PRESS(fsm)
    fsm:setState(States.BIDDING_ENDED)
end

local function BIDDING_STARTED_CHAT_MSG_RECEIVED(fsm, message, playerName)
    if not string.match(message, "^" .. BID_MSG .. "$") then
        -- Debug feature for test bids
        if DEBUG and string.match(message, "testbid (%a+)") then
            AddBid(string.match(message, "testbid (%a+)"))
            InitBidderList()
        end
        return
    end
    AddBid(playerName)
    InitBidderList()
end

local function BIDDING_ENDED_Enter(fsm)
    if #players == 0 then
		fsm:setState(States.IDLE)
		return
	end

    -- Send status to chat and players
    SendToRaid("ROLL FOR " .. currentItem.link)
    SendToRaid("======================")

    -- separate these so players get their whisper after the raid dump
	local index = 0
    for _, player in ipairs(players) do
        local topEnd = GetTopEndRoll(index)
        SendToRaid("1-" .. topEnd .. "  " .. player.name)
        index = index + 1
    end

    index = 0
    for _, player in ipairs(players) do
        local topEnd = GetTopEndRoll(index)
        SendToPlayer("roll 1-" .. topEnd, player.name)
        index = index + 1
    end
    SendToRaid("======================")

    BiddingButton:Disable()
    ItemName:SetText("vv Select Winner vv")

    -- flip all entries from remove to pick winner button
    for i, player in ipairs(players) do
        local removeButton = GetChildOfFrame(player.frame, "RemoveButton")
        local winnerButton = GetChildOfFrame(player.frame, "WinnerButton")
        local playerRoll = GetChildOfFrame(player.frame, "Roll")

        playerRoll:SetText("Awaiting Roll...")

        removeButton:Hide()
        winnerButton:Show()

        winnerButton:SetScript("OnClick", function(self, button, down)
            FKPHelper:SpendFKP(player.name, FKP_ITEM_COST)
            for _, player in ipairs(players) do
                ReleaseFKPListFrame(player.frame)
			end
            SendToRaid(player.name .. " wins " .. currentItem.link .. "!!")
            fsm:setState(States.IDLE)
        end)
	end
end

local function BIDDING_ENDED_SYSTEM_MSG_RECEIVED(fsm, message)
    local player, roll, minRoll, maxRoll = string.match(message, "(.+) rolls (%d+) %((%d+)-(%d+)%)")
    if player and roll and minRoll and maxRoll then
        SetPlayerRoll(player, tonumber(roll), tonumber(maxRoll))
    end
end

-- FRAME EVENT HANDLERS

ClearItemButton:SetScript("OnClick", function(self, button, down)
    fsm:setState(States.IDLE)
end)

BiddingButton:SetScript("OnClick", function(self, button, down)
   fsm:handleEvent(Events.BID_BUTTON_PRESS)
end)

FKPDialog:SetScript("OnEvent", function(self, event, message, playerName)
    if event == "CHAT_MSG_SYSTEM" then
        fsm:handleEvent(Events.SYSTEM_MSG_RECEIVED, message)
        return
    end

    local shouldHandle = false

    for index, value in ipairs(CHAT_EVENT_TYPES) do
        if value == event then
            shouldHandle = true
            break
        end
    end

    if not shouldHandle then
        return
    end

    fsm:handleEvent(Events.CHAT_MSG_RECEIVED, message, playerName)
end)

FKPDialog:SetScript("OnShow", function(self)
    if initialized then
        return
    end
    fsm:setState(States.IDLE)
    initialized = true
end)

FKPDialog:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)

FKPDialog:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
end)

dropTargetFrame:SetScript("OnMouseDown", function(self, button)
    fsm:handleEvent(Events.ITEM_AREA_CLICKED, button)
end)

dropTargetFrame:SetScript("OnEnter", function(self)
    if currentItem == nil then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(currentItem.id)
    GameTooltip:Show()
end)

dropTargetFrame:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- FSM SETUP

local states = {
    [States.IDLE] = {
        enter = IDLE_Enter,
        events = {
            [Events.ITEM_AREA_CLICKED] = IDLE_ITEM_AREA_CLICKED
        }
    },
    [States.ITEM_SELECTED] = {
        enter = ITEM_SELECTED_Enter,
        events = {
			[Events.BID_BUTTON_PRESS] = ITEM_SELECTED_BID_BUTTON_PRESS
		}
    },
    [States.BIDDING_STARTED] = {
        enter = BIDDING_STARTED_Enter,
		events = {
			[Events.BID_BUTTON_PRESS] = BIDDING_STARTED_BID_BUTTON_PRESS,
            [Events.CHAT_MSG_RECEIVED] = BIDDING_STARTED_CHAT_MSG_RECEIVED
		}
    },
    [States.BIDDING_ENDED] = {
        enter = BIDDING_ENDED_Enter,
        events = {
			[Events.SYSTEM_MSG_RECEIVED] = BIDDING_ENDED_SYSTEM_MSG_RECEIVED
		}
    },
}
fsm = FSM:new(states)