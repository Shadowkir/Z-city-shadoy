util.AddNetworkString("Get_Appearance")
util.AddNetworkString("OnlyGet_Appearance")
hg.Appearance = hg.Appearance or {}
local APmodule = hg.Appearance

hg.PointShop = hg.PointShop or {}
local PSmodule = hg.PointShop

local cv_custom_skins = CreateConVar("hg_custom_skins", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Включение уникальных скинов по SteamID (1 - вкл, 0 - выкл)", 0, 1)

local CustomPlayerModels = {
    ["76561199028709348"] = "models/saya/saya_no_uta/rstar/saya/saya.mdl", --necoarci
    --[""] = "",
}

--прекэш всех добавленных моделей. Так что такие пироги
for _, mdl in pairs(CustomPlayerModels) do
    util.PrecacheModel(mdl)
end

local function CheckAttachments(ply, tbl)
    if !IsValid(ply) or !ply:IsPlayer() then return tbl end
    if hg.Appearance.GetAccessToAll and hg.Appearance.GetAccessToAll(ply) then return tbl end

    if tbl.AAttachments then
        for i = 1, #tbl.AAttachments do
            local uid = tbl.AAttachments[i]
            if PSmodule.Items and PSmodule.Items[uid] and (!ply:PS_HasItem(uid) and ply:IsPlayer()) then
                tbl.AAttachments[i] = ""
            end

            if hg.Accessories and hg.Accessories[uid] and hg.Accessories[uid].disallowinappearance then
                tbl.AAttachments[i] = ""
            end
        end
    end

    local tMdl = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel] or tbl.AModel
    if istable(tMdl) and tbl.ABodygroups and hg.Appearance.Bodygroups then
        for k, v in pairs(tbl.ABodygroups) do
            local bgCategory = hg.Appearance.Bodygroups[k]
            if not bgCategory then continue end

            local sexIndex = tMdl.sex and 2 or 1
            if not bgCategory[sexIndex] then continue end

            local bodygroup = bgCategory[sexIndex][v]
            if not bodygroup then continue end

            local uid = bodygroup["ID"]
            if bodygroup[2] and uid and PSmodule.Items and PSmodule.Items[uid] and (!ply:PS_HasItem(uid) and ply:IsPlayer()) then
                tbl.ABodygroups[k] = nil
            end
        end
    end

    return tbl
end

local function ForceApplyAppearance(ply, tbl, noModelChange)
    if not IsValid(ply) or not tbl then return end

    local isCustom = false
    local customMdl = nil

    if cv_custom_skins:GetBool() and ply:IsPlayer() then
        customMdl = CustomPlayerModels[ply:SteamID64()]
        if customMdl then
            isCustom = true
        end
    end

    local finalModel = customMdl
    local tMdl = nil

    if not isCustom then
        tMdl = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel] or tbl.AModel
        finalModel = istable(tMdl) and tMdl.mdl or tMdl
    end

    if finalModel and finalModel ~= ply:GetModel() and not noModelChange then
        ply:SetModel(finalModel)
    end

    local clr = tbl.AColor
    if clr then
        if ply.SetPlayerColor then
            ply:SetPlayerColor(Vector(clr.r / 255, clr.g / 255, clr.b / 255))
        end
        ply:SetNWVector("PlayerColor", Vector(clr.r / 255, clr.g / 255, clr.b / 255))
    end

    ply:SetSubMaterial()

    if not isCustom then
        local mats = ply:GetMaterials()

        if istable(tMdl) and tMdl.submatSlots and tbl.AClothes then
            for k, v in pairs(tMdl.submatSlots) do
                local slot = 1
                for i = 1, #mats do
                    if mats[i] == v then slot = i - 1 break end
                end
                local sexIdx = tMdl.sex and 2 or 1
                ply:SetSubMaterial(slot, hg.Appearance.Clothes[sexIdx][tbl.AClothes[k]] or hg.Appearance.Clothes[sexIdx]["normal"])
                ply:SetNWString("Colthes" .. k, tbl.AClothes[k] or "normal")
            end
        end

        if tbl.AFacemap and hg.Appearance.FacemapsSlots then
            for i = 1, #mats do
                if hg.Appearance.FacemapsSlots[mats[i]] and hg.Appearance.FacemapsSlots[mats[i]][tbl.AFacemap] then
                    ply:SetSubMaterial(i - 1, hg.Appearance.FacemapsSlots[mats[i]][tbl.AFacemap])
                end
            end
        end
    end

    if tbl.AName then
        ply:SetNWString("PlayerName", tbl.AName)
    end

    ply:SetBodyGroups("00000000000000000000")

    if not isCustom and istable(tMdl) and tbl.ABodygroups then
        local bodygroups = ply:GetBodyGroups()
        local sexIdx = tMdl.sex and 2 or 1

        for k, v in ipairs(bodygroups) do
            if !v.name or !tbl.ABodygroups[v.name] or !hg.Appearance.Bodygroups[v.name] then continue end
            if !hg.Appearance.Bodygroups[v.name][sexIdx] then continue end

            local desiredVal = tbl.ABodygroups[v.name]
            local targetData = hg.Appearance.Bodygroups[v.name][sexIdx][desiredVal]
            if not targetData then continue end

            for i = 0, #v.submodels do
                local b = v.submodels[i]
                if targetData[1] == b then
                    ply:SetBodygroup(k - 1, i)
                    break
                end
            end
        end
    end

    if tbl.AAttachments then
        ply:SetNetVar("Accessories", tbl.AAttachments)
    end

    ply.CurAppearance = {}
    table.CopyFromTo(tbl, ply.CurAppearance)
