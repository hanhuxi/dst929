local assets =
{
    Asset("ANIM", "anim/armor_wagpunk_01.zip"),
    Asset("ANIM", "anim/armor_wagpunk_02.zip"),
    Asset("ANIM", "anim/armor_wagpunk_03.zip"),
    Asset("ANIM", "anim/armor_wagpunk_04.zip"),
    Asset("ANIM", "anim/armor_wagpunk_05.zip"),
}

local assets_fx =
{
    Asset("ANIM", "anim/armor_wagpunk_01.zip"),
    Asset("ANIM", "anim/armor_wagpunk_02.zip"),
    Asset("ANIM", "anim/armor_wagpunk_03.zip"),
    Asset("ANIM", "anim/armor_wagpunk_04.zip"),
    Asset("ANIM", "anim/armor_wagpunk_05.zip"),
}

local prefabs = {
    "armorwagpunk_fx",
    "wagpunksteam_armor_up",
    "wagpunksteam_armor_down",
    "wagpunk_bits",
}

local AMB_SOUNDNAME = "armorwagpunk_amb"

---------------------------------------------------------------------------------------------

local function KillTargetTask(inst)
    if inst._targettask ~= nil then
        inst._targettask:Cancel()
        inst._targettask = nil
    end

    inst._potencialtarget = nil
end

local function SpawnSteamFX_Internal(inst, prefab)
    if inst:IsValid() and not inst.components.health:IsDead() and not inst.components.freezable:IsFrozen() then
        inst:AddChild(SpawnPrefab(prefab))
    end
end

local function SpawnSteamFX(inst, owner, fx)
    if owner == nil or not owner:IsValid() then return end

    local delay = math.random() * 0.3

    owner:DoTaskInTime(delay, SpawnSteamFX_Internal, fx)
end

local function SpawnBuffFX(inst, owner)
    SpawnSteamFX(inst, owner, "wagpunksteam_armor_up")
end

local function ResetBuff(inst)
    inst:KillTargetTask()

    local owner = inst.components.inventoryitem:GetGrandOwner()

    if owner ~= nil then
        if inst.components.equippable.walkspeedmult > 1 then
            inst:SpawnSteamFX(owner, "wagpunksteam_armor_down")
        end

        owner.SoundEmitter:KillSound(AMB_SOUNDNAME)
    end

    inst.components.equippable.walkspeedmult = 1
    inst.fx.level:set(1)
end

local function SetNewTarget(inst, target, owner)
    if owner == nil or inst.components.equippable == nil then
        return
    end

    if not target.components.health:IsDead() then
        if inst.fx ~= nil then
            inst.fx.level:set(2)
        end

        inst:KillTargetTask()

        if inst.components.targettracker ~= nil then
            if not inst.components.targettracker:IsTracking(target) then
                inst.components.targettracker:TrackTarget(target)
                inst:SpawnBuffFX(owner)

                inst.components.equippable.walkspeedmult = TUNING.ARMORPUNK_SPEED_MULT_STAGE0
            end

            local hat = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)

            if hat ~= nil and hat.components.targettracker ~= nil and not hat.components.targettracker:HasTarget() then
                hat:SetNewTarget(target, owner)
            end
        end
    else
        if inst.fx ~= nil then
            inst.fx.level:set(1)
            owner.SoundEmitter:KillSound(AMB_SOUNDNAME)
        end
    end
end

local function PlayAmbientSound(inst, owner, level)
    if not owner.SoundEmitter:PlayingSound(AMB_SOUNDNAME) then
        owner.SoundEmitter:PlaySound("rifts3/wagpunk_armor/wagpunk_armor_hat_lp", AMB_SOUNDNAME)
    end

    -- TODO(DiogoW): Missing armor sound levels...
    --owner.SoundEmitter:SetParameter(AMB_SOUNDNAME, "param00", level)
end

local function OnAttack(owner, data)
    local armor = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)

    if armor.components.targettracker:IsTracking(data.target) or
        (armor._targettask ~= nil and armor._potencialtarget == data.target)
    then
        return
    end

    armor:KillTargetTask()

    if data.target:IsValid() then
        if armor.components.targettracker:HasTarget() then
            armor.components.targettracker:StopTracking(true)
        end

        armor.fx.level:set(2)
        armor:PlayAmbientSound(owner, 0)

        armor._potencialtarget = data.target
        armor._targettask = armor:DoTaskInTime(2, armor.SetNewTarget, data.target, owner)
    end
end


local function TimeCheck(inst, targettime, lasttime)
    local STAGE1 = TUNING.ARMORPUNK_STAGE1
    local STAGE2 = TUNING.ARMORPUNK_STAGE2
    local STAGE3 = TUNING.ARMORPUNK_STAGE3

    local owner = inst.components.inventoryitem.owner

    if STAGE1 <= targettime and lasttime < STAGE1 then
        inst.fx.level:set(3)
        inst.components.equippable.walkspeedmult = TUNING.ARMORPUNK_SPEED_MULT_STAGE1
        if owner then
            inst:SpawnBuffFX(owner)
            inst:PlayAmbientSound(owner, 0.3)
        end
    end
    if STAGE2 <= targettime and lasttime < STAGE2 then
        inst.fx.level:set(4)
        inst.components.equippable.walkspeedmult = TUNING.ARMORPUNK_SPEED_MULT_STAGE2
        if owner then
            inst:SpawnBuffFX(owner)
            inst:PlayAmbientSound(owner, 0.5)
        end
    end
    if STAGE3 <= targettime and lasttime < STAGE3 then
        inst.fx.level:set(5)
        inst.components.equippable.walkspeedmult = TUNING.ARMORPUNK_SPEED_MULT_STAGE3
        if owner then
            inst:SpawnBuffFX(owner)
            inst:PlayAmbientSound(owner, 0.7)
        end
    end
end

local function ShouldKeepTarget(inst, target)
    return inst:GetDistanceSqToInst(target) <= TUNING.WAGPUNK_MAXRANGE*TUNING.WAGPUNK_MAXRANGE
end

local function OnBlocked(owner)
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
end

local function OnEquip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_wagpunk_01")
    else
        owner.AnimState:OverrideSymbol("swap_body", "armor_wagpunk_01", "swap_body")
    end

    local hat = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)

    if hat ~= nil and hat.components.targettracker ~= nil then
        inst.components.targettracker:CloneTargetFrom(hat, TUNING.WAGPUNK_SYNC_TIME)
    end

    inst:ListenForEvent("blocked",       inst.OnBlocked, owner)
    inst:ListenForEvent("onattackother", inst.OnAttack, owner)

    if inst.fx ~= nil then
        inst.fx:Remove()
    end

    inst.fx = SpawnPrefab("armorwagpunk_fx")
    inst.fx:AttachToOwner(owner)
    inst.fx.level:set(1)
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    inst:RemoveEventCallback("blocked",       inst.OnBlocked, owner)
    inst:RemoveEventCallback("onattackother", inst.OnAttack,  owner)

    inst.components.targettracker:StopTracking()

    if owner ~= nil then
        owner.SoundEmitter:KillSound(AMB_SOUNDNAME)
    end

    if inst.fx ~= nil then
        inst.fx:Remove()
        inst.fx = nil
    end
end

local function UnpauseFn(inst)
    local timetracking = inst.components.targettracker:GetTimeTracking()

    if timetracking ~= nil then
        inst:TimeCheck(timetracking, 0)
    end
end

local function SetupEquippable(inst)
    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
end

local SWAP_DATA_BROKEN = { bank = "armor_wagpunk_01", anim = "broken" }
local SWAP_DATA        = { bank = "armor_wagpunk_01", anim = "anim"   }

local function OnBroken(inst)
    if inst.components.equippable ~= nil then
        inst:RemoveComponent("equippable")
        inst.AnimState:PlayAnimation("broken")
        inst.components.floater:SetSwapData(SWAP_DATA_BROKEN)
        inst:AddTag("broken")
        inst.components.inspectable.nameoverride = "BROKEN_FORGEDITEM"
    end
end

local function OnRepaired(inst)
    if inst.components.equippable == nil then
        SetupEquippable(inst)
        inst.AnimState:PlayAnimation("anim")
        inst.components.floater:SetSwapData(SWAP_DATA)
        inst:RemoveTag("broken")
        inst.components.inspectable.nameoverride = nil
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("armor_wagpunk_01")
    inst.AnimState:SetBuild("armor_wagpunk_01")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("metal") -- Impact sound.
    inst:AddTag("show_broken_ui")

    inst.foleysound = "dontstarve/movement/foley/metalarmour"

    MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, SWAP_DATA)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnAttack  = OnAttack
    inst.OnBlocked = OnBlocked

    inst.TimeCheck = TimeCheck
    inst.KillTargetTask = KillTargetTask
    inst.SpawnSteamFX = SpawnSteamFX
    inst.SpawnBuffFX = SpawnBuffFX
    inst.PlayAmbientSound = PlayAmbientSound

    inst.SetNewTarget = SetNewTarget

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("targettracker")
    inst.components.targettracker:SetOnTimeUpdateFn(TimeCheck)
    inst.components.targettracker:SetOnResetTarget(ResetBuff)
    inst.components.targettracker:SetShouldKeepTrackingFn(ShouldKeepTarget)
    inst.components.targettracker:SetOnResumeFn(UnpauseFn)

    inst:AddComponent("armor")
    inst.components.armor:InitCondition(TUNING.ARMORPUNK, TUNING.ARMORPUNK_ABSORPTION)

    inst:AddComponent("planardefense")
    inst.components.planardefense:SetBaseDefense(TUNING.ARMORPUNK_PLANAR_DEF)

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable.walkspeedmult = 1

    MakeForgeRepairable(inst, FORGEMATERIALS.WAGPUNKBITS, OnBroken, OnRepaired)
    MakeHauntableLaunch(inst)

    return inst
end

------------------------------------------------------------------------

local function CreateFxFollowFrame(i)
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()

    inst:AddTag("FX")

    inst.AnimState:SetBank("armor_wagpunk_01")
    inst.AnimState:SetBuild("armor_wagpunk_01")
    inst.AnimState:PlayAnimation("on"..tostring(i), true)

    inst:AddComponent("highlightchild")

    inst.persists = false

    return inst
end

local function fx_OnRemoveEntity(inst)
    for i, v in ipairs(inst.fx) do
        v:Remove()
    end
end

local function fx_ColourChanged(inst, r, g, b, a)
    for i, v in ipairs(inst.fx) do
        v.AnimState:SetAddColour(r, g, b, a)
    end
end

local function fx_SpawnFxForOwner(inst, owner)
    inst.owner = owner
    inst.wasmoving = false
    inst.fx = {}
    local frame
    for i = 1, 9 do
        local fx = CreateFxFollowFrame(i)
        fx.entity:SetParent(owner.entity)
        fx.Follower:FollowSymbol(owner.GUID, "swap_body", nil, nil, nil, true, nil, i - 1)
        fx.components.highlightchild:SetOwner(owner)
        table.insert(inst.fx, fx)
    end
    inst.components.colouraddersync:SetColourChangedFn(fx_ColourChanged)

    inst.OnRemoveEntity = fx_OnRemoveEntity
end

local function fx_OnEntityReplicated(inst)
    local owner = inst.entity:GetParent()
    if owner ~= nil then
        fx_SpawnFxForOwner(inst, owner)
    end
end

local function fx_AttachToOwner(inst, owner)
    inst.entity:SetParent(owner.entity)
    if owner.components.colouradder ~= nil then
        owner.components.colouradder:AttachChild(inst)
    end
    --Dedicated server does not need to spawn the local fx
    if not TheNet:IsDedicated() then
        fx_SpawnFxForOwner(inst, owner)
    end
end

local function wagpunkarmor_fx_leveldirty(inst)
    if inst.fx ~= nil then
        if inst.level:value() then
            local bank =
                (inst.level:value() == 5 and "armor_wagpunk_05") or
                (inst.level:value() == 4 and "armor_wagpunk_05") or
                (inst.level:value() == 3 and "armor_wagpunk_05") or
                (inst.level:value() == 2 and "armor_wagpunk_05") or
                "armor_wagpunk_01"

            for i, v in ipairs(inst.fx) do
                v.AnimState:SetBank(bank)
            end
        end
    end
end

local function fxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst:AddComponent("colouraddersync")

    inst.level = net_tinybyte(inst.GUID, "wagpunkarmor_fx.level", "wagpunkarmor_leveldirty")
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("wagpunkarmor_leveldirty", wagpunkarmor_fx_leveldirty)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = fx_OnEntityReplicated

        return inst
    end

    inst.AttachToOwner = fx_AttachToOwner
    inst.persists = false

    return inst
end


local function steamon_fxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.AttachToOwner = fx_AttachToOwner
    inst.persists = false

    return inst
end

return Prefab("armorwagpunk", fn, assets, prefabs),
       Prefab("armorwagpunk_fx", fxfn, assets_fx)
