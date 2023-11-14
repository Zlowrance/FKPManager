-- Author      : zachl
-- Create Date : 11/14/2023 2:58:00 PM

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