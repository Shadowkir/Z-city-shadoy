hg.Appearance = hg.Appearance or {}
hg.PointShop = hg.PointShop or {}

hg.Appearance.ModelFaceSlots = hg.Appearance.ModelFaceSlots or {}

hg.Appearance.PlayerModels = hg.Appearance.PlayerModels or { [1] = {}, [2] = {} }
hg.Appearance.Clothes = hg.Appearance.Clothes or { [1] = {}, [2] = {} }
hg.Appearance.ClothesDesc = hg.Appearance.ClothesDesc or {}
hg.Appearance.FacemapsSlots = hg.Appearance.FacemapsSlots or {}
hg.Appearance.FacemapsModels = hg.Appearance.FacemapsModels or {}

local function AddHL2Clothes()
    hg.Appearance.Clothes = hg.Appearance.Clothes or { [1] = {}, [2] = {} }
    hg.Appearance.ClothesDesc = hg.Appearance.ClothesDesc or {}

    local maleClothes = {
        Boiler_Suit = "models/humans/male/group01/hl2civilian",
		Medic_Uniform = "models/humans/male/group01/hl2rebelmedic",
		Refugee_Attire = "models/humans/male/group01/hl2refugee",
		Rebel_Cloths = "models/humans/male/group01/hl2rebel",
		Prospekt_Attire = "models/humans/male/group01/coldgearsheet",
    }
    for id, path in pairs(maleClothes) do
        hg.Appearance.Clothes[1][id] = path
        hg.Appearance.ClothesDesc[id] = hg.Appearance.ClothesDesc[id] or { desc = "Unique clothes from Colorable Clothes! How original..." }
    end

    local femaleClothes = {
        Boiler_Suit = "models/humans/female/group01/hl2civilian",
		Refugee_Attire = "models/humans/female/group01/hl2refugee",
		Rebel_Cloths = "models/humans/female/group01/hl2rebel",
    }
    for id, path in pairs(femaleClothes) do
        hg.Appearance.Clothes[2][id] = path
        hg.Appearance.ClothesDesc[id] = hg.Appearance.ClothesDesc[id] or { desc = "Unique clothes from Colorable Clothes! How unoriginal..." }
    end

end


hook.Add("Initialize", "HL2AppearanceClothes_Init", function()
    AddHL2Clothes()
end)

hook.Add("InitPostEntity", "ZCity_LoadHL2AppearanceClothes_Init", function()
    AddHL2Clothes()
end)

hook.Add("OnGamemodeLoaded", "ZCity_LoadHL2AppearanceClothes", function()
    AddHL2Clothes()
end)

hook.Add("PostGamemodeLoaded", "ZCity_LoadHL2AppearanceClothes_PostGM", function()
    AddHL2Clothes()
end)

if SERVER then
    local function PatchAppearanceReset()
        local appearanceTable = hg.Appearance
        if not appearanceTable or appearanceTable.__ZCitySubmaterialResetPatched then return end
        local originalForceApply = appearanceTable.ForceApplyAppearance
        if not isfunction(originalForceApply) then return end

        appearanceTable.__ZCitySubmaterialResetPatched = true
        appearanceTable.ForceApplyAppearance = function(ply, tbl, noModelChange)
            if IsValid(ply) and ply.GetMaterials and ply.SetSubMaterial then
                local mats = ply:GetMaterials() or {}
                for i = 1, #mats do
                    ply:SetSubMaterial(i - 1, nil)
                end
            end

            return originalForceApply(ply, tbl, noModelChange)
        end
    end

    hook.Add("InitPostEntity", "ZCity_PatchForceApplyAppearanceReset", function()
        PatchAppearanceReset()
        timer.Create("ZCity_PatchForceApplyAppearanceResetRetry", 0.5, 20, function()
            if hg.Appearance and hg.Appearance.__ZCitySubmaterialResetPatched then
                timer.Remove("ZCity_PatchForceApplyAppearanceResetRetry")
                return
            end
            PatchAppearanceReset()
        end)
    end)
end