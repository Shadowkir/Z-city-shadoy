SWEP.Base = "weapon_ak74"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "AKS-74"
SWEP.Author = "Izhevsk Machine-Building Plant"
SWEP.Instructions = "Variant of the AK-74 Automatic rifle chambered in 5.45x39 mm\n\nRate of fire 700 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.FakeBodyGroups = "00900030302"
SWEP.WepSelectIcon2 = Material("entities/tfa_ins2_ak74_r.png")
SWEP.WepSelectIcon2box = true
SWEP.IconOverride = "entities/tfa_ins2_ak74_r.png"
SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.01 - math.cos(i) * 0.02, math.cos(i * i) * 0.02, 0) * 2
end

SWEP.Ergonomics = 1.05