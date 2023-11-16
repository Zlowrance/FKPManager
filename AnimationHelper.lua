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

function AnimationHelper:SlideIn(frame, duration, direction, easing, onComplete)
    local parentWidth, parentHeight = UIParent:GetWidth(), UIParent:GetHeight()
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
    
    local function SetFramePosition(x, y)
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end
    
    SetFramePosition(startX, startY)

    if easing == nil then
        easing = LibEasing.OutQuad
    end
    
    return LibEasing:Ease(function(progress)
        local newX = easing(progress, startX, endX - startX, 1)
        local newY = easing(progress, startY, endY - startY, 1)
        SetFramePosition(newX, newY)
    end, 0, 1, duration, LibEasing.Linear, onComplete)
end

function AnimationHelper:SlideOut(frame, duration, direction, easing, onComplete)
    local parentWidth, parentHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local startX, startY = frame:GetCenter()
    local endX, endY = startX, startY

    if direction == AnimationDirection.UP then
        endY = endY + parentHeight
    elseif direction == AnimationDirection.DOWN then
        endY = endY - parentHeight
    elseif direction == AnimationDirection.LEFT then
        endX = endX - parentWidth
    elseif direction == AnimationDirection.RIGHT then
        endX = endX + parentWidth
    end
    frame:ClearAllPoints()
    
    local function SetFramePosition(x, y)
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end

    if easing == nil then
        easing = LibEasing.InQuad
    end
    
    return LibEasing:Ease(function(progress)
        local newX = easing(progress, startX, endX - startX, 1)
        local newY = easing(progress, startY, endY - startY, 1)
        SetFramePosition(newX, newY)
    end, 0, 1, duration, LibEasing.Linear, onComplete)
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
