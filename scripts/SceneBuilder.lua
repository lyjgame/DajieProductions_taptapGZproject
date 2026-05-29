-- ============================================================================
-- SceneBuilder.lua - 场景构建模块
-- 负责创建 3D 场景：地形、灯光、障碍物、道具等
-- ============================================================================

local GameConfig = require("GameConfig")

local SceneBuilder = {}

--- 创建完整场景
---@return Scene
function SceneBuilder.CreateScene()
    local scene = Scene:new()

    -- 基础组件
    scene:CreateComponent("Octree")
    scene:CreateComponent("PhysicsWorld")
    scene:CreateComponent("DebugRenderer")

    -- 灯光
    SceneBuilder.CreateLighting(scene)

    -- 地形
    SceneBuilder.CreateTerrain(scene)

    -- TODO: 添加游戏特有的场景元素
    -- SceneBuilder.CreateCollectibles(scene)
    -- SceneBuilder.CreateObstacles(scene)

    return scene
end

--- 创建灯光系统
---@param scene Scene
function SceneBuilder.CreateLighting(scene)
    -- Zone（环境光 + 雾效）
    local zoneNode = scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.ambientColor = GameConfig.Scene.AmbientColor
    zone.fogColor = GameConfig.Scene.FogColor
    zone.fogStart = GameConfig.Scene.FogStart
    zone.fogEnd = GameConfig.Scene.FogEnd

    -- 太阳光（定向光）
    local lightNode = scene:CreateChild("DirectionalLight")
    lightNode.direction = GameConfig.Scene.SunDirection
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = GameConfig.Scene.SunColor
    light.castShadows = true
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
end

--- 创建地形
---@param scene Scene
function SceneBuilder.CreateTerrain(scene)
    -- 主地板
    SceneBuilder.CreateFloor(scene, Vector3(0, 0, 0), Vector3(50, 1, 50))

    -- 上层平台（示例）
    SceneBuilder.CreateFloor(scene, Vector3(15, 3, 0), Vector3(10, 1, 10))

    -- 斜坡连接
    SceneBuilder.CreateRamp(scene, Vector3(7, 1.5, 0), Vector3(8, 0.5, 4), 20)
end

--- 创建地板
---@param scene Scene
---@param position Vector3
---@param size Vector3
function SceneBuilder.CreateFloor(scene, position, size)
    local node = scene:CreateChild("Floor")
    node.position = position
    node.scale = size

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))

    local body = node:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)

    return node
end

--- 创建斜坡
---@param scene Scene
---@param position Vector3
---@param size Vector3
---@param angle number
function SceneBuilder.CreateRamp(scene, position, size, angle)
    local node = scene:CreateChild("Ramp")
    node.position = position
    node.rotation = Quaternion(angle, Vector3(0, 0, 1))
    node.scale = size

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))

    local body = node:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)

    return node
end

--- 创建一个简单的 Box 道具（模板方法，可扩展）
---@param scene Scene
---@param position Vector3
---@param size Vector3
---@param color Color|nil
---@return Node
function SceneBuilder.CreateBox(scene, position, size, color)
    local node = scene:CreateChild("Box")
    node.position = position
    node.scale = size or Vector3(1, 1, 1)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    if color then
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(color))
        mat:SetShaderParameter("Roughness", Variant(0.7))
        mat:SetShaderParameter("Metallic", Variant(0.0))
        model:SetMaterial(mat)
    else
        model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))
    end

    return node
end

return SceneBuilder
