hg.settings = hg.settings or {}
hg.settings.tbl = hg.settings.tbl or {}

function hg.settings:AddOpt( strCategory, strConVar, strTitle, bDecimals, bString, category )
    self.tbl[strCategory] = self.tbl[strCategory] or {}
    self.tbl[strCategory][strConVar] = { strCategory, strConVar, strTitle, bDecimals or false, bString or false, category }
end

local hg_firstperson_death = CreateClientConVar("hg_firstperson_death", "0", true, false, "Toggle first-person death camera view", 0, 1)
local hg_font = CreateClientConVar("hg_font", "Bahnschrift", true, false, "change every text font to selected because ui customization is cool")
local hg_attachment_draw_distance = CreateClientConVar("hg_attachment_draw_distance", 0, true, nil, "distance to draw attachments", 0, 4096)
local hg_holster_style = CreateClientConVar("hg_holster_style", "0", true, true, "Holster weapon on chest instead of back", 0, 1)
local hg_ui_sticker = CreateClientConVar("hg_ui_sticker", "0", true, false, "Show Yuuri in settings menu", 0, 1)

xbars = 17
ybars = 30

gradient_l = Material("vgui/gradient-l")

local blur = Material("pp/blurscreen")
local blur2 = Material("effects/shaders/zb_blur" )
local sw, sh = ScrW(), ScrH()

local font = function() -- hg_coolvetica:GetBool() and "Coolvetica" or "Bahnschrift"
    local usefont = "Bahnschrift"

    if hg_font:GetString() != "" then
        usefont = hg_font:GetString()
    end

    return usefont
end

surface.CreateFont("ZCity_setiings_tiny", {
	font = font(),
	size = ScreenScale(7),
	weight = 100
})

surface.CreateFont("ZCity_setiings_fine", {
	font = font(),
	size = ScreenScale(10),
	weight = 100
})

surface.CreateFont("ZCity_setiings_category", {
	font = font(),
	size = ScreenScale(15),
	weight = 100
})

hg.settings:AddOpt("Gameplay","hg_old_notificate", "Old Notifications")
hg.settings:AddOpt("Gameplay","hg_cheats", "Enable Cheats")
hg.settings:AddOpt("Gameplay","hg_showthoughts", "Show thoughts")
hg.settings:AddOpt("Gameplay","hg_hints", "Show hints")
hg.settings:AddOpt("Gameplay","hg_gary", "Center weapon in fake")
hg.settings:AddOpt("Gameplay","hg_deathfadeout", "Death fade out")
--hg_gary
--hg_deathfadeout
if not game.IsDedicated() then
	hg.settings:AddOpt("Server-side settings","hg_toughnpcs", "Tough npcs")
	hg.settings:AddOpt("Server-side settings","hg_thirdperson", "Thirdperson (WIP)")
	hg.settings:AddOpt("Server-side settings","hg_legacycam", "Legacy camera")
	hg.settings:AddOpt("Server-side settings","hg_ragdollcombat", "Ragdoll combat mode")
	hg.settings:AddOpt("Server-side settings","hg_movement_stamina_debuff", "Movement stamina debuff")
	hg.settings:AddOpt("Server-side settings","hg_furcity", "Furcity")
	hg.settings:AddOpt("Server-side settings","hg_appearance_access_for_all", "Appearance full access for all", nil, nil, "bool")
	hg.settings:AddOpt("Server-side settings","hg_healanims", "Heal & food animations")
	hg.settings:AddOpt("Server-side settings","hg_slings", "Sling system")
	hg.settings:AddOpt("Server-side settings","hg_allow_gopro", "Allow GoPro-like first-person camera")
	hg.settings:AddOpt("Server-side settings","hg_allow_gopro_pos", "Allow editing GoPro camera position")
	hg.settings:AddOpt("Server-side settings","hg_giveammomul", "Multiply given ammo for weapon spawned from spawnmenu")
	hg.settings:AddOpt("Server-side settings","hg_ixanims", "Toggle Helix-like animations on NPC models for players. Experimental")
	hg.settings:AddOpt("Server-side settings","hg_coolhands", "Give cool hands instead of default hands on spawn")
    hg.settings:AddOpt("Server-side settings","homicide_traitoramount", "Homicide: Traitor Amount", nil, nil, "int")
	hg.settings:AddOpt("Server-side settings","hg_random_atts", "Give random atts")
end
--hg_appearance_access_for_all
--hg_furcity
--hg_legacycam
--hg_toughnpcs

