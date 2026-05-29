-- ============================================================================
-- GameConfig.lua - 游戏全局配置
-- 所有可调参数集中在此文件，方便 GameJam 期间快速调整
-- ============================================================================

local GameConfig = {}

-- 游戏基本信息
GameConfig.Title = "大杰 GameJam 3D Game"

-- 角色配置
GameConfig.Player = {
    StartPos = Vector3(0, 2, 0),
    -- 预制体（推荐，包含完整模型+材质+动画）
    Prefab = "DefaultMale/DefaultMale.prefab",
    -- FSM 动画状态机
    NormalFSM = "urhox-libs/Animation/FSM/DefaultMale_Normal.fsm",
    -- 物理参数
    CapsuleRadius = 0.7,
    CapsuleHeight = 1.8,
    CapsuleOffset = Vector3(0.0, 0.86, 0.0),
    JumpSpeed = 8.0,
    -- 空中控制 (0=无控制, 0.05=Fall Guys, 0.4=马里奥, 0.6=中等)
    AirControlFactor = 0.4,
    -- 步行模式（true=默认步行按Shift跑步，false=默认跑步）
    EnableWalkMode = true,
}

-- 相机配置
GameConfig.Camera = {
    Distance = 5.0,
    Offset = Vector3(0, 1.7, 0),
    FOV = 45.0,
    NearClip = 0.1,
    FarClip = 300.0,
}

-- 场景配置
GameConfig.Scene = {
    -- 环境光
    AmbientColor = Color(0.4, 0.4, 0.4),
    -- 雾效
    FogColor = Color(0.7, 0.8, 0.9),
    FogStart = 100.0,
    FogEnd = 300.0,
    -- 太阳光
    SunDirection = Vector3(0.6, -1.0, 0.8),
    SunColor = Color(0.8, 0.8, 0.8),
}

-- 游戏玩法配置（根据你的游戏设计修改）
GameConfig.Gameplay = {
    -- TODO: 在这里添加游戏特有的配置参数
    -- 例如：
    -- TimeLimit = 120,        -- 游戏时间限制（秒）
    -- ScorePerItem = 10,      -- 每个道具得分
    -- MaxLives = 3,           -- 最大生命数
}

return GameConfig
