RunConsoleCommand("mp_show_voice_icons", "0")

if engine.ActiveGamemode() == "zcity" then return end

local function ClearVoicePanels()
    if IsValid(g_VoicePanelList) then
        g_VoicePanelList:Clear()
        g_VoicePanelList:SetVisible(false)
    end
end

hook.Add("PlayerStartVoice", "niceigraem.HideVoicePanels", function(ply)
    ClearVoicePanels()
    return true
end)

hook.Add("PlayerEndVoice", "niceigraem.HideVoicePanels", function(ply)
    return true
end)

hook.Add("InitPostEntity", "niceigraem.HideVoicePanels.Init", ClearVoicePanels)