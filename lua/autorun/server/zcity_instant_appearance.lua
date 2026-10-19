local function InitInstantAppearance()
    if not hg or not hg.Appearance then return false end

    local APmodule = hg.Appearance
    local PSmodule = hg.PointShop or {}

    local function SafeFindModel(mdlName)
        if not mdlName then return nil end
        if istable(mdlName) then return mdlName end
        for sex = 1, 2 do
            if APmodule.PlayerModels and APmodule.PlayerModels[sex] and APmodule.PlayerModels[sex][mdlName] then
                return APmodule.PlayerModels[sex][mdlName]
            end
        end
        if APmodule.FuckYouModels then
            for sex = 1, 2 do
                if APmodule.FuckYouModels[sex] and APmodule.FuckYouModels[sex][mdlName] then
                    return APmodule.FuckYouModels[sex][mdlName]
                end
            end
        end
        return nil
    end

    local function CheckAttachments(ply, tbl)
        if not IsValid(ply) or not ply:IsPlayer() or not tbl then return tbl end
        
        local isClass = ply.PlayerClassName and ply.PlayerClassName ~= "none" and ply.PlayerClassName ~= ""
        if isClass then
            tbl.AClothes = nil
            tbl.AFacemap = nil
            tbl.ABodygroups = {}
            tbl.AAttachments = {}
            return tbl
        end

        if hg.Appearance.GetAccessToAll and hg.Appearance.GetAccessToAll(ply) then return tbl end
        
        tbl.AAttachments = tbl.AAttachments or {}
        for i = #tbl.AAttachments, 1, -1 do
            local uid = tbl.AAttachments[i]
            local remove = false

            if PSmodule.Items and PSmodule.Items[uid] and (not ply:PS_HasItem(uid) and ply:IsPlayer()) then
                remove = true
                if ply.ChatPrint then ply:ChatPrint(uid .. " - not bought, removed") end
            end

            if hg.Accessories and hg.Accessories[uid] and hg.Accessories[uid].disallowinappearance then
                remove = true
                if ply.ChatPrint then ply:ChatPrint(uid .. " - is disallowed in default appearance, removed") end
            end

            if remove then
                table.remove(tbl.AAttachments, i)
            end
        end

        local tMdl = SafeFindModel(tbl.AModel) or tbl.AModel
        local sexIdx = (istable(tMdl) and tMdl.sex) and 2 or 1

        tbl.ABodygroups = tbl.ABodygroups or {}
        if hg.Appearance.Bodygroups then
            for k, v in pairs(tbl.ABodygroups) do
                local bgCategory = hg.Appearance.Bodygroups[k]
                if not bgCategory or not bgCategory[sexIdx] then continue end
                local bodygroup = bgCategory[sexIdx][v]

                if not bodygroup then continue end

                local uid = bodygroup["ID"]
                if bodygroup[2] and uid and PSmodule.Items and PSmodule.Items[uid] and (not ply:PS_HasItem(uid) and ply:IsPlayer()) then
                    tbl.ABodygroups[k] = nil
                    if ply.ChatPrint then ply:ChatPrint(v .. " - not bought, removed") end
                end
            end
        end

        return tbl
    end

    _G.ApplyAppearanceRagdoll = function(ent, ply)
        if not IsValid(ent) or not IsValid(ply) then return end
        local Appearance = ply.CurAppearance
        
        local isClass = ply.PlayerClassName and ply.PlayerClassName ~= "none" and ply.PlayerClassName ~= ""
        if isClass then
            ent:SetNWString("PlayerName", ply:GetNWString("PlayerName", ply:Nick()))
            ent:SetNetVar("Accessories", "")
            
            ent:SetSkin(ply:GetSkin())
            for i = 0, ply:GetNumBodyGroups() - 1 do
                ent:SetBodygroup(i, ply:GetBodygroup(i))
            end
            for i = 0, 31 do
                ent:SetSubMaterial(i, ply:GetSubMaterial(i))
            end

            local clr = Appearance and Appearance.AColor
            if istable(clr) then
                ent:SetNWVector("PlayerColor", Vector(clr.r / 255, clr.g / 255, clr.b / 255))
            else
                ent:SetNWVector("PlayerColor", ply:GetPlayerColor())
            end
            return
        end

        if not Appearance then return end

        ent:SetNWString("PlayerName", ply:GetNWString("PlayerName", Appearance.AName))
        ent:SetNetVar("Accessories", ply:GetNetVar("Accessories", ""))

        local tMdl = SafeFindModel(ent:GetModel()) or SafeFindModel(Appearance.AModel)
        local sexIdx = (istable(tMdl) and tMdl.sex) and 2 or 1
        
        ent:SetSubMaterial()
        local mats = ent:GetMaterials()

        if istable(tMdl) and tMdl.submatSlots and Appearance.AClothes then
            for k, v in pairs(tMdl.submatSlots) do
                local slot = -1
                for i = 1, #mats do
                    if mats[i] == v then slot = i - 1 break end
                end
                
                if slot != -1 then
                    local clothingType = istable(Appearance.AClothes) and (Appearance.AClothes[k] or Appearance.AClothes["main"]) or Appearance.AClothes or "normal"
                    local matPath = (hg.Appearance.Clothes and hg.Appearance.Clothes[sexIdx] and hg.Appearance.Clothes[sexIdx][clothingType]) or (hg.Appearance.Clothes and hg.Appearance.Clothes[sexIdx] and hg.Appearance.Clothes[sexIdx]["normal"])
                    if matPath then
                        ent:SetSubMaterial(slot, matPath)
                        ent:SetNWString("Colthes" .. k, clothingType)
                    end
                end
            end
        end

        if Appearance.AFacemap and hg.Appearance.FacemapsSlots then
            for i = 1, #mats do
                if hg.Appearance.FacemapsSlots[mats[i]] and hg.Appearance.FacemapsSlots[mats[i]][Appearance.AFacemap] then
                    ent:SetSubMaterial(i - 1, hg.Appearance.FacemapsSlots[mats[i]][Appearance.AFacemap])
                end
            end
        end

        ent:SetBodyGroups("00000000000000000000")
        local bodygroups = ent:GetBodyGroups()
        Appearance.ABodygroups = Appearance.ABodygroups or {}
        for k, v in ipairs(bodygroups) do
            if not v.name then continue end
            if not Appearance.ABodygroups[v.name] then continue end
            if not hg.Appearance.Bodygroups or not hg.Appearance.Bodygroups[v.name] then continue end
            for i = 0, #v.submodels do
                local b = v.submodels[i]
                if not hg.Appearance.Bodygroups[v.name][sexIdx] or not hg.Appearance.Bodygroups[v.name][sexIdx][Appearance.ABodygroups[v.name]] then continue end
                if hg.Appearance.Bodygroups[v.name][sexIdx][Appearance.ABodygroups[v.name]][1] != b then continue end
                ent:SetBodygroup(k - 1, i)
            end
        end

        local clr = Appearance.AColor
        if istable(clr) then
            ent:SetNWVector("PlayerColor", Vector(clr.r / 255, clr.g / 255, clr.b / 255))
        end
    end

    local oldForce = APmodule.ForceApplyAppearance
    APmodule.ForceApplyAppearance = function(ply, tbl, noModelChange)
        if ply.PlayerClassName and ply.PlayerClassName ~= "none" and ply.PlayerClassName ~= "" then
            return
        end

        if isfunction(oldForce) then
            oldForce(ply, tbl, noModelChange)
        end

        local ragdoll = ply.FakeRagdoll
        if IsValid(ragdoll) then
            local mdl = ply:GetModel()
            if mdl ~= ragdoll:GetModel() then
                ragdoll:SetModel(mdl)
            end
            
            timer.Simple(0, function()
                if IsValid(ragdoll) and IsValid(ply) then
                    ApplyAppearanceRagdoll(ragdoll, ply)
                end
            end)
        end
    end

    net.Receive("OnlyGet_Appearance", function(len, client)
        local tAppearance = net.ReadTable()
        if not tAppearance or table.IsEmpty(tAppearance) then
            client.CachedAppearance = APmodule.GetRandomAppearance and APmodule.GetRandomAppearance() or {}
        else
            client.CachedAppearance = tAppearance
        end

        if client.PlayerClassName and client.PlayerClassName ~= "none" and client.PlayerClassName ~= "" then
            return
        end

        local checked = CheckAttachments(client, table.Copy(client.CachedAppearance))

        if APmodule.ForceApplyAppearance then
            APmodule.ForceApplyAppearance(client, checked, false)
        end
    end)

    return true
end

hook.Add("PostGamemodeLoaded", "ZCity_InstantAppearance_Init", function()
    InitInstantAppearance()
end)

hook.Add("InitPostEntity", "ZCity_InstantAppearance_InitPost", function()
    if not InitInstantAppearance() then
        timer.Create("ZCity_InstantAppearance_Retry", 0.5, 10, function()
            if InitInstantAppearance() then
                timer.Remove("ZCity_InstantAppearance_Retry")
            end
        end)
    end
end)