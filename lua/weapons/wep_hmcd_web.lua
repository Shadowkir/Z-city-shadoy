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

SWEP.IsWebWeapon = true

function SWEP:PrimaryAttack() end

function SWEP:Think()
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsPlayer() then return end

    if ply:KeyPressed(IN_ATTACK) then
        self.LookSpot = ply:GetEyeTrace().HitPos
        ply:SetVelocity(Vector(0, 0, 250))
    elseif ply:KeyDown(IN_ATTACK) and self.LookSpot then
        ply:SetVelocity((self.LookSpot - ply:GetPos()):GetNormalized() * 25)
    end
end

if SERVER then
    hook.Add("PlayerPostThink", "Web_SyncNoFake", function(ply)
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        local isHolding = IsValid(wep) and wep.IsWebWeapon

        if isHolding then
            ply.NoFakeImmunity = true
            ply.HoldingWebImmunity = true
        elseif ply.HoldingWebImmunity then
            ply.HoldingWebImmunity = nil
            ply.NoFakeImmunity = false
        end
    end)
end