ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Base Stationary Gun"
ENT.Author = "ZCity / Homigrad"
ENT.Category = "Stationary Guns"
ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.Model = "models/sw/ground/kord/kord.mdl"
ENT.Mass = 150

ENT.MaxAmmo = 100
ENT.AmmoCaliber = "12.7x108 mm"
ENT.FireRate = 0.1
ENT.Damage = 100
ENT.BulletSpeed = 820
ENT.Penetration = 50
ENT.Spread = Vector(0.003, 0.003, 0)
ENT.Force = 40
ENT.Diameter = 12.7

ENT.PitchMin = -20
ENT.PitchMax = 20
ENT.YawMin = -35
ENT.YawMax = 35

ENT.GunnerOffset = Vector(-38, 0, 0)
ENT.SightOffset = Vector(-10, 0, 18)

ENT.SoundFire = "homigrad/weapons/rifle/loud_awp3.wav"
ENT.SoundEmpty = "zcitysnd/sound/weapons/fnfal/handling/fnfal_empty.wav"
ENT.SoundReload = "weapons/ar2/ar2_reload.wav"
ENT.SoundReloadEnd = "weapons/ar2/ar2_reload.wav"
ENT.SoundMount = "homigrad/weapons/draw_hmg.mp3"
ENT.SoundDismount = "homigrad/weapons/hmg_holster.mp3"
ENT.SoundDistFar = "m249/m249_dist.wav"

ENT.RecoilPunchPitch = {-4.2, -3.2}
ENT.RecoilPunchYaw   = {-1.2, 1.2}
ENT.RecoilClimbPitch = {0.65, 1.0}
ENT.RecoilClimbYaw   = {-0.25, 0.25}
ENT.ScreenShakeAmp   = 7.0
ENT.ScreenShakeDist  = 700

ENT.EnableHUD = true

ENT.RefillAmmoClasses = {
	["ent_ammo_12.7x108mm"] = true,
	["ent_ammo_127108"] = true
}

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Gunner")
	self:NetworkVar("Int", 0, "AmmoCount")
	self:NetworkVar("Float", 0, "NextShootTime")
	self:NetworkVar("Bool", 0, "IsReloading")
end

function ENT:GetAmmoID()
	local cal = self.AmmoCaliber or "12.7x108 mm"
	local id = game.GetAmmoID(cal)
	if id and id > 0 then return id end

	local altCal = string.Replace(cal, " ", "")
	id = game.GetAmmoID(altCal)
	if id and id > 0 then return id end

	return -1
end

function ENT:GetGunnerAmmo(ply)
	if not IsValid(ply) then return 0 end

	local ammoID = self:GetAmmoID()
	if ammoID > 0 then
		local count = ply:GetAmmoCount(ammoID)
		if count and count > 0 then return count end
	end

	local cal = self.AmmoCaliber or "12.7x108 mm"
	local altCal = string.Replace(cal, " ", "")

	local countByName = ply:GetAmmoCount(cal)
	if countByName and countByName > 0 then return countByName end

	countByName = ply:GetAmmoCount(altCal)
	if countByName and countByName > 0 then return countByName end

	local inv = ply.inventory or (ply.GetNetVar and ply:GetNetVar("Inventory"))
	if istable(inv) and istable(inv.Ammo) then
		if ammoID > 0 and inv.Ammo[ammoID] and inv.Ammo[ammoID] > 0 then return inv.Ammo[ammoID] end
		if inv.Ammo[cal] and inv.Ammo[cal] > 0 then return inv.Ammo[cal] end
		if inv.Ammo[altCal] and inv.Ammo[altCal] > 0 then return inv.Ammo[altCal] end
	end

	return 0
end

function ENT:UpdateTurretPose(gunner)
	if not IsValid(gunner) then return end

	local aim = self:WorldToLocalAngles(gunner:EyeAngles())
	aim:Normalize()

	local targetPitch = math.Clamp(-aim.p, self.PitchMin, self.PitchMax)
	local targetYaw = math.Clamp(aim.y, self.YawMin, self.YawMax)

	self:SetPoseParameter("pitch", targetPitch)
	self:SetPoseParameter("yaw", targetYaw)
end

hook.Add("StartCommand", "StationaryGun_Base_ControlOverride", function(ply, cmd)
	local gun = ply:GetNWEntity("ActiveStationaryGun")
	if IsValid(gun) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) then
			wep:SetNextPrimaryFire(CurTime() + 0.5)
			wep:SetNextSecondaryFire(CurTime() + 0.5)
		end
	end
end)