-- ============================================================================
-- PlayerController.lua - 玩家角色模块
-- 负责创建玩家角色：模型、物理、动画、控制器
-- ============================================================================

local GameConfig = require("GameConfig")

local PlayerController = {}

--- 创建玩家角色
---@param scene Scene
---@return table { character: CharacterComponent, stateMachine: AnimationStateMachine, node: Node }
function PlayerController.CreatePlayer(scene)
    local cfg = GameConfig.Player

    -- 角色根节点
    local objectNode = scene:CreateChild("Player")
    objectNode:SetPosition(cfg.StartPos)

    -- 模型节点
    local modelNode = objectNode:CreateChild("ModelNode")

    -- 加载预制体
    local prefabLoaded = false
    if cfg.Prefab then
        local prefabFile = cache:GetResource("XMLFile", cfg.Prefab)
        if prefabFile then
            prefabLoaded = modelNode:LoadXML(prefabFile:GetRoot())
            if prefabLoaded then
                print("[Player] Prefab loaded: " .. cfg.Prefab)
            end
        end
    end

    if not prefabLoaded then
        print("[Player] WARNING: Prefab not found, using fallback")
        local adjustNode = modelNode:CreateChild("AdjustNode")
        adjustNode:SetRotation(Quaternion(180, Vector3(0, 1, 0)))
        local model = adjustNode:CreateComponent("AnimatedModel")
        model:SetModel(cache:GetResource("Model", "Platforms/Models/BetaLowpoly/Beta.mdl"))
        model:SetMaterial(0, cache:GetResource("Material", "Platforms/Materials/BetaBody_MAT.xml"))
        model:SetCastShadows(true)
    end

    -- AnimationController
    modelNode:GetOrCreateComponent("AnimationController")

    -- AnimationStateMachine
    local stateMachine = modelNode:CreateComponent("AnimationStateMachine")
    local fsmFile = cache:GetResource("JSONFile", cfg.NormalFSM)
    if fsmFile then
        stateMachine:LoadFromJSONFile(fsmFile)
        stateMachine:Start()
        print("[Player] FSM started: " .. cfg.NormalFSM)
    else
        print("[Player] WARNING: FSM not found: " .. cfg.NormalFSM)
    end

    -- 刚体
    local body = objectNode:CreateComponent("RigidBody")
    body:SetCollisionLayerAndMask(CollisionLayerCharacter, CollisionMaskCharacter)
    body:SetMass(1)
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    -- 碰撞形状（胶囊体）
    local shape = objectNode:CreateComponent("CollisionShape")
    shape:SetCapsule(cfg.CapsuleRadius, cfg.CapsuleHeight, cfg.CapsuleOffset)

    -- 运动学角色控制器
    local kinematicController = objectNode:CreateComponent("KinematicCharacterController")
    kinematicController:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)
    kinematicController:SetJumpSpeed(cfg.JumpSpeed)

    -- CharacterComponent
    local character = objectNode:CreateComponent("CharacterComponent")
    character:SetAirControlFactor(cfg.AirControlFactor)
    character:SetEnableWalkMode(cfg.EnableWalkMode)

    return {
        character = character,
        stateMachine = stateMachine,
        node = objectNode,
    }
end

return PlayerController