hg.settings:AddOpt("Debug","hg_show_hitposmuzzle", "Show weapon hitpos")
hg.settings:AddOpt("Debug","hg_setzoompos", "Edit weapon zoompos, check console for results")
hg.settings:AddOpt("Debug","hg_show_hitbox", "Show hitboxes")

hg.settings:AddOpt("Optimization","hg_potatopc", "Potato PC Mode")
hg.settings:AddOpt("Optimization","hg_anims_draw_distance", "Animations Draw Distance", true, nil, "int")
hg.settings:AddOpt("Optimization","hg_anim_fps", "Animations FPS", nil, nil, "int")
hg.settings:AddOpt("Optimization","hg_attachment_draw_distance", "Attachment Draw Distance", true, nil, "int")
hg.settings:AddOpt("Optimization","hg_maxsmoketrails", "Maximum Smoke Trails", nil, nil, "int")
hg.settings:AddOpt("Optimization","hg_tpik_distance", "TPIK Render Distance", true, nil, "int")

hg.settings:AddOpt("Blood","hg_blood_draw_distance", "Blood Draw Distance")
hg.settings:AddOpt("Blood","hg_blood_fps", "Blood FPS")
hg.settings:AddOpt("Blood","hg_blood_sprites", "Blood Sprites (DISABLED FOR EVERYONE)")
hg.settings:AddOpt("Blood","hg_old_blood", "Old blood")

hg.settings:AddOpt("UI","hg_font", "Set Custom Font", false, true)
hg.settings:AddOpt("UI","hg_ui_sticker", "Yuuri")

hg.settings:AddOpt("Weapons","hg_weaponshotblur_enable", "Shooting Blur")
hg.settings:AddOpt("Weapons","hg_dynamic_mags", "Dynamic Ammo Inspect")
hg.settings:AddOpt("Weapons","hg_zoomsensitivity", "Scope sensitivity")
hg.settings:AddOpt("Weapons","hg_highpitchgunfire", "Toggle high pitched gunfire sounds inside buildings")
hg.settings:AddOpt("Weapons","hg_holster_style", "Chest Holster")

hg.settings:AddOpt("View","hg_firstperson_death", "First-Person Death")
hg.settings:AddOpt("View","hg_fov", "Field Of View")
hg.settings:AddOpt("View","hg_newspectate", "Smooth Spectator Camera")
hg.settings:AddOpt("View","hg_cshs_fake", "C'sHS Ragdoll Camera")
hg.settings:AddOpt("View","hg_gun_cam", "Gun Camera (ADMIN ONLY)")
hg.settings:AddOpt("View","hg_nofovzoom", "Disable/Enable FOV Zoom")
hg.settings:AddOpt("View","hg_realismcam", "Realism camera (shitty)")
hg.settings:AddOpt("View","hg_gopro", "GoPro camera")
hg.settings:AddOpt("View","hg_newfakecam", "New fake camera")
hg.settings:AddOpt("View","hg_leancam_mul", "Lean camera mul", true, nil, "int")
hg.settings:AddOpt("View","hg_gun_cam", "Gun camera (WIP Admin only)")
--hg_hints
--hg_leancam_mul
--hg_newfakecam

hg.settings:AddOpt("Sound","hg_dmusic", "Dynamic Music")
hg.settings:AddOpt("Sound","hg_quietshots", "Enable/Disable Quietshoot Sounds")

function hg.CreateCategory(ctgName, ParentPanel, yPos)
    local pppanel = vgui.Create('DPanel', ParentPanel)
    pppanel:SetSize(ParentPanel:GetWide() / 1.05, ParentPanel:GetTall() * 0.07)
    pppanel:SetPos(ParentPanel:GetWide() / 2 - pppanel:GetWide() / 2, yPos)
    --pppanel:SetText(ctgName)
    local clr_title = Color(220, 220, 220, 220)

    pppanel.Paint = function(self,w,h)
        surface.SetDrawColor(60,60,60,145)
        surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(42, 42, 42, 184)
		surface.DrawRect(0, h-5, w, 5)
    
        draw.SimpleText(ctgName, 'ZCity_setiings_category', w / 2, h / 2, clr_title, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    return pppanel
end

function hg.GetConVarType(convar)
    local stringv = convar:GetString()
    local floatVal = convar:GetFloat()
    local intVal = convar:GetInt()
    local boolVal = convar:GetBool()

    if (stringv == '0' and not boolVal) or (stringv == '1' and boolVal) then
        return 'bool'
    end

    if tonumber(stringv) and math.floor(stringv) == floatVal then
        if intVal == floatVal then
            return "int"
        end
    end

    return "string"
end

local function SetConVarValue(convar, value)
    if not convar then return end

    local name = convar.GetName and convar:GetName()
    if not name or name == "" then return end

    if isbool(value) then
        RunConsoleCommand(name, value and "1" or "0")
        return
    end

    RunConsoleCommand(name, tostring(value))
end

local clr_1 = Color(255,255,255,104)
local clr_2 = Color(122,122,122,104)
local clr_3 = Color(28,28,28)
local clr_4 = Color(0, 0, 0, 30)
local clr_5 = Color(30, 29, 29, 30)
local clr_6 = Color(255, 255, 255, 100)
local clr_7 = Color(255, 255, 255, 200)
local clr_8 = Color(70, 130, 180)

function hg.CreateButton(buttonData, convarName, ParentPanel, yPos)
    local convar = GetConVar(convarName)

    if not convar then 
        return 
    end
    local pppanel = vgui.Create('DPanel', ParentPanel)
    pppanel:SetSize(ParentPanel:GetWide()/1.05, math.max(ParentPanel:GetTall()/15, 38))
    pppanel:SetPos(ParentPanel:GetWide()/2-pppanel:GetWide()/2, yPos)
    
    surface.SetFont('ZCity_setiings_fine')
    local width2, height2 = surface.GetTextSize(buttonData[3])
    
    local convarType = buttonData[6] or hg.GetConVarType(convar)
    pppanel.Paint = function(self,w,h)
        surface.SetDrawColor(43, 43, 43,145)
        surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(47, 47, 47,145)
		surface.DrawRect(0, h-3, w, 3)
        
        draw.SimpleText(buttonData[3], 'ZCity_setiings_fine', 30, h / 2 - height2/2.5, clr_1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(convar:GetHelpText(), 'ZCity_setiings_tiny', 30, h / 2 + height2/2, clr_2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if convarType == 'bool' then
        local toggle = vgui.Create('DButton', pppanel)
        toggle:SetSize(pppanel:GetWide() / 18, pppanel:GetTall() / 2)
        toggle:SetPos(pppanel:GetWide() - toggle:GetWide()*1.4 - pppanel:GetWide() / 20, pppanel:GetTall() / 2 - toggle:GetTall() / 2)
        toggle:SetText('')
        
        local animProgress = convar:GetBool() and 1 or 0
        local targetProgress = animProgress
        
        function toggle:Paint(w, h)
            if animProgress ~= targetProgress then
                animProgress = Lerp(FrameTime() * 8, animProgress, targetProgress)
            end
            
            local bgColor = Color(
                Lerp(animProgress, 180, 80),  
                Lerp(animProgress, 30, 120),  
                Lerp(animProgress, 30, 50)   
            )
            
            local shadowColor = Color(0, 0, 0, Lerp(animProgress, 150, 40))
            surface.SetDrawColor(clr_3)
            draw.RoundedBox(0, 0, 0, w, h, clr_3)
            
            surface.SetDrawColor(clr_5)
            draw.RoundedBox(0, 2, 2, w - 4, h - 4, clr_4)
            
            local slsize = h - 12
            local slPos = Lerp(animProgress, 6, w - slsize - 6)
            surface.SetDrawColor(bgColor)
            draw.RoundedBox(0, slPos, 6, slsize, slsize, bgColor)
            surface.SetDrawColor(shadowColor)
            surface.DrawRect(slPos, slsize+4, slsize, 3)
        end
        
        function toggle:DoClick()
            if convar then
                local newValue = not convar:GetBool()
                SetConVarValue(convar, newValue)

                surface.PlaySound('glide/headlights_on.wav')
                targetProgress = newValue and 1 or 0
            end
        end
        
    elseif convarType == 'int' then
        local slider = vgui.Create('DNumSlider', pppanel)
        slider:SetSize(280, 30)
        slider:SetPos(pppanel:GetWide() - 300, pppanel:GetTall() / 2 - 15)
        slider:SetText('')
        
        local min = convar:GetMin() or 0
        local max = convar:GetMax() or 100
        local decimals = buttonData[4] and 2 or 0
        
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(decimals)
        slider:SetValue(decimals > 0 and convar:GetFloat() or convar:GetInt())
        
        function slider:OnValueChanged(val)
            if convar then
                SetConVarValue(convar, decimals > 0 and math.Round(val, decimals) or math.Round(val))
            end
        end
        
        local valueLabel = vgui.Create('DLabel', pppanel)
        valueLabel:SetPos(pppanel:GetWide() - 350, pppanel:GetTall() / 2 - 8)
        valueLabel:SetSize(50, 20)
        valueLabel:SetText(convar:GetInt())
        valueLabel:SetTextColor(clr_7)
        valueLabel:SetFont('ZCity_setiings_tiny')
        
        slider.Think = function()
            if convar then
                valueLabel:SetText(convar:GetInt())
            end
        end
        
    elseif convarType == 'string' then
        local textEntry = vgui.Create('DTextEntry', pppanel)
        textEntry:SetSize(pppanel:GetWide()/8, pppanel:GetTall()/2)
        textEntry:SetPos(pppanel:GetWide()-pppanel:GetWide()/8-20, pppanel:GetTall()/2-textEntry:GetTall()/2)
        textEntry:SetText(convar:GetString())
        textEntry:SetUpdateOnType(true) 
        textEntry:SetFont('ZCity_Tiny')
        
        textEntry.Paint = function(self, w, h)
            surface.SetDrawColor(30, 30, 30, 255)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(60, 60, 60, 255)
            surface.DrawOutlinedRect(0, 0, w, h)
            
            self:DrawTextEntryText(color_white, clr_8, color_white)
        end
        
        function textEntry:OnValueChange(val)
            if convar then
                SetConVarValue(convar, val)
            end
        end
    end
    
    return pppanel
end

local kartinko = Material("sticker/yuuri1.png", "smooth")

function hg.DrawSettings(ParentPanel)
    ParentPanel:SetAlpha(0)
    ParentPanel.Paint = function(self,w,h)
        surface.SetDrawColor(28,28,28,255)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(107, 107, 107,20)

        for i = 1, (ybars + 1) do
            surface.DrawRect((sw / ybars) * i - (CurTime() * 30 % (sw / ybars)), 0, ScreenScale(1), sh)
        end

        for i = 1, (xbars + 1) do
            surface.DrawRect(0, (sh / xbars) * (i - 1) + (CurTime() * 30 % (sh / xbars)), sw, ScreenScale(1))
        end

        local border_size = ScreenScale(2)

        surface.SetDrawColor(0, 0, 0)
        surface.SetMaterial(gradient_l)
        surface.DrawTexturedRect(0, 0, border_size, sh)
		surface.SetMaterial(blur)
        surface.SetDrawColor(28,28,28,208)
        surface.DrawRect(0, 0, w, h)
    end

    hg.DrawBlur(ParentPanel, 5)
    ParentPanel:AlphaTo(255, 0.15, 0)

    local tabOrder = {
        "Gameplay",
        "Weapons",
        "View",
        "Sound",
        "Optimization",
        "Blood",
        "UI",
        "Server-side settings",
        "Debug"
    }

    local categories = {}
    for _, name in ipairs(tabOrder) do
        if hg.settings.tbl[name] then
            table.insert(categories, name)
        end
    end
    for name, _ in pairs(hg.settings.tbl) do
        if not table.HasValue(categories, name) then
            table.insert(categories, name)
        end
    end

    local tabH = ScreenScale(18)
    local tabMargin = ScreenScale(8)

    local scroller = vgui.Create("DHorizontalScroller", ParentPanel)
    scroller:SetPos(tabMargin, tabMargin)
    scroller:SetSize(ParentPanel:GetWide() - tabMargin * 2, tabH)
    scroller:SetOverlap(-ScreenScale(3))

    if IsValid(scroller.btnLeft) then
        scroller.btnLeft.Paint = function(s, w, h)
            draw.SimpleText("<", "ZCity_setiings_fine", w/2, h/2, s:IsHovered() and Color(192,0,0) or clr_1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    if IsValid(scroller.btnRight) then
        scroller.btnRight.Paint = function(s, w, h)
            draw.SimpleText(">", "ZCity_setiings_fine", w/2, h/2, s:IsHovered() and Color(192,0,0) or clr_1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local contentY = tabMargin + tabH + ScreenScale(6)
    local contentPanel = vgui.Create("DScrollPanel", ParentPanel)
    contentPanel:SetPos(0, contentY)
    contentPanel:SetSize(ParentPanel:GetWide(), ParentPanel:GetTall() - contentY - tabMargin)
    --pppanel3:SetAlpha(0)
    contentPanel.Paint = function() end
    -- 🥴 <- лучший смайлик

    local initialTab = (hg.settings.LastTab and table.HasValue(categories, hg.settings.LastTab)) and hg.settings.LastTab or categories[1] or ""
    local currentTab = initialTab

    local function OpenCategory(catName)
        currentTab = catName
        hg.settings.LastTab = catName

        contentPanel:Clear()
        contentPanel:SetAlpha(0)
        contentPanel:AlphaTo(255, 0.15, 0)

        local catTable = hg.settings.tbl[catName]
        if not catTable then return end

        local yOffset = 10
        local header = hg.CreateCategory(catName, contentPanel, yOffset)
        yOffset = yOffset + header:GetTall() + 10

        for convarName, settingData in pairs(catTable) do
            local btn = hg.CreateButton(settingData, convarName, contentPanel, yOffset)
            if btn then
                yOffset = yOffset + btn:GetTall() + 10
            end
        end

        local spacer = vgui.Create("DPanel", contentPanel)
        spacer:SetSize(0, 0)
        spacer:SetPos(0, yOffset + 10)
    end

    for _, catName in ipairs(categories) do
        local tabBtn = vgui.Create("DButton")
        surface.SetFont("ZCity_setiings_fine")
        local tw, _ = surface.GetTextSize(catName)
        tabBtn:SetSize(tw + ScreenScale(16), tabH)
        tabBtn:SetText("")
        tabBtn.HoverLerp = 0

        tabBtn.Paint = function(s, w, h)
            local isSelected = (currentTab == catName)
            local isHovered = s:IsHovered()
            s.HoverLerp = Lerp(FrameTime() * 10, s.HoverLerp, (isSelected or isHovered) and 1 or 0)

            local bgAlpha = Lerp(s.HoverLerp, 70, 160)
            surface.SetDrawColor(38, 38, 38, bgAlpha)
            surface.DrawRect(0, 0, w, h)

            if isSelected then
                surface.SetDrawColor(192, 0, 0, 240)
                surface.DrawRect(0, h - 3, w, 3)
            elseif s.HoverLerp > 0.05 then
                surface.SetDrawColor(120, 120, 120, 150 * s.HoverLerp)
                surface.DrawRect(0, h - 2, w, 2)
            end

            local textColor = isSelected and Color(255, 255, 255) or Color(170 + 70 * s.HoverLerp, 170 + 70 * s.HoverLerp, 170 + 70 * s.HoverLerp)
            draw.SimpleText(catName, "ZCity_setiings_fine", w / 2, h / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        tabBtn.DoClick = function()
            if currentTab == catName then return end
            surface.PlaySound("shitty/tap_depress.wav")
            OpenCategory(catName)
        end

        scroller:AddPanel(tabBtn)

        if catName == initialTab then
            timer.Simple(0, function()
                if IsValid(scroller) and IsValid(tabBtn) then
                    scroller:ScrollToChild(tabBtn)
                end
            end)
        end
    end

    if initialTab ~= "" then
        OpenCategory(initialTab)
    end

    local stickerSize = ScreenScale(45)
    local stickerBtn = vgui.Create("DButton", ParentPanel)
    stickerBtn:SetSize(stickerSize, stickerSize)
    stickerBtn:SetText("")

    local baseX = ParentPanel:GetWide() - stickerSize - ScreenScale(18)
    local baseY = ParentPanel:GetTall() - stickerSize - ScreenScale(18)
    stickerBtn:SetPos(baseX, baseY)

    stickerBtn.Think = function(self)
        local active = hg_ui_sticker:GetBool()
        self:SetMouseInputEnabled(active)
        if not active then return end

        local t = CurTime() * 2
        local offX = math.sin(t) * ScreenScale(7)
        local offY = math.cos(t * 1.5) * ScreenScale(4)

        local jumpY = 0
        local timeSince = CurTime() - (self.ClickTime or 0)
        if timeSince < 0.45 then
            local p = timeSince / 0.45
            jumpY = -math.sin(p * math.pi) * ScreenScale(14)
        end

        self:SetPos(baseX + offX, baseY + offY + jumpY)
    end

    stickerBtn.Paint = function(self, w, h)
        if not hg_ui_sticker:GetBool() then return end

        local timeSince = CurTime() - (self.ClickTime or 0)
        local scaleX = 1
        local scaleY = 1
        local angle = 0

        if timeSince < 0.45 then
            local p = timeSince / 0.45
            local stretch = math.sin(p * math.pi)
            scaleX = 1 - stretch * 0.12
            scaleY = 1 + stretch * 0.22
            angle = math.sin(p * math.pi * 2) * (1 - p) * 12
        end

        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(kartinko)
        surface.DrawTexturedRectRotated(w / 2, h / 2, w * scaleX, h * scaleY, angle)
    end

    stickerBtn.DoClick = function(self)
        if not hg_ui_sticker:GetBool() then return end
        self.ClickTime = CurTime()
        surface.PlaySound("Chito.mp3")
    end
end