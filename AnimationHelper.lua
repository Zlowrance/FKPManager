-- Author      : zachl
-- Create Date : 11/14/2023 4:09:23 PM

local LibEasing = LibStub("LibEasing-1.0");

AnimationHelper = {}
AnimationDirection = {
    UP = "UP",
    DOWN = "DOWN",
    LEFT = "LEFT",
    RIGHT = "RIGHT"
}

function AnimationHelper:Cancel(handle)
    LibEasing:StopEasing(handle)
end

local function SetFrameALpha(frame, alpha)
    frame:SetAlpha(alpha)
end

local function SetFramePosition(frame, x, y)
    frame:SetPoint("CENTER", parent, "BOTTOMLEFT", x, y)
end

function AnimationHelper:FadeIn(frame, duration)
    return LibEasing:Ease(function(progress)
        frame:SetAlpha(progress)
    end, 0, 1, duration, LibEasing.InOutQuad)
end

function AnimationHelper:FadeOut(frame, duration)
    return LibEasing:Ease(function(progress)
        frame:SetAlpha(progress)
    end, 1, 0, duration, LibEasing.InOutQuad)
end

function AnimationHelper:MoveBy(frame, duration, x, y, easing, onComplete)
    local startX, startY = frame:GetCenter()
    return AnimationHelper:MoveTo(frame, duration, startX + x, startY + y, easing, onComplete)
end

function AnimationHelper:MoveTo(frame, duration, x, y, easing, onComplete)
    local startX, startY = frame:GetCenter()
    local endX, endY = x, y
    frame:ClearAllPoints()

    if easing == nil then
        easing = LibEasing.InOutQuad
    end

    return LibEasing:Ease(function(progress)
        local newX = startX + (endX - startX) * progress
        local newY = startY + (endY - startY) * progress
        SetFramePosition(frame, newX, newY)
    end, 0, 1, duration, easing, onComplete)
end

function AnimationHelper:SlideIn(frame, duration, direction, easing, onComplete)
    local parent = frame:GetParent() or UIParent
    local parentWidth, parentHeight = parent:GetWidth(), parent:GetHeight()
    local endX, endY = frame:GetCenter()
    local startX, startY = endX, endY

    if direction == AnimationDirection.UP then
        startY = startY - parentHeight
    elseif direction == AnimationDirection.DOWN then
        startY = startY + parentHeight
    elseif direction == AnimationDirection.LEFT then
        startX = startX + parentWidth
    elseif direction == AnimationDirection.RIGHT then
        startX = startX - parentWidth
    end
    frame:ClearAllPoints()
    
    SetFramePosition(frame, startX, startY)
    
    return AnimationHelper:MoveTo(frame, duration, endX, endY, easing, onComplete)
end

function AnimationHelper:SlideOut(frame, duration, direction, easing, onComplete)
    local parent = frame:GetParent() or UIParent
    local parentWidth, parentHeight = parent:GetWidth(), parent:GetHeight()
    local endX, endY = frame:GetCenter()
    
    if direction == AnimationDirection.UP then
        endY = endY + parentHeight
    elseif direction == AnimationDirection.DOWN then
        endY = endY - parentHeight
    elseif direction == AnimationDirection.LEFT then
        endX = endX - parentWidth
    elseif direction == AnimationDirection.RIGHT then
        endX = endX + parentWidth
    end
    
    return AnimationHelper:MoveTo(frame, duration, endX, endY, easing, onComplete)
end

function AnimationHelper:PunchScale(frame, punchAmount, duration, onComplete)
    local startScale = 1.0  -- Starting scale
    local maxScale = punchAmount    -- Maximum scale
    local midDuration = duration / 2  -- Duration to reach max scale

    -- First part: scale up to maxScale
    LibEasing:Ease(function(progress)
        local currentScale = LibEasing.OutQuad(progress, startScale, maxScale - startScale, 1)
        frame:SetScale(currentScale)
    end, 0, 1, midDuration, LibEasing.Linear, function()
        -- Second part: scale back down to startScale
        LibEasing:Ease(function(progress)
            local currentScale = LibEasing.InQuad(progress, maxScale, startScale - maxScale, 1)
            frame:SetScale(currentScale)
        end, 0, 1, midDuration, LibEasing.Linear, onComplete)
    end)
end
