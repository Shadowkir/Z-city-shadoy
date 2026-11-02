AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "stationary_turret_base"
ENT.PrintName = "Корд"
ENT.Author = "Shermann Wolf & Degtyarev plant"
ENT.Category = "Zcity Stationary Machine Guns"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Model = "models/sw/ground/kord/kord.mdl"
ENT.IconOverride = "pwb2/vgui/weapons/pkm.png"
ENT.Mass = 160

ENT.MaxAmmo = 150
ENT.AmmoCaliber = "12.7x108 mm"
ENT.FireRate = 0.09
ENT.Damage = 155
ENT.BulletSpeed = 820
ENT.Penetration = 65.0
ENT.Force = 45
ENT.Diameter = 12.7
ENT.Spread = Vector(0.0035, 0.0035, 0)

ENT.PitchMin = -20
ENT.PitchMax = 25
ENT.YawMin   = -35
ENT.YawMax   = 35

ENT.GunnerOffset = Vector(-38, 0, 0)
ENT.SightOffset  = Vector(-10, 0, 18)

ENT.MuzzleScale = 1.7
ENT.ShellEjectOffset = Vector(-1, 9, 25)

ENT.SoundFire       = "homigrad/weapons/rifle/loud_awp3.wav"
ENT.SoundDistFar    = "m249/m249_dist.wav"
ENT.SoundEmpty      = "zcitysnd/sound/weapons/fnfal/handling/fnfal_empty.wav"
ENT.SoundReload     = "weapons/ar2/ar2_reload.wav"
ENT.SoundReloadEnd  = "weapons/ar2/ar2_reload.wav"
ENT.SoundMount      = "homigrad/weapons/draw_hmg.mp3"
ENT.SoundDismount   = "homigrad/weapons/hmg_holster.mp3"

ENT.RecoilPunchPitch = {-4.5, -3.5}
ENT.RecoilPunchYaw   = {-1.5, 1.5}

ENT.RecoilClimbPitch = {0.75, 1.15}
ENT.RecoilClimbYaw   = {-0.3, 0.3}

ENT.ScreenShakeAmp   = 7.5
ENT.ScreenShakeDist  = 750

ENT.EnableHUD = true

ENT.RefillAmmoClasses = {
	["ent_ammo_12.7x108mm"] = true,
	["ent_ammo_127108"] = true
}