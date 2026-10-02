SWEP.PrintName = "Паутинка"
SWEP.Author = "Sadsalat"
SWEP.Instructions = "PRESS FIRE TO SHOOT"
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.Spawnable = true
SWEP.DangerLevel = 70
SWEP.ViewModel = "models/weapons/cstrike/c_smg_ump45.mdl"
SWEP.WorldModel = "models/weapons/w_smg_ump45.mdl"
SWEP.UseHands = true
if CLIENT then
	SWEP.WepSelectIcon = Material("criresp/flaguus.png")
	SWEP.IconOverride = "criresp/flaguus.png"
	SWEP.BounceWeaponIcon = true
end

SWEP.Primary = {
    Automatic = true,
    ClipSize = 0,
    DefaultClip = 0,
    Ammo = "",
}

SWEP.Secondary = {
    Automatic = false,
    ClipSize = 0,
    DefaultClip = 0,
    Ammo = "",
}

function SWEP:PrimaryAttack() end

function SWEP:Think()
    if (self:GetOwner():KeyDown(IN_ATTACK) and !self:GetOwner():KeyPressed(IN_ATTACK)) then
        self:GetOwner():SetVelocity((self.LookSpot - self:GetOwner():GetPos()):GetNormalized() * 25)
    end
    if (self:GetOwner():KeyPressed(IN_ATTACK)) then
        self.LookSpot = self:GetOwner():GetEyeTrace().HitPos
        self:GetOwner():SetVelocity(Vector(0, 0, 250))
    end
end