end

local function WearAppearance(ply, tbl)
    if not tbl then return end
    local safeTable = table.Copy(tbl)
    local checked = CheckAttachments(ply, safeTable)
    ForceApplyAppearance(ply, checked)
end

APmodule.ForceApplyAppearance = ForceApplyAppearance

local tWaitResponse = {}

function ApplyAppearance(Client, tAppearance, bRandom, bResponeIsValid, bUseCahsed)
    if not IsValid(Client) then return end

    if bRandom or (Client.IsBot and Client:IsBot()) or (Client.IsRagdoll and Client:IsRagdoll()) then
        tAppearance = APmodule.GetRandomAppearance()
        WearAppearance(Client, tAppearance)
        return
    end

    if bUseCahsed then
        tAppearance = Client.CachedAppearance or APmodule.GetRandomAppearance()
        if !APmodule.AppearanceValidater(tAppearance) then 
            tAppearance = APmodule.GetRandomAppearance() 
        end
        net.Start("OnlyGet_Appearance")
        net.Send(Client)
        WearAppearance(Client, tAppearance)
        return
    end

    if !bResponeIsValid then
        tWaitResponse[Client] = CurTime() + 3
        net.Start("Get_Appearance")
        net.Send(Client)
        return
    end

    if !tWaitResponse[Client] then return end
    if tWaitResponse[Client] > CurTime() then
        ApplyAppearance(Client, nil, true)
        return
    end

    if !tAppearance or !APmodule.AppearanceValidater(tAppearance) then 
        ApplyAppearance(Client, nil, true) 
        return 
    end

    WearAppearance(Client, tAppearance)
end

net.Receive("Get_Appearance", function(len, client)
    local tAppearance = net.ReadTable()
    local bRandom = net.ReadBool()
    if !APmodule.AppearanceValidater(tAppearance) then bRandom = true end

    ApplyAppearance(client, tAppearance, table.IsEmpty(tAppearance) and true or bRandom, true)
end)

net.Receive("OnlyGet_Appearance", function(len, client)
    local tAppearance = net.ReadTable()
    local bRandom = !tAppearance or table.IsEmpty(tAppearance)
    client.CachedAppearance = bRandom and APmodule.GetRandomAppearance() or tAppearance
end)

APmodule.ApplyAppearance = ApplyAppearance

-- Ragdoll apply
function ApplyAppearanceRagdoll(ent, ply)
    local Appearance = ply.CurAppearance
    if !Appearance then return end
    ent:SetNWString("PlayerName", ply:GetNWString("PlayerName", Appearance.AName))
    ent:SetNetVar("Accessories", ply:GetNetVar("Accessories", ""))

    local tMdl = APmodule.PlayerModels[1][ent:GetModel()] or APmodule.PlayerModels[2][ent:GetModel()] or ent:GetModel()
    if istable(tMdl) and tMdl.submatSlots then
        for k, v in pairs(tMdl.submatSlots) do
            ent:SetNWString("Colthes" .. k, ply:GetNWString("Colthes" .. k, "normal"))
        end
    end
end

-- Sandbox applyApperance 
if engine.ActiveGamemode() == "sandbox" then
    hook.Add("PlayerSpawn", "SetAppearance", function(ply)
        if OverrideSpawn then return end
        timer.Simple(0, function()
            if IsValid(ply) then
                ApplyAppearance(ply, nil, nil, nil, true)
            end
        end)
    end)
end