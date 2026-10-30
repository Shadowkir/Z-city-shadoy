ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Base Stationary Gun"
ENT.Author = "ZCity / Homigrad"
ENT.Category = "Stationary Guns"
ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.Model = "models/sw/ground/kord/kord.mdl"
ENT.Mass = 150

-- Боезапас и баллистика
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
ENT.YawMin = -25
ENT.YawMax = 25

ENT.GunnerOffset = Vector(-40, 0, 0)
ENT.ExitOffset = Vector(-70, 0, 5)
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
ENT.ViewKickBack     = 3.5
ENT.ViewKickPitch    = 1.6

ENT.EnableHUD = true
ENT.HUD_AmmoIcon = "vgui/hud/127108.png"

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

function ENT:GetGunnerAmmo(ply)
	if not IsValid(ply) then return 0 end
	local cal = self.AmmoCaliber or "12.7x108 mm"
	local altCal = string.Replace(cal, " ", "")

	if ply.inventory and istable(ply.inventory.Ammo) then
		if ply.inventory.Ammo[cal] and ply.inventory.Ammo[cal] > 0 then
			return ply.inventory.Ammo[cal]
		elseif ply.inventory.Ammo[altCal] and ply.inventory.Ammo[altCal] > 0 then
			return ply.inventory.Ammo[altCal]
		end
	end

	local netInv = ply.GetNetVar and ply:GetNetVar("Inventory")
	if istable(netInv) and istable(netInv.Ammo) then
		if netInv.Ammo[cal] and netInv.Ammo[cal] > 0 then
			return netInv.Ammo[cal]
		elseif netInv.Ammo[altCal] and netInv.Ammo[altCal] > 0 then
			return netInv.Ammo[altCal]
		end
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

hook.Add("CalcMainActivity", "StationaryGun_Base_Anim", function(ply)
	local gun = ply:GetNWEntity("ActiveStationaryGun")
	if IsValid(gun) then
		local seq = ply:LookupSequence("cidle_dual")
		if seq and seq > 0 then
			return ACT_STAND, seq
		end
		return ACT_HL2MP_IDLE_DUAL, -1
	end
end)

hook.Add("StartCommand", "StationaryGun_Base_ControlOverride", function(ply, cmd)
	local gun = ply:GetNWEntity("ActiveStationaryGun")
	if IsValid(gun) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) then
			wep:SetNextPrimaryFire(CurTime() + 0.5)
			wep:SetNextSecondaryFire(CurTime() + 0.5)
		end

		cmd:ClearMovement()

		if cmd:KeyDown(IN_JUMP) then
			if SERVER then
				gun:ReleaseGunner()
			end
		end
	end
end)