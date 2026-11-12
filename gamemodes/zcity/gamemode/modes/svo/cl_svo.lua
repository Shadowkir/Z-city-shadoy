MODE.name = "svo"

local MODE = MODE
local StartTime = 0
local hmcdEndMenu = nil

net.Receive("svo_start", function()
    StartTime = CurTime()
    timer.Simple(0.5, function()
        surface.PlaySound(LocalPlayer():Team() == 1 and "ukraineround.wav" or "hohols.mp3")
    end)
    zb.RemoveFade()
end)

local teams = {
    [0] = {
        objective = "Your task is to destroy the enemy forces of Russia.",
        name = "an Ukraine soldier",
        color = Color(204, 163, 0)
    },
    [1] = {
        objective = "Your task is to destroy the enemy forces of Ukraine.",
        name = "a Russian soldier",
        color = Color(34, 139, 34)
    },
}

function MODE:RenderScreenspaceEffects()
    if StartTime + 7.5 < CurTime() then return end
    local fade = math.Clamp(StartTime + 7.5 - CurTime(), 0, 1)

    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

function MODE:HUDPaint()
    if StartTime + 8.5 < CurTime() then return end
    local lply = LocalPlayer()
    if not IsValid(lply) or not lply:Alive() then return end

    zb.RemoveFade()
    local fade = math.Clamp(StartTime + 8 - CurTime(), 0, 1)
    local teamId = lply:Team()
    local tData = teams[teamId] or teams[1]

    local sw, sh = ScrW(), ScrH()

    draw.SimpleText("ZVBattle | Special Military Operation", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0, 162, 255, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local roleColor = Color(tData.color.r, tData.color.g, tData.color.b, 255 * fade)
    draw.SimpleText(tData.name, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, roleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText(tData.objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.88, Color(255, 255, 255, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local BlurBackground = BlurBackground or hg.DrawBlur

local colDarkGreen = Color(25, 95, 25, 220)
local colRed = Color(130, 10, 10)
local colRedUp = Color(160, 30, 30)
local colGray = Color(75, 75, 75, 255)
local colSpect1 = Color(55, 55, 55, 255)

local function OpenEndMenu()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end

    surface.PlaySound("ambient/alarms/warningbell1.wav")

    local sizeX, sizeY = ScrW() / 2.5, ScrH() / 1.2
    local posX, posY = ScrW() / 1.3 - sizeX / 2, ScrH() / 2 - sizeY / 2

    hmcdEndMenu = vgui.Create("ZFrame")
    hmcdEndMenu:SetPos(posX, posY)
    hmcdEndMenu:SetSize(sizeX, sizeY)
    hmcdEndMenu:MakePopup()
    hmcdEndMenu:SetKeyboardInputEnabled(false)
    hmcdEndMenu:ShowCloseButton(false)

    local closebutton = vgui.Create("DButton", hmcdEndMenu)
    closebutton:SetPos(5, 5)
    closebutton:SetSize(ScrW() / 20, ScrH() / 30)
    closebutton:SetText("")
    closebutton.DoClick = function()
        if IsValid(hmcdEndMenu) then
            hmcdEndMenu:Close()
            hmcdEndMenu = nil
        end
    end
    closebutton.Paint = function(self, w, h)
        surface.SetDrawColor(colDarkGreen)
        surface.DrawOutlinedRect(0, 0, w, h, 1.5)

        surface.SetFont("ZB_InterfaceMedium")
        surface.SetTextColor(255, 255, 255, 255)
        local lengthX = surface.GetTextSize("Close")
        surface.SetTextPos(w / 2 - lengthX / 2, 4)
        surface.DrawText("Close")
    end

    hmcdEndMenu.Paint = function(self, w, h)
        BlurBackground(self)
        surface.SetFont("ZB_InterfaceMediumLarge")
        surface.SetTextColor(255, 255, 255, 255)
        local lengthX = surface.GetTextSize("Players:")
        surface.SetTextPos(w / 2 - lengthX / 2, 20)
        surface.DrawText("Players:")

        surface.SetDrawColor(colDarkGreen)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    local scroll = vgui.Create("DScrollPanel", hmcdEndMenu)
    scroll:SetPos(10, 70)
    scroll:SetSize(sizeX - 20, sizeY - 80)

    function scroll:Paint(w, h)
        BlurBackground(self)
        surface.SetDrawColor(colDarkGreen)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        local btn = vgui.Create("DButton", scroll)
        btn:SetSize(100, 45)
        btn:Dock(TOP)
        btn:DockMargin(4, 4, 4, 2)
        btn:SetText("")

        btn.Paint = function(self, w, h)
            local isAlive = ply:Alive()
            local c1 = isAlive and colRed or colGray
            local c2 = isAlive and colRedUp or colSpect1

            surface.SetDrawColor(c1.r, c1.g, c1.b, c1.a)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(c2.r, c2.g, c2.b, c2.a)
            surface.DrawRect(0, h / 2, w, h / 2)

            surface.SetFont("ZB_InterfaceMedium")
            surface.SetTextColor(255, 255, 255, 255)
            
            local statusText = ply:Name() .. (isAlive and "" or "He quited")
            surface.SetTextPos(15, h / 2 - 8)
            surface.DrawText(statusText)

            local roleText = ply:GetNWString("PlayerRole", "")
            if roleText ~= "" then
                local lengthR = surface.GetTextSize(roleText)
                surface.SetTextPos(w / 2 - lengthR / 2, h / 2 - 8)
                surface.DrawText(roleText)
            end

            local kills = tostring(ply:Frags()) .. " Kills"
            local lengthK = surface.GetTextSize(kills)
            surface.SetTextPos(w - lengthK - 15, h / 2 - 8)
            surface.DrawText(kills)
        end

        btn.DoClick = function()
            if not ply:IsBot() then
                gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
            end
        end

        scroll:AddItem(btn)
    end
end

net.Receive("svo_roundend", function()
    OpenEndMenu()
end)

function MODE:RoundStart()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end