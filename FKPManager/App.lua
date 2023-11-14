-- Author      : zachl
-- Create Date : 11/14/2023 11:42:58 AM

-- SLASH COMMANDS

SLASH_FKP1 = "/fkp"

SlashCmdList["FKP"] = function(msg)
    if FKPDialog:IsVisible() then
        FKPDialog:Hide()
    else
        FKPDialog:Show()
    end
end

-- create hidden frame to get event callbacks
local eventFrame = CreateFrame("Frame", nil, UIParent)
eventFrame:Hide()  

eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if FKPManagerData == nil then
		    FKPManagerData = {DataTimestamp = 0, FKPSpent = {}}
		end
        
        if FKPManagerData.DataTimestamp < FKPDataLastUpdated then
            FKPManagerData.DataTimestamp = FKPDataLastUpdated
            FKPManagerData.FKPSpent = {}
            Log("Data updated, cleared cache")
        end
     
        self:UnregisterEvent("ADDON_LOADED")  
        Log("FKPManager loaded: ")
        Log(DumpTable(FKPManagerData))
    end
end)