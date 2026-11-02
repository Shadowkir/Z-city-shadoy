AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("StationaryGun_ShootFX")
util.AddNetworkString("StationaryGun_Punch")

function ENT:Initialize()
	self:SetModel(self.Model or self.MDL)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(self.Mass or 150)
		phys:Wake()
		phys:EnableMotion(true)
	end

	self:SetAmmoCount(self.MaxAmmo)
	self:SetNextShootTime(0)
	self:SetIsReloading(false)

	self.NextReloadAttempt = 0
	self.LastReloadKey = false
end

function ENT:TakeGunnerAmmo(ply, amount)
	if not IsValid(ply) or amount <= 0 then return 0 end

	local ammoID = self:GetAmmoID()
	local currentAmmo = self:GetGunnerAmmo(ply)
	if currentAmmo <= 0 then return 0 end

	local toTake = math.min(currentAmmo, amount)
	local remaining = currentAmmo - toTake

	if ammoID > 0 then
		ply:SetAmmo(remaining, ammoID)
	else
		local cal = self.AmmoCaliber or "12.7x108 mm"
		ply:SetAmmo(remaining, cal)
	end

	if ply.inventory and istable(ply.inventory) then
		ply.inventory.Ammo = ply:GetAmmo()
		if ply.SetNetVar then
			ply:SetNetVar("Inventory", ply.inventory)
		end
	end

	return toTake
end

function ENT:CancelReload()
	local timerID = "StationaryGun_Reload_" .. self:EntIndex()
	if timer.Exists(timerID) then
		timer.Remove(timerID)
	end

	self:StopSound(self.SoundReload)
	self:StopSound(self.SoundEmpty)
	self:SetIsReloading(false)
	self.NextReloadAttempt = CurTime() + 0.3
end

function ENT:Use(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local gunner = self:GetGunner()
	if IsValid(gunner) then
		if gunner == ply then
			self:ReleaseGunner()
		end
		return
	end

	local forward = self:GetForward()
	local toPly = (ply:GetPos() - self:GetPos()):GetNormalized()
	if forward:Dot(toPly) > -0.2 then return end

	local handlePos = self:LocalToWorld(self.GunnerOffset or Vector(-38, 0, 0))
	if ply:GetPos():DistToSqr(handlePos) > (25 * 25) then return end

	self:SetGunner(ply)
	ply:SetNWEntity("ActiveStationaryGun", self)

	self:EmitSound(self.SoundMount, 65, 100)
end

function ENT:ReleaseGunner()
	local gunner = self:GetGunner()
	if not IsValid(gunner) then return end

	self:CancelReload()
	gunner:SetNWEntity("ActiveStationaryGun", NULL)
	self:SetGunner(NULL)

	self:EmitSound(self.SoundDismount, 65, 100)
end

function ENT:StartTouch(ent)
	if not IsValid(ent) then return end
	if self.RefillAmmoClasses and self.RefillAmmoClasses[ent:GetClass()] then
		local current = self:GetAmmoCount()
		if current < self.MaxAmmo then
			local count = ent.AmmoCount or 20
			local needed = self.MaxAmmo - current
			local taken = math.min(needed, count)

			self:SetAmmoCount(current + taken)
			self:EmitSound(self.SoundReload, 65, 110)

			if count - taken <= 0 then
				ent:Remove()
			else
				ent.AmmoCount = count - taken
			end
		end
	end
end

function ENT:FireGunBullet(gunner)
	self:SetNextShootTime(CurTime() + self.FireRate)
	self.LastShootTime = CurTime()
	self:SetAmmoCount(self:GetAmmoCount() - 1)

	local muzzleAtt = self:LookupAttachment("muzzle")
	if muzzleAtt <= 0 then muzzleAtt = self:LookupAttachment("muzzle_1") end
	if muzzleAtt <= 0 then muzzleAtt = 1 end

	local att = self:GetAttachment(muzzleAtt)
	local shootOrigin = att and att.Pos or self:LocalToWorld(Vector(65, 0, 16))

	local shootDir = att and att.Ang:Forward() or self:GetForward()
	local bulletSpeed = self.BulletSpeed or 820

	local bulletData = {
		Src = shootOrigin, pos = shootOrigin,
		Dir = shootDir, dir = shootDir,
		vel = shootDir * (bulletSpeed * 39.37),
		Spread = self.Spread, spread = self.Spread,
		Force = self.Force, force = self.Force,
		Damage = self.Damage, damage = self.Damage,
		Attacker = gunner, attacker = gunner,
		Inflictor = self, inflictor = self,
		Penetration = self.Penetration, penetration = self.Penetration,
		Caliber = self.AmmoCaliber, caliber = self.AmmoCaliber,
		Diameter = self.Diameter, diameter = self.Diameter,
		Speed = bulletSpeed, speed = bulletSpeed,
		Tracer = 1, tracer = 1, TracerName = "Tracer",
		filter = {self, gunner}
	}

	bulletData.Callback = function(attk, tr, dmginfo)
		dmginfo:SetDamageType(DMG_BULLET)
		if hg and hg.bulletHit then
			hg.bulletHit(attk, tr, dmginfo, bulletData)
		end
	end
	bulletData.callback = bulletData.Callback

	local bulletSpawned = false
	if hg and hg.PhysBullet and isfunction(hg.PhysBullet.CreateBullet) then
		local ok = pcall(hg.PhysBullet.CreateBullet, bulletData)
		if ok then bulletSpawned = true end
	end

	if not bulletSpawned then
		self:FireBullets(bulletData)
	end

	self:EmitSound(self.SoundFire, 130, math.random(102, 108), 1, CHAN_WEAPON)
	util.ScreenShake(shootOrigin, self.ScreenShakeAmp or 7.0, 45, 0.22, self.ScreenShakeDist or 700)

	local pPitch = self.RecoilPunchPitch or {-4.2, -3.2}
	local pYaw = self.RecoilPunchYaw or {-1.2, 1.2}
	net.Start("StationaryGun_Punch")
		net.WriteAngle(Angle(
			math.Rand(pPitch[1], pPitch[2]),
			math.Rand(pYaw[1], pYaw[2]),
			math.Rand(-0.6, 0.6)
		))
	net.Send(gunner)

	local cPitch = self.RecoilClimbPitch or {0.65, 1.0}
	local cYaw = self.RecoilClimbYaw or {-0.25, 0.25}
	local curEye = gunner:EyeAngles()
	gunner:SetEyeAngles(Angle(
		math.Clamp(curEye.p - math.Rand(cPitch[1], cPitch[2]), -89, 89),
		curEye.y + math.Rand(cYaw[1], cYaw[2]),
		0
	))

	net.Start("StationaryGun_ShootFX")
		net.WriteEntity(self)
		net.WriteVector(shootOrigin)
	net.Broadcast()
end

function ENT:ReloadWeapon(gunner)
	if self:GetIsReloading() then return end
	if CurTime() < (self.NextReloadAttempt or 0) then return end
	if self:GetAmmoCount() >= self.MaxAmmo then return end

	local availableAmmo = self:GetGunnerAmmo(gunner)

	if availableAmmo <= 0 then
		self.NextReloadAttempt = CurTime() + 1.0
		self:EmitSound(self.SoundEmpty, 65, 100)
		return
	end

	self.NextReloadAttempt = CurTime() + 3.6
	self:SetIsReloading(true)
	self:EmitSound(self.SoundReload, 70, 95)

	local timerID = "StationaryGun_Reload_" .. self:EntIndex()
	timer.Create(timerID, 3.5, 1, function()
		if not IsValid(self) then return end

		self:SetIsReloading(false)

		local currentGunner = self:GetGunner()
		if not IsValid(currentGunner) or currentGunner ~= gunner then return end

		local currentAmmo = self:GetAmmoCount()
		local needed = self.MaxAmmo - currentAmmo

		local taken = self:TakeGunnerAmmo(gunner, needed)
		if taken > 0 then
			self:SetAmmoCount(currentAmmo + taken)
			self:EmitSound(self.SoundReloadEnd, 65, 115)
		end
	end)
end

function ENT:Think()
	local gunner = self:GetGunner()

	if IsValid(gunner) then
		local handlePos = self:LocalToWorld(self.GunnerOffset or Vector(-38, 0, 0))

		if not gunner:Alive() or (gunner.organism and gunner.organism.otrub) or gunner:GetPos():DistToSqr(handlePos) > (25 * 25) then
			self:CancelReload()
			self:ReleaseGunner()
			return
		end

		if gunner.organism then
			gunner.organism.adrenaline = 0
		end

		self:UpdateTurretPose(gunner)

		local reloadKey = gunner:KeyDown(IN_RELOAD)
		if reloadKey and not self.LastReloadKey and not self:GetIsReloading() then
			self:ReloadWeapon(gunner)
		end
		self.LastReloadKey = reloadKey

		if gunner:KeyDown(IN_ATTACK) and not self:GetIsReloading() then
			if CurTime() >= self:GetNextShootTime() then
				if self:GetAmmoCount() > 0 then
					self:FireGunBullet(gunner)
				else
					if CurTime() >= (self.NextEmptySound or 0) then
						self:EmitSound(self.SoundEmpty, 65, 100)
						self.NextEmptySound = CurTime() + 0.35
					end
					self:SetNextShootTime(CurTime() + 0.3)
				end
			end
		end
	else
		self.LastReloadKey = false
	end

	self:NextThink(CurTime())
	return true
end

function ENT:OnRemove()
	self:CancelReload()
	self:ReleaseGunner()
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos + tr.HitNormal * 2)
	ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
	ent:Spawn()
	return ent
end