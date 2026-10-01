local MODE = MODE

local deathmatch_nozone = ConVarExists("deathmatch_nozone") and GetConVar("deathmatch_nozone") or CreateConVar("deathmatch_nozone", 0, FCVAR_REPLICATED, "Allows to disable deathmatch mode zone.", 0, 1)

MODE.name = "dm"
MODE.PrintName = "Deathmatch"
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.randomSpawns = true

MODE.ForBigMaps = false
MODE.Chance = 0.04

local radius = nil
local mapsize = 7500
-- MODE.MapSize = mapsize

util.AddNetworkString("dm_start")
util.AddNetworkString("dm_end")

function MODE:CanLaunch()
    return true -- (zb.GetWorldSize() >= ZBATTLE_BIGMAP)
end

function MODE:Intermission()
	game.CleanUpMap()

	local poses = {}
	for k, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then
			continue
		end
		
		ApplyAppearance(ply)
		ply:SetupTeam(0)
		table.insert(poses, ply:GetPos())
	end

	local centerpoint = Vector(0, 0, 0)
	for i, pos in ipairs(poses) do
		centerpoint:Add(pos)
	end
	centerpoint:Div(#poses)

	local dist = 0
	for i, pos in ipairs(poses) do
		local dist2 = pos:Distance(centerpoint)
		if dist < dist2 then
			dist = dist2
		end
	end

	zonepoint = centerpoint
	zonedistance = dist
	
	net.Start("dm_start")
		net.WriteVector(zonepoint)
		net.WriteFloat(zonedistance)
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	local AlivePlyTbl = {}
	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		if ply.organism and ply.organism.incapacitated then continue end
		AlivePlyTbl[#AlivePlyTbl + 1] = ply
	end
	return AlivePlyTbl
end

function MODE:ShouldRoundEnd()
	return (#zb:CheckAlive(true) <= 1)
end
--крч это пресеты брони но не все
local ARMOR_DEFAULT = {"vest3", "helmet1"}
local ARMOR_LIGHT   = {"vest1", "helmet1"}
local ARMOR_HEAVY   = {"vest4", "helmet1"}
local ARMOR_NVG     = {"vest1", "helmet1", "nightvision1"}
local ARMOR_MASK    = {"vest3", "helmet1", "mask1"}

local loadouts = {
--пистолеты
	{ p = "weapon_glock17", atts = {{"supressor4"}, {"holo16", "laser3"}, {"holo15", "laser1"}, ""}, armor = ARMOR_DEFAULT },
	{ p = "weapon_cz75",    atts = {{"supressor4"}, ""}, armor = ARMOR_DEFAULT },
	{ p = "weapon_deagle",  armor = ARMOR_DEFAULT },
	{ p = "weapon_glock18c", atts = {{"mag1", "holo16"}}, armor = ARMOR_DEFAULT, ammo = 4 },
	{ p = "weapon_tec9",    armor = ARMOR_DEFAULT },
	{ p = "weapon_hk_usp",  atts = {{"supressor3"}}, armor = ARMOR_DEFAULT },
	{ p = "weapon_revolver2",  armor = ARMOR_DEFAULT },
	{ p = "weapon_revolver357", armor = ARMOR_DEFAULT },

--пп
	{ p = "weapon_mac11",   armor = ARMOR_DEFAULT },
	{ p = "weapon_uzi",     armor = ARMOR_DEFAULT },
	{ p = "weapon_skorpion", armor = ARMOR_DEFAULT, ammo = 4 },
	{ p = "weapon_mp5",     atts = {{"supressor4"}}, armor = ARMOR_DEFAULT },
	{ p = "weapon_mp7",     atts = {{"holo1", "supressor2"}, {"holo5", "supressor2"}, {"laser4", "supressor2"}}, armor = ARMOR_DEFAULT },
	{ p = "weapon_p90",     atts = {{"holo15", "supressor4"}, {"laser1", "supressor4"}, {"holo14", "supressor4"}}, armor = ARMOR_DEFAULT },
	{ p = "weapon_tmp",     atts = {{"optic8"}, {"holo3"}, {"holo4"}}, armor = ARMOR_DEFAULT },
	{ p = "weapon_vector",  atts = {{"supressor4", "holo3"}, {"holo4"}, {"holo7"}}, armor = ARMOR_DEFAULT, ammo = 4 },


--автоматы
	{ p = "weapon_ar15",   atts = {{"holo1", "grip1", "supressor2"}, {"holo5", "grip3", "supressor2"}, {"laser4", "grip2"}, {"laser4", "supressor2"}}, armor = ARMOR_HEAVY },
	{ p = "weapon_m4a1",   atts = {{"holo1", "grip1", "supressor2"}, {"holo5", "grip3", "supressor2"}, {"laser4", "grip2"}, {"laser4", "supressor2"}}, armor = ARMOR_LIGHT },
	{ p = "weapon_hk416",  atts = {{"holo1", "grip1", "supressor2"}, {"holo5", "grip3", "supressor2"}, {"laser4", "grip2"}, {"laser4", "supressor2"}}, armor = ARMOR_LIGHT },
	{ p = "weapon_akm",    atts = {{"holo6", "supressor1"}, {"holo4", "laser1"}, {"supressor1"}}, armor = ARMOR_NVG },
	{ p = "weapon_ak74",   atts = {{"holo6"}, {"holo4"}, {"optic8"}}, armor = ARMOR_LIGHT },
	{ p = "weapon_ak74u",  atts = {{"holo6"}, {"holo4"}}, armor = ARMOR_LIGHT },
	{ p = "weapon_akmwreked", armor = ARMOR_LIGHT },
	{ p = "weapon_dracovska",  armor = ARMOR_LIGHT }, --weapon_draco
	{ p = "weapon_sg552",  atts = {{"optic8"}, {"holo3"}, {"holo4"}}, armor = ARMOR_HEAVY },
	{ p = "weapon_ac556",  atts = {{"holo6"}, {"holo4"}}, armor = ARMOR_DEFAULT },

--дробовики
	{ p = "weapon_remington870", armor = ARMOR_DEFAULT },
	{ p = "weapon_m590a1",   armor = {"vest4", "helmet1", "mask1"} },
	{ p = "weapon_doublebarrel_short", armor = ARMOR_MASK, ammo = 6 },
	{ p = "weapon_xm1014",   armor = ARMOR_MASK },
	{ p = "weapon_saiga12",  armor = ARMOR_MASK, ammo = 4 },
	{ p = "weapon_spas12",   atts = {{"supressor5"}}, armor = ARMOR_MASK },

--снайперки
	{ p = "weapon_sr25",       atts = {{"holo1", "laser2"}, {"optic2"}, {"holo8", "supressor7"}, {"holo5", "supressor7"}}, armor = ARMOR_NVG },
	{ p = "weapon_svd",        atts = {{"holo13"}, {"holo6"}, {"holo2"}}, armor = ARMOR_LIGHT },
	{ p = "weapon_sks",        atts = {{"optic8"}, {"holo6"}}, armor = ARMOR_DEFAULT, ammo = 4 },
	{ p = "weapon_winchester", armor = ARMOR_DEFAULT, ammo = 4 },

--карабины
	{ p = "weapon_mini14",     armor = ARMOR_DEFAULT, ammo = 4 },
	{ p = "weapon_ruger",      armor = ARMOR_DEFAULT, ammo = 5 },

--пулеметы
	{ p = "weapon_pkm",        armor = ARMOR_LIGHT, ammo = 0 },


--комплекты с 1 и 2 оружием
	{ p = "weapon_ar15",       s = "weapon_cz75",        atts = {{"holo1", "grip1"}, {"holo5", "grip3"}}, armor = ARMOR_DEFAULT, ammo2 = 2 },
	{ p = "weapon_akm",        s = "weapon_px4beretta",   atts = {{"holo6"}, {"holo4"}}, armor = ARMOR_DEFAULT, ammo2 = 2 },
	{ p = "weapon_m4a1",       s = "weapon_p22",         atts = {{"holo1", "grip1"}, {"holo5", "grip3"}}, armor = ARMOR_DEFAULT, ammo2 = 2 },
	{ p = "weapon_mp5",        s = "weapon_revolver2",    atts = {{"supressor4"}}, armor = ARMOR_DEFAULT, ammo2 = 2 },
	{ p = "weapon_sks",        s = "weapon_flintlock",   armor = ARMOR_DEFAULT, ammo = 4, ammo2 = 3 },
	{ p = "weapon_winchester", s = "weapon_cz75",        armor = ARMOR_DEFAULT, ammo = 4, ammo2 = 2 },
	{ p = "weapon_mini14",     s = "weapon_px4beretta",  atts = {{"holo6"}}, armor = ARMOR_DEFAULT, ammo2 = 2 },

--рофляночка
	{ p = "weapon_hg_bow", armor = {"helmet1"}, ammo = 25, melee = "weapon_pocketknife", noGrenade = true, medicine = {"weapon_bandage_sh"}, medicineCount = 1 },
	{ p = "weapon_hg_bow", armor = {"helmet7"}, ammo = 25, melee = "weapon_pocketknife", noGrenade = true, medicine = {"weapon_bigbandage_sh"}, medicineCount = 1 },
	{ p = "weapon_musket", s = "weapon_flintlock", armor = {"vest2", "helmet1"}, ammo = 10, ammo2 = 6, melee = "weapon_pocketknife", randomMedicine = true },
	{ p = "weapon_musket", s = "weapon_flintlock", armor = {"vest3"}, ammo = 12, ammo2 = 8, melee = "weapon_pocketknife", randomMedicine = true },
	{ p = "weapon_ptrd",       armor = {}, ammo = 12 },
}

local randomGrenades = {"weapon_hg_rgd_tpik", "weapon_hg_pipebomb_tpik", "weapon_hg_smokenade_tpik", "weapon_hg_flashbang_tpik"}
local randomMedicine = {"weapon_bandage_sh", "weapon_bigbandage_sh", "weapon_medkit_sh", "weapon_fentanyl", "weapon_morphine", "weapon_adrenaline", "weapon_tourniquet"}
local randomMelees = {"weapon_melee", "weapon_pocketknife"}

local function MakeDissolver(ent, position, dissolveType)
    local Dissolver = ents.Create("env_entity_dissolver")
    timer.Simple(5, function()
        if IsValid(Dissolver) then Dissolver:Remove() end
    end)
	if not IsValid(Dissolver) then return end
    Dissolver.Target = "dissolve" .. ent:EntIndex()
    Dissolver:SetKeyValue("dissolvetype", dissolveType)
    Dissolver:SetKeyValue("magnitude", 0)
    Dissolver:SetPos(position)
    Dissolver:SetPhysicsAttacker(ent)
    Dissolver:Spawn()
    ent:SetName(Dissolver.Target)
	ent:Fire("Open")
    Dissolver:Fire("Dissolve", Dissolver.Target, 0)
    Dissolver:Fire("Kill", "", 0.1)
    return Dissolver
end

function MODE:RoundStart()
	local loadout = loadouts[math.random(#loadouts)]

	local rawAtts = loadout.atts or loadout.attachments
	local selectedAttachments
	if istable(rawAtts) and #rawAtts > 0 then
		selectedAttachments = table.Random(rawAtts)
	else
		selectedAttachments = rawAtts
	end

	local primaryClass  = loadout.p or loadout.primary
	local primaryAmmo   = loadout.ammo or 3
	local armorList     = loadout.armor or ARMOR_DEFAULT
	local meleeWeapon   = loadout.melee or randomMelees[math.random(#randomMelees)]
	local secondaryClass = loadout.s or loadout.secondary

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		ply:SetSuppressPickupNotices(true)
		ply.noSound = true
		ply:Give("weapon_hands_sh")

		local inv = ply:GetNetVar("Inventory")
		inv["Weapons"]["hg_sling"] = true
		ply:SetNetVar("Inventory", inv)
		
		local gun = ply:Give(primaryClass)
		if IsValid(gun) then
			ply:GiveAmmo(gun:GetMaxClip1() * primaryAmmo, gun:GetPrimaryAmmoType(), true)
			if selectedAttachments and selectedAttachments ~= "" then
				hg.AddAttachmentForce(ply, gun, selectedAttachments)
			end
		end

		if secondaryClass then
			local pistol = ply:Give(secondaryClass)
			if IsValid(pistol) then
				ply:GiveAmmo(pistol:GetMaxClip1() * (loadout.ammo2 or 2), pistol:GetPrimaryAmmoType(), true)
			end
		end

		hg.AddArmor(ply, armorList)
		ply:Give(meleeWeapon)

		if not loadout.noGrenade then
			local grenadeCount = math.random(1, 2)
			local usedGrenades = {}
			for i = 1, grenadeCount do
				local grenade = randomGrenades[math.random(#randomGrenades)]
				while usedGrenades[grenade] and i > 1 do
					grenade = randomGrenades[math.random(#randomGrenades)]
				end
				usedGrenades[grenade] = true
				ply:Give(grenade)
			end
		end

		if loadout.medicine then
			for i = 1, (loadout.medicineCount or 1) do
				ply:Give(loadout.medicine[math.random(#loadout.medicine)])
			end
		elseif loadout.randomMedicine then
			for i = 1, math.random(1, 2) do
				ply:Give(randomMedicine[math.random(#randomMedicine)])
			end
		else
			ply:Give("weapon_bandage_sh")
			ply:Give("weapon_tourniquet")
		end

		ply:Give("weapon_walkie_talkie")
		ply:SelectWeapon("weapon_hands_sh")

		if ply.organism then ply.organism.recoilmul = 0.5 end

		timer.Simple(0.1, function() ply.noSound = false end)
		ply:SetSuppressPickupNotices(false)
		zb.GiveRole(ply, "Fighter", Color(190, 15, 15))
		ply:SetNetVar("CurPluv", "pluvboss")
	end
end

local cooldown = CurTime()
hook.Add("Think", "bober", function(ply)
	local rnd = CurrentRound()
	if not rnd or rnd.name ~= "dm" then return end
	if (zb.ROUND_START or CurTime()) + 20 > CurTime() then return end
	if cooldown > CurTime() then return end
	if deathmatch_nozone:GetBool() then return end
	cooldown = CurTime() + 0.5

	local pos = zonepoint
	local radius = MODE.GetZoneRadius()
	local radiussqr = radius * radius
	
	for i, ent in ents.Iterator() do
		if pos:DistToSqr(ent:GetPos()) > radiussqr then
			if ent:IsPlayer() then
				hg.LightStunPlayer(ent)
				continue
			end

			if hgIsDoor(ent) then
				if not ent:GetNoDraw() then
					hgBlastThatDoor(ent)
				end
				continue
			end
			
			if string.find(ent:GetClass(), "prop_") and not hg.expItems[ent:GetModel()] then
				MakeDissolver(ent, ent:GetPos(), 0)
			end
		end
	end
end)

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

function MODE:RoundThink()
end

function MODE:PlayerDeath(ply)
	if zb.ROUND_STATE == 1 then
		ply:GiveSkill(-0.1)
	end
end

function MODE:CanSpawn()
end

function MODE:EndRound()
	local playersharm = {}
	for ply, tbl in pairs(zb.HarmDone) do
		for attacker, harm in pairs(tbl) do
			playersharm[attacker] = (playersharm[attacker] or 0) + harm
		end
	end

	local most_violent_player
	local curharm = 0
	for ply, harm in pairs(playersharm) do
		if harm > curharm then
			most_violent_player = ply
			curharm = harm
		end
	end

	timer.Simple(2, function()
		net.Start("dm_end")
		local ent = zb:CheckAlive(true)[1]
		
		if IsValid(ent) then
			ent:GiveExp(math.random(150, 200))
			ent:GiveSkill(math.Rand(0.2, 0.3))
		end

		if IsValid(most_violent_player) then
			most_violent_player:GiveExp(math.random(150, 200))
			most_violent_player:GiveSkill(math.Rand(0.2, 0.3))
		end

		net.WriteEntity(IsValid(ent) and ent:Alive() and ent or NULL)
		net.WriteEntity(IsValid(most_violent_player) and most_violent_player or NULL)
		net.Broadcast()
	end)
end