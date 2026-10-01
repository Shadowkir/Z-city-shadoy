local CLASS_RU = player.RegClass("russiansoldier")

function CLASS_RU.Off(self)
    if CLIENT then return end
end

local rusnames = {
    "Кирилл", "Иван", "Игорь", "Владислав", "Святослав", "Владимир",
    "Евгений", "Дмитрий", "Александр", "Егор", "Роман", "Ярослав",
    "Михаил", "Арсений", "Фёдор", "Матвей", "Максим", "Никита"
}

local models_ru = {
    "models/dejtriyev/smo/zuperzoldat.mdl",
}

function CLASS_RU.On(self)
    if CLIENT then return end

    if isfunction(ApplyAppearance) then
        ApplyAppearance(self, nil, nil, nil, true)
    end
    
    local Appearance = self.CurAppearance or (hg and hg.Appearance and hg.Appearance.GetRandomAppearance and hg.Appearance.GetRandomAppearance()) or {}

    self:SetPlayerColor(Color(25, 90, 0):ToVector())
    self:SetModel(models_ru[math.random(#models_ru)])
    self:SetNWString("PlayerName", rusnames[math.random(#rusnames)])

    Appearance.AAttachments = ""
    Appearance.AColthes = ""
    Appearance.Attachmets = "none"
    Appearance.ClothesStyle = ""
    self:SetNetVar("Accessories", "none")

    self:SetSubMaterial()
    self.CurAppearance = Appearance
end
-- Я вам устрою СВО