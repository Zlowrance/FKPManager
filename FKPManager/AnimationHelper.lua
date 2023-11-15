-- Author      : zachl
-- Create Date : 11/14/2023 4:09:23 PM

AnimationHelper = {}
AnimationDirection = {
    UP = "UP",
    DOWN = "DOWN",
    LEFT = "LEFT",
    RIGHT = "RIGHT"
}

function AnimationHelper:FadeIn(frame, duration)
    local animGroup = frame:CreateAnimationGroup()

    local anim = animGroup:CreateAnimation("Alpha")
    anim:SetFromAlpha(0)
    anim:SetToAlpha(1)
    anim:SetDuration(duration)
    anim:SetSmoothing("OUT")

    return animGroup
end

function AnimationHelper:FadeOut(frame, duration)
    local animGroup = frame:CreateAnimationGroup()

    local anim = animGroup:CreateAnimation("Alpha")
    anim:SetFromAlpha(1)
    anim:SetToAlpha(0)
    anim:SetDuration(duration)
    anim:SetSmoothing("IN")

    return animGroup
end

function AnimationHelper:SlideIn(frame, duration, direction)
    local animGroup = frame:CreateAnimationGroup()
    local anim = animGroup:CreateAnimation("Translation")
    anim:SetDuration(duration)
    anim:SetSmoothing("OUT")

    -- Save the original position
    local origPoint, origRelativeTo, origRelPoint, origX, origY = frame:GetPoint()

    -- Determine the offset based on the direction
    local offsetX, offsetY = 0, 0
    local parent = frame:GetParent() or UIParent
    local parentWidth, parentHeight = parent:GetWidth(), parent:GetHeight()

    if direction == AnimationDirection.UP then
        offsetY = -parentHeight
    elseif direction == AnimationDirection.DOWN then
        offsetY = parentHeight
    elseif direction == AnimationDirection.LEFT then
        offsetX = parentWidth
    elseif direction == AnimationDirection.RIGHT then
        offsetX = -parentWidth
    end
    
    anim:SetOffset(-offsetX, -offsetY)

    -- Set the starting position
    frame:SetPoint(origPoint, origRelativeTo, origRelPoint, origX + offsetX, origY + offsetY)
    
    -- Reset position after animation
    animGroup:SetScript("OnFinished", function()
        frame:SetPoint(origPoint, origRelativeTo, origRelPoint, origX, origY)
    end)

    return animGroup
end

function AnimationHelper:SlideOut(frame, duration, direction)
    local animGroup = frame:CreateAnimationGroup()
    local anim = animGroup:CreateAnimation("Translation")

    anim:SetDuration(duration)
    anim:SetSmoothing("IN")

    local width, height = frame:GetWidth(), frame:GetHeight()
    local parent = frame:GetParent() or UIParent
    local parentWidth, parentHeight = parent:GetWidth(), parent:GetHeight()

    if direction == AnimationDirection.UP then
        anim:SetOffset(0, -parentHeight)
    elseif direction == AnimationDirection.DOWN then
        anim:SetOffset(0, parentHeight)
    elseif direction == AnimationDirection.LEFT then
        anim:SetOffset(parentWidth, 0)
    elseif direction == AnimationDirection.RIGHT then
        anim:SetOffset(-parentWidth, 0)
    end

    return animGroup
end
