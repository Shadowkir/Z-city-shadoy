if not SERVER then return end
if not hg then return end

concommand.Add("zb_identity_swap", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end

    local trace = ply:GetEyeTrace().Entity
    -- ply:ChatPrint("hit " .. tostring(trace))
    if not trace:IsPlayer() and not trace:IsRagdoll() then return end
    if trace:IsRagdoll() then
        if not trace.organism.owner:IsPlayer() then return end
        trace = trace.organism.owner end
        -- print("is player") end
    -- ply:ChatPrint("passed ifs")

    trace:Kill()
    ply:Kill()

    targetBody = trace:GetRagdollEntity()
    playerBody = ply:GetRagdollEntity()

    timer.Simple(0.1, function()
        if IsValid(targetBody) and IsValid(playerBody) then
            hg.RespawnIntoBody(trace, playerBody)
            hg.RespawnIntoBody(ply, targetBody)
        end
    end)
end)