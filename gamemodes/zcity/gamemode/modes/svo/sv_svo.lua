MODE.name = "svo"
MODE.PrintName = "Special Military Operation"

MODE.Chance = 0.05
MODE.LootSpawn = false
MODE.ForBigMaps = true

function MODE:ClearPlayerRoles()
    for _, ply in player.Iterator() do
        ply:SetNWString("PlayerRole", "")
        ply.subClass = nil
    end
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 1, true
end

util.AddNetworkString("svo_start")
util.AddNetworkString("svo_roundend")

function MODE:Intermission()
    game.CleanUpMap()

    for _, ply in player.Iterator() do
        ply:SetupTeam(ply:Team())
    end

    net.Start("svo_start")
    net.Broadcast()
end

function MODE:RoundStart()
end

function MODE:RoundThink()
end

function MODE:CheckAlivePlayers()
    return zb:CheckAliveTeams(true)
end

function MODE:ShouldRoundEnd()
    local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
    return endround
end

local EquipmentRU = {
    ["leader"] = {
        Primary = "weapon_ak203",
        Secondary = "weapon_makarov",
        Other = {"weapon_hands_sh", "weapon_melee", "weapon_hg_rgd_tpik", "weapon_bandage_sh", "weapon_medkit_sh", "weapon_tourniquet"},
        Attachments = {
            Primary = { Scopes = {"optic11", "holo13"}, Barrel = {"supressor1"} }
        },
        Armor = {"vest5", "helmet1", "headphones1"}
    },
    ["machinegunner"] = {
        Primary = "weapon_pkm",
        Secondary = "weapon_makarov",
        Other = {"weapon_hands_sh", "weapon_melee", "weapon_hg_rgd_tpik", "weapon_bandage_sh", "weapon_medkit_sh", "weapon_tourniquet"},
        Attachments = {
            Primary = { Scopes = {"holo6", "optic11"} }
        }, 
        Armor = {"vest5", "helmet1", "headphones1"}
    },
    ["sniper"] = {
        Primary = "weapon_svd",
        Secondary = "weapon_makarov",
        Other = {"weapon_hands_sh", "weapon_melee", "weapon_bandage_sh", "weapon_medkit_sh"},
        Attachments = {
            Primary = { Scopes = {"optic11", "optic3"} }
        },
        Armor = {"vest5", "helmet1", "headphones1"}
    },
    ["sniper2"] = {
        Primary = "weapon_asval",
        Secondary = "weapon_makarov",
        Other = {"weapon_hands_sh", "weapon_melee", "weapon_hg_rgd_tpik", "weapon_bandage_sh", "weapon_medkit_sh"},
        Attachments = {
            Primary = { Scopes = {"optic3", "optic4"} }
        },
        Armor = {"vest5", "helmet1", "headphones1"}
    },
    ["rifleman"] = {
        PrintName = "Штурмовик",
        Primary = "weapon_ak74",
        Secondary = "weapon_makarov",
        Other = {"weapon_hands_sh", "weapon_melee", "weapon_hg_rgd_tpik", "weapon_bandage_sh", "weapon_medkit_sh"},
        Attachments = {
            Primary = { Scopes = {"holo12", "holo2"} }
        },
        Armor = {"vest5", "helmet1"}
    }
}

local EquipmentUA = {
    ["leader"] = {
        Primary = "weapon_hk416",
        Secondary = "weapon_glock17",
        Other = {"weapon_hands_sh", "weapon_sogknife", "weapon_hg_grenade_tpik", "weapon_bandage_sh", "weapon_medkit_sh", "weapon_tourniquet"},
        Attachments = {
            Primary = { Scopes = {"holo17", "holo14"}, Barrel = {"supressor2"} }
        },
        Armor = {"vest1", "helmet1", "headphones1"}
    },
    ["machinegunner"] = {
        Primary = "weapon_m249",
        Secondary = "weapon_glock17",
        Other = {"weapon_hands_sh", "weapon_sogknife", "weapon_hg_grenade_tpik", "weapon_bandage_sh", "weapon_medkit_sh", "weapon_tourniquet"},
        Attachments = {
            Primary = { Scopes = {"holo11", "holo4"} }
        },
        Armor = {"vest1", "helmet1", "headphones1"}
    },
    ["sniper"] = {
        Primary = "weapon_sr25",
        Secondary = "weapon_glock17",
        Other = {"weapon_hands_sh", "weapon_sogknife", "weapon_medkit_sh"},
        Attachments = {
            Primary = { Scopes = {"optic6", "optic2"} }
        },
        Armor = {"vest3", "helmet1", "headphones1"}
    },
    ["rifleman"] = {
        Primary = "weapon_m4a1",
        Secondary = "weapon_glock17",
        Other = {"weapon_hands_sh", "weapon_sogknife", "weapon_hg_grenade_tpik", "weapon_bandage_sh", "weapon_medkit_sh"},
        Attachments = {
            Primary = { Scopes = {"holo14", "holo17"} }
        },
        Armor = {"vest1", "helmet1"}
    }
}

local function ApplyLoadout(ply, loadout, teamId)
    local inv = ply:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    ply:SetNetVar("Inventory", inv)

    if loadout.Primary then
        local primary = ply:Give(loadout.Primary)
        if IsValid(primary) then
            ply:GiveAmmo(primary:GetMaxClip1() * 4, primary:GetPrimaryAmmoType(), true)
            
            if loadout.Attachments and loadout.Attachments.Primary then
                local atts = loadout.Attachments.Primary
                if atts.Scopes and #atts.Scopes > 0 then
                    hg.AddAttachmentForce(ply, primary, atts.Scopes[math.random(#atts.Scopes)])
                end
                if atts.Barrel and #atts.Barrel > 0 then
                    hg.AddAttachmentForce(ply, primary, atts.Barrel[math.random(#atts.Barrel)])
                end
            end
        end
    end

    if loadout.Secondary then
        local sec = ply:Give(loadout.Secondary)
        if IsValid(sec) then
            ply:GiveAmmo(sec:GetMaxClip1() * 3, sec:GetPrimaryAmmoType(), true)
        end
    end

    if loadout.Armor then
        hg.AddArmor(ply, loadout.Armor)
    end

    if loadout.Other then
        for _, wep in ipairs(loadout.Other) do
            ply:Give(wep)
        end
    end

    local walkie = ply:Give("weapon_walkie_talkie")
    if IsValid(walkie) then
        walkie.Frequency = (teamId == 1 and 100) or 200
    end

    ply:Give("weapon_hands_sh")
    ply:SelectWeapon("weapon_hands_sh")
end

function MODE:GiveEquipment()
    timer.Simple(0.1, function()
        local players_alive = zb:CheckPlaying()

        for _, ply in RandomPairs(players_alive) do
            ply:SetSuppressPickupNotices(true)
            ply.noSound = true

            local teamId = ply:Team()
            local equipTable = (teamId == 1) and EquipmentRU or EquipmentUA

            local loadoutData = table.Random(equipTable)

            ply:SetPlayerClass(teamId == 1 and "russiansoldier" or "ukrainiansoldier")
            
            ApplyLoadout(ply, loadoutData, teamId)

            timer.Simple(0.1, function()
                if IsValid(ply) then ply.noSound = false end
            end)

            ply:SetSuppressPickupNotices(false)
        end
    end)
end

function MODE:GetTeamSpawn()
    local uaPoints = zb.GetMapPoints("HMCD_SVO_UKRAINE")
    local ruPoints = zb.GetMapPoints("HMCD_SVO_RUSSIAN")

    if not uaPoints or #uaPoints == 0 then uaPoints = zb.GetMapPoints("HMCD_TDM_T") end
    if not ruPoints or #ruPoints == 0 then ruPoints = zb.GetMapPoints("HMCD_TDM_CT") end

    return zb.TranslatePointsToVectors(uaPoints), zb.TranslatePointsToVectors(ruPoints)
end

function MODE:EndRound()
    local team0, team1 = 0, 0
    for _, ply in player.Iterator() do
        if ply:Alive() then
            if ply:Team() == 0 then team0 = team0 + 1 end
            if ply:Team() == 1 then team1 = team1 + 1 end
        end
    end

    local winnerteam = 2
    if team0 > team1 then
        winnerteam = 0
    elseif team1 > team0 then
        winnerteam = 1
    elseif team0 == 0 and team1 == 0 then
        winnerteam = 3
    end

    self:ClearPlayerRoles()

    timer.Simple(2, function()
        net.Start("svo_roundend")
        net.WriteInt(winnerteam, 4)
        net.Broadcast()
    end)
end

function MODE:CanLaunch()
    local ru = zb.GetMapPoints("HMCD_SVO_RUSSIAN")
    local ua = zb.GetMapPoints("HMCD_SVO_UKRAINE")
    if ru and #ru > 0 and ua and #ua > 0 then
        return true
    end

    local tdm_t = zb.GetMapPoints("HMCD_TDM_T")
    local tdm_ct = zb.GetMapPoints("HMCD_TDM_CT")
    if tdm_t and #tdm_t > 0 and tdm_ct and #tdm_ct > 0 then
        return true
    end

    return false
end