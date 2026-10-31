local customEffects = {
    
    "time_dilation_vfx",
    "time_dilation_vfx_outlines",
    "time_dilation_vfx_flash",
    "time_dilation_vfx_radial_blur"
}

local timeDilationVisualEffects = {
    "time_dilation_vfx",
    "time_dilation_vfx_outlines",
    "time_dilation_vfx_flash",
    "time_dilation_vfx_radial_blur",
    "berserk",
    "stagger_effect"
}

local effectExits = function(effects, effectName)
    for _, effect in pairs(effects) do
        if effect.effectName == effectName then
            return true
        end
    end

    return false
end

---@param player PlayerPuppet
local initCustomEffects = function(player)
    ---@diagnostic disable-next-line: undefined-field
    local effects = player:FindComponentByName("fx_player").effectDescs

    for _, effect in pairs(customEffects) do
        local effectName = CName.new(effect)
        local effectPath = "base\\fx\\player\\" .. effect .. ".effect"

        if not effectExits(effects, effectName) then
            local customEffect = entEffectDesc.new()
            --- @diagnostic disable-next-line: assign-type-mismatch
            customEffect.effect = effectPath
            customEffect.effectName = effectName

            table.insert(effects, customEffect)
        end
    end

    ---@diagnostic disable-next-line: inject-field
    player:FindComponentByName("fx_player").effectDescs = effects
end

local applyTimeDilationVisualEffects = function()
    local player = Game.GetPlayer()
    for _, effect in pairs(timeDilationVisualEffects) do
        --- @diagnostic disable-next-line: missing-parameter
        GameObjectEffectHelper.StartEffectEvent(player, CName.new(effect), true)
    end
end

local removeTimeDilationVisualEffects = function()
    local player = Game.GetPlayer()
    for _, effect in pairs(timeDilationVisualEffects) do
        GameObjectEffectHelper.BreakEffectLoopEvent(player, CName.new(effect))
    end
end

local onInit = function()
    -- adds custom time dilation effect to player's fx_player component
    Observe("PlayerPuppet", "PlayerAttachedCallback", initCustomEffects)

    -- disable default Sandevistan and Kerenzikov vfx
    --- @diagnostic disable-next-line: param-type-mismatch
    TweakDB:SetFlat("playerStateMachineTimeDilation.timeDilationAcceptedReasons.sandevistanEffectReasons", { "none" })
    --- @diagnostic disable-next-line: param-type-mismatch
    TweakDB:SetFlat("playerStateMachineTimeDilation.timeDilationAcceptedReasons.kereznikovEffectReasons", { "none" })

    -- hook to SandevistanEvents to apply/remove custom Sandevistan vfx
    Observe("SandevistanEvents", "OnEnter", applyTimeDilationVisualEffects)
    Observe("SandevistanEvents", "OnExit", removeTimeDilationVisualEffects)
    Observe("SandevistanEvents", "OnForcedExit", removeTimeDilationVisualEffects)

    -- hook to KerenzikovEvents to apply/remove custom Kerenzikov vfx
    Observe("KerenzikovEvents", "OnEnter", applyTimeDilationVisualEffects)
    Observe("KerenzikovEvents", "OnExit", removeTimeDilationVisualEffects)
    Observe("KerenzikovEvents", "OnForcedExit", removeTimeDilationVisualEffects)
end

registerForEvent("onInit", onInit)