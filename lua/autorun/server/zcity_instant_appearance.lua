hook.Add("Initialize", "ZCity_InstantAppearance_Init", function()
    if not hg or not hg.Appearance then return end

    local APmodule = hg.Appearance
    local PSmodule = hg.PointShop

    local function CheckAttachments(ply, tbl)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        local isClass = ply.PlayerClassName and ply.PlayerClassName ~= "none" and ply.PlayerClassName ~= ""
        if isClass then
            tbl.AClothes = {}
            tbl.AFacemap = "normal"
            tbl.ABodygroups = {}
        end

        if hg.Appearance.GetAccessToAll(ply) then return tbl end
        
        for i = 1, #tbl.AAttachments do
            local uid = tbl.AAttachments[i]
            if PSmodule.Items[uid] and (not ply:PS_HasItem(uid) and ply:IsPlayer()) then
                tbl.AAttachments[i] = ""
                if ply.ChatPrint then ply:ChatPrint(uid .. " - not bought, removed") end
            end

            if hg.Accessories[uid] and hg.Accessories[uid].disallowinappearance then
                tbl.AAttachments[i] = ""
                if ply.ChatPrint then ply:ChatPrint(uid .. " - is disallowed in default appearance, removed") end
            end
        end

        local tMdl = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel] or tbl.AModel
        tbl.ABodygroups = tbl.ABodygroups or {}
        for k, v in pairs(tbl.ABodygroups) do
            if not hg.Appearance.Bodygroups[k] then continue end
            if not hg.Appearance.Bodygroups[k][tMdl.sex and 2 or 1] then continue end
            local bodygroup = hg.Appearance.Bodygroups[k][tMdl.sex and 2 or 1][v]

            if not bodygroup then continue end

            local uid = bodygroup["ID"]
            if bodygroup[2] and uid and PSmodule.Items[uid] and (not ply:PS_HasItem(uid) and ply:IsPlayer()) then
                tbl.ABodygroups[k] = nil
                if ply.ChatPrint then ply:ChatPrint(v .. " - not bought, removed") end
            end
        end

        return tbl
    end

    _G.ApplyAppearanceRagdoll = function(ent, ply)
        local Appearance = ply.CurAppearance
        if not Appearance then return end
        
        ent:SetNWString("PlayerName", ply:GetNWString("PlayerName", Appearance.AName))
        ent:SetNetVar("Accessories", ply:GetNetVar("Accessories", ""))

        local isClass = ply.PlayerClassName and ply.PlayerClassName ~= "none" and ply.PlayerClassName ~= ""
        if isClass then
            ent:SetSubMaterial()
            ent:SetBodyGroups("00000000000000000000")
            local clr = Appearance.AColor
            if istable(clr) then
                ent:SetNWVector("PlayerColor", Vector(clr.r / 255, clr.g / 255, clr.b / 255))
            end
            return
        end

        local tMdl = APmodule.PlayerModels[1][ent:GetModel()] or APmodule.PlayerModels[2][ent:GetModel()] or APmodule.PlayerModels[1][Appearance.AModel] or APmodule.PlayerModels[2][Appearance.AModel]
        
        ent:SetSubMaterial()
        local mats = ent:GetMaterials()

        if istable(tMdl) then
            for k, v in pairs(tMdl.submatSlots) do
                local slot = -1
                for i = 1, #mats do
                    if mats[i] == v then slot = i - 1 break end
                end
                
                if slot != -1 then
                    local clothingType = Appearance.AClothes[k] or "normal"
                    local matPath = hg.Appearance.Clothes[tMdl.sex and 2 or 1][clothingType] or hg.Appearance.Clothes[tMdl.sex and 2 or 1]["normal"]
                    ent:SetSubMaterial(slot, matPath)
                    ent:SetNWString("Colthes" .. k, clothingType)
                end
            end
        end

        for i = 1, #mats do
            if hg.Appearance.FacemapsSlots[mats[i]] and hg.Appearance.FacemapsSlots[mats[i]][Appearance.AFacemap] then
                ent:SetSubMaterial(i - 1, hg.Appearance.FacemapsSlots[mats[i]][Appearance.AFacemap])
            end
        end

        ent:SetBodyGroups("00000000000000000000")
        local bodygroups = ent:GetBodyGroups()
        Appearance.ABodygroups = Appearance.ABodygroups or {}
        for k, v in ipairs(bodygroups) do
            if not v.name then continue end
            if not Appearance.ABodygroups[v.name] then continue end
            if not hg.Appearance.Bodygroups[v.name] then continue end
            for i = 0, #v.submodels do
                local b = v.submodels[i]
                if not hg.Appearance.Bodygroups[v.name][tMdl.sex and 2 or 1][Appearance.ABodygroups[v.name]] then continue end
                if hg.Appearance.Bodygroups[v.name][tMdl.sex and 2 or 1][Appearance.ABodygroups[v.name]][1] != b then continue end
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
        oldForce(ply, tbl, noModelChange)

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
            client.CachedAppearance = APmodule.GetRandomAppearance()
        else
            client.CachedAppearance = tAppearance
        end
        
        local checked = CheckAttachments(client, client.CachedAppearance)

        local noModelChange = false
        if client.PlayerClassName and client.PlayerClassName ~= "none" and client.PlayerClassName ~= "" then
            noModelChange = true
        end

        APmodule.ForceApplyAppearance(client, checked, noModelChange)
    end)

    print("[Z-City] Instant Appearance Apply loaded (v3)!")
end)