-- ============================================================================
-- 大杰 TapTap 广州 GameJam 项目
-- 基于 UrhoX 3D 第三人称角色脚手架
-- ============================================================================

-- 引入工具库
require "LuaScripts/Utilities/Sample"
require "LuaScripts/Utilities/Touch"
require "urhox-libs.UI.GameHUD"
require "urhox-libs.Camera.ThirdPersonCamera"
local UI = require("urhox-libs/UI")

-- 引入游戏模块
local GameConfig = require("GameConfig")
local SceneBuilder = require("SceneBuilder")
local PlayerController = require("PlayerController")

-- ============================================================================
-- 全局变量
-- ============================================================================

---@type Scene
local scene_ = nil
---@type ThirdPersonCameraInstance
local tpCamera_ = nil
---@type CharacterComponent
local character_ = nil
---@type AnimationStateMachine
local stateMachine_ = nil

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    SampleStart()

    -- 创建场景
    scene_ = SceneBuilder.CreateScene()

    -- 创建相机
    tpCamera_ = ThirdPersonCamera.Create(scene_, {
        modes = {
            normal = {
                distance = GameConfig.Camera.Distance,
                offset = GameConfig.Camera.Offset,
                fov = GameConfig.Camera.FOV,
            },
        },
        transitionSpeed = 8.0,
        farClip = GameConfig.Camera.FarClip,
    })
    renderer:SetViewport(0, Viewport:new(scene_, tpCamera_:GetCamera()))

    -- 创建角色
    local playerData = PlayerController.CreatePlayer(scene_)
    character_ = playerData.character
    stateMachine_ = playerData.stateMachine

    -- 创建 UI
    CreateUI()

    -- 创建 GameHUD（摇杆 + 跳跃按钮）
    CreateGameHUD()

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    UnsubscribeFromEvent("SceneUpdate")

    -- 锁定鼠标（第三人称视角控制）
    SampleInitMouseMode(MM_RELATIVE)

    print("=== GameJam Project Started ===")
    print("WASD: 移动 | Shift: 跑步 | Space: 跳跃")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- UI
-- ============================================================================

function CreateUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    local root = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Label {
                id = "instructions",
                text = "WASD: 移动 | Shift: 跑步 | Space: 跳跃",
                fontSize = 12,
                fontColor = { 255, 255, 200, 200 },
                position = "absolute",
                top = 10,
                left = 0,
                right = 0,
                textAlign = "center",
                width = "100%",
            },
        }
    }
    UI.SetRoot(root)
end

function CreateGameHUD()
    GameHUD.Initialize()
    GameHUD.SetControls(character_.controls)

    GameHUD.Create({
        enableJump = true,
        enableRun = true,
        enableShooter = false,  -- 暂不启用射击系统，可后续开启
    })

    -- 移动端触摸视角控制
    GameHUD.EnableTouchLook({
        camera = tpCamera_:GetNode(),
    })
end

-- ============================================================================
-- 事件处理
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if character_ == nil then return end

    -- 触摸输入
    if touchEnabled then
        UpdateTouches(character_.controls)
    end

    -- PC 鼠标视角控制
    if ui.focusElement == nil and not touchEnabled then
        character_.controls.yaw = character_.controls.yaw + input.mouseMoveX * YAW_SENSITIVITY
        character_.controls.pitch = character_.controls.pitch + input.mouseMoveY * YAW_SENSITIVITY
        character_.controls.pitch = Clamp(character_.controls.pitch, -80.0, 80.0)
    end
end

---@param eventType string
---@param eventData PostUpdateEventData
function HandlePostUpdate(eventType, eventData)
    if character_ == nil then return end

    -- 更新动画状态机参数
    if stateMachine_ ~= nil then
        local moveSpeed = character_:GetMoveSpeed()
        local isGrounded = character_:IsOnGround()
        local isJumping = character_:IsJumping()

        if character_:IsJumpStarted() then
            stateMachine_:SetTrigger("jump")
        end

        local effectiveGrounded = isGrounded and not isJumping
        stateMachine_:SetFloat("moveSpeed", moveSpeed)
        stateMachine_:SetBool("isGrounded", effectiveGrounded)
        stateMachine_:SetBool("isJumping", isJumping)
    end

    -- 更新第三人称相机
    local timeStep = eventData["TimeStep"]:GetFloat()
    local characterNode = character_:GetNode()
    tpCamera_:Update(timeStep, characterNode, character_.controls.yaw, character_.controls.pitch)
end
