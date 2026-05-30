-- ============================================================================
-- GameScene.lua - 单人点球大战游戏场景
-- 视角：从射手身后看向球门（2D 正面视角）
-- 渲染：NanoVG 自定义绘制
-- ============================================================================

local UI = require("urhox-libs/UI")

local GameScene = {}

-- ============================================================================
-- 游戏状态
-- ============================================================================
local STATE = {
    READY = "ready",          -- 准备射门（可以瞄准）
    SHOOTING = "shooting",    -- 球飞行中
    GOAL = "goal",            -- 进球
    SAVED = "saved",          -- 被扑出
    OPPONENT = "opponent",    -- 对手射门阶段
    ROUND_END = "round_end", -- 一轮结束
}

-- 游戏数据
local game = {
    state = STATE.READY,
    round = 1,
    maxRounds = 5,
    playerScore = 0,
    opponentScore = 0,

    -- 球的位置和运动
    ball = { x = 0.5, y = 0.85 },    -- 归一化坐标 (0-1)
    ballTarget = { x = 0.5, y = 0.3 }, -- 射门目标
    ballProgress = 0,                  -- 球飞行进度 0-1

    -- 守门员
    keeper = { x = 0.5, y = 0.32 },   -- 守门员位置
    keeperTarget = { x = 0.5 },        -- 扑救目标

    -- 瞄准
    aimX = 0.5,   -- 瞄准位置 (0-1 水平)
    aimY = 0.35,  -- 瞄准位置 (垂直)

    -- 计时
    timer = 0,
    stateTimer = 0,
}

-- 颜色
local C = {
    pitch = { 34, 120, 50, 255 },
    pitchDark = { 28, 100, 42, 255 },
    pitchLine = { 255, 255, 255, 180 },
    goal = { 255, 255, 255, 255 },
    goalNet = { 200, 200, 200, 80 },
    ball = { 255, 255, 255, 255 },
    ballShadow = { 0, 0, 0, 60 },
    keeper = { 255, 220, 50, 255 },
    keeperBody = { 30, 30, 30, 255 },
    aim = { 255, 60, 60, 180 },
    hudBg = { 0, 0, 0, 160 },
    textWhite = { 255, 255, 255, 255 },
    textGold = { 255, 210, 60, 255 },
}

-- 屏幕尺寸（在渲染时更新）
local screenW, screenH = 0, 0

-- ============================================================================
-- NanoVG 上下文
-- ============================================================================
local vg = nil
local fontCreated = false

-- ============================================================================
-- 初始化
-- ============================================================================

function GameScene.Init()
    -- 创建独立的 NanoVG 上下文（与 UI 系统并行使用）
    vg = nvgCreate(1 + 2 + 4)

    -- 创建字体（只创建一次）
    if not fontCreated then
        nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
        fontCreated = true
    end

    -- 重置游戏状态
    GameScene.ResetGame()

    -- 订阅 NanoVG 渲染事件（用于自定义绘制）
    SubscribeToEvent("NanoVGRender", "HandleGameRender")
    -- 订阅输入事件
    SubscribeToEvent("Update", "HandleGameUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleGameMouseDown")
    SubscribeToEvent("TouchBegin", "HandleGameTouchBegin")

    print("[GameScene] Initialized")
end

function GameScene.Shutdown()
    UnsubscribeFromEvent("NanoVGRender")
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("MouseButtonDown")
    UnsubscribeFromEvent("TouchBegin")
end

function GameScene.ResetGame()
    game.state = STATE.READY
    game.round = 1
    game.playerScore = 0
    game.opponentScore = 0
    game.ball = { x = 0.5, y = 0.85 }
    game.ballProgress = 0
    game.keeper = { x = 0.5, y = 0.32 }
    game.aimX = 0.5
    game.aimY = 0.35
    game.timer = 0
    game.stateTimer = 0
end

-- ============================================================================
-- 游戏逻辑更新
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleGameUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    game.timer = game.timer + dt
    game.stateTimer = game.stateTimer + dt

    if game.state == STATE.READY then
        -- 瞄准阶段：光标轻微摆动（增加难度）
        -- 玩家通过点击/触摸确定射门方向

    elseif game.state == STATE.SHOOTING then
        -- 球飞行动画（慢动作效果）
        local speed = 1.2  -- 慢动作速度
        game.ballProgress = game.ballProgress + dt * speed

        -- 更新球的位置（从起点到目标的插值）
        local t = math.min(game.ballProgress, 1.0)
        -- 使用缓动函数让球运动更自然
        local easeT = 1 - (1 - t) * (1 - t)
        game.ball.x = Lerp(0.5, game.ballTarget.x, easeT)
        game.ball.y = Lerp(0.85, game.ballTarget.y, easeT)

        -- 守门员扑救动画
        local keeperT = math.min(game.stateTimer * 1.5, 1.0)
        game.keeper.x = Lerp(0.5, game.keeperTarget.x, keeperT)

        -- 判定结果
        if game.ballProgress >= 1.0 then
            local dx = math.abs(game.ball.x - game.keeper.x)
            if dx < 0.08 then
                -- 被扑出
                game.state = STATE.SAVED
            else
                -- 进球
                game.state = STATE.GOAL
                game.playerScore = game.playerScore + 1
            end
            game.stateTimer = 0
        end

    elseif game.state == STATE.GOAL or game.state == STATE.SAVED then
        -- 显示结果 2 秒后进入下一轮
        if game.stateTimer > 2.0 then
            GameScene.NextRound()
        end

    elseif game.state == STATE.OPPONENT then
        -- 对手射门阶段（AI 自动）
        if game.stateTimer > 1.5 then
            -- AI 射门结果（60% 进球概率）
            if math.random() < 0.6 then
                game.opponentScore = game.opponentScore + 1
                game.state = STATE.GOAL
            else
                game.state = STATE.SAVED
            end
            game.stateTimer = 0
        end
    end
end

function GameScene.NextRound()
    if game.state == STATE.GOAL or game.state == STATE.SAVED then
        -- 切换到对手射门或下一轮
        if game.round <= game.maxRounds then
            -- 重置球和守门员
            game.ball = { x = 0.5, y = 0.85 }
            game.ballProgress = 0
            game.keeper = { x = 0.5, y = 0.32 }
            game.aimX = 0.5
            game.state = STATE.READY
            game.stateTimer = 0
            game.round = game.round + 1
        else
            game.state = STATE.ROUND_END
            game.stateTimer = 0
        end
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleGameMouseDown(eventType, eventData)
    if game.state ~= STATE.READY then return end

    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        -- 获取鼠标位置作为射门目标
        local mx = input.mousePosition.x
        local my = input.mousePosition.y
        local dpr = graphics:GetDPR()
        local w = graphics:GetWidth() / dpr
        local h = graphics:GetHeight() / dpr

        GameScene.Shoot(mx / w, my / h)
    end
end

---@param eventType string
---@param eventData TouchBeginEventData
function HandleGameTouchBegin(eventType, eventData)
    if game.state ~= STATE.READY then return end

    local tx = eventData["X"]:GetInt()
    local ty = eventData["Y"]:GetInt()
    local dpr = graphics:GetDPR()
    local w = graphics:GetWidth() / dpr
    local h = graphics:GetHeight() / dpr

    GameScene.Shoot(tx / dpr / w, ty / dpr / h)
end

function GameScene.Shoot(normalizedX, normalizedY)
    -- 限制射门范围在球门区域内
    game.ballTarget.x = Clamp(normalizedX, 0.2, 0.8)
    game.ballTarget.y = Clamp(normalizedY, 0.18, 0.45)

    -- 守门员随机选择扑救方向
    local keeperChoices = { 0.3, 0.4, 0.5, 0.6, 0.7 }
    game.keeperTarget.x = keeperChoices[math.random(1, #keeperChoices)]

    -- 切换到射门状态
    game.state = STATE.SHOOTING
    game.ballProgress = 0
    game.stateTimer = 0

    print("[GameScene] Shoot! Target: " .. string.format("%.2f, %.2f", game.ballTarget.x, game.ballTarget.y))
end

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================

function HandleGameRender(eventType, eventData)
    if vg == nil then return end

    local dpr = graphics:GetDPR()
    screenW = graphics:GetWidth() / dpr
    screenH = graphics:GetHeight() / dpr

    nvgBeginFrame(vg, screenW, screenH, dpr)

    -- 绘制场景
    DrawPitch()
    DrawGoal()
    DrawKeeper()
    DrawBall()
    DrawAim()
    DrawHUD()
    DrawStateMessage()

    nvgEndFrame(vg)
end

--- 绘制球场草地
function DrawPitch()
    -- 渐变绿色草地
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    local paint = nvgLinearGradient(vg, 0, 0, 0, screenH, 
        nvgRGBA(C.pitch[1], C.pitch[2], C.pitch[3], C.pitch[4]),
        nvgRGBA(C.pitchDark[1], C.pitchDark[2], C.pitchDark[3], C.pitchDark[4]))
    nvgFillPaint(vg, paint)
    nvgFill(vg)

    -- 草地条纹
    nvgBeginPath(vg)
    for i = 0, 8 do
        local y = (screenH / 9) * i
        nvgRect(vg, 0, y, screenW, screenH / 18)
    end
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 8))
    nvgFill(vg)

    -- 禁区线
    local boxLeft = screenW * 0.2
    local boxRight = screenW * 0.8
    local boxTop = screenH * 0.15
    local boxBottom = screenH * 0.6

    nvgBeginPath(vg)
    nvgRect(vg, boxLeft, boxTop, boxRight - boxLeft, boxBottom - boxTop)
    nvgStrokeColor(vg, nvgRGBA(C.pitchLine[1], C.pitchLine[2], C.pitchLine[3], C.pitchLine[4]))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 罚球点
    nvgBeginPath(vg)
    nvgCircle(vg, screenW * 0.5, screenH * 0.75, 4)
    nvgFillColor(vg, nvgRGBA(C.pitchLine[1], C.pitchLine[2], C.pitchLine[3], C.pitchLine[4]))
    nvgFill(vg)
end

--- 绘制球门
function DrawGoal()
    local goalLeft = screenW * 0.25
    local goalRight = screenW * 0.75
    local goalTop = screenH * 0.15
    local goalBottom = screenH * 0.38
    local postWidth = 5

    -- 球网背景
    nvgBeginPath(vg)
    nvgRect(vg, goalLeft, goalTop, goalRight - goalLeft, goalBottom - goalTop)
    nvgFillColor(vg, nvgRGBA(C.goalNet[1], C.goalNet[2], C.goalNet[3], C.goalNet[4]))
    nvgFill(vg)

    -- 网格线
    nvgStrokeColor(vg, nvgRGBA(200, 200, 200, 40))
    nvgStrokeWidth(vg, 1)
    -- 竖线
    for i = 1, 9 do
        local x = goalLeft + (goalRight - goalLeft) * (i / 10)
        nvgBeginPath(vg)
        nvgMoveTo(vg, x, goalTop)
        nvgLineTo(vg, x, goalBottom)
        nvgStroke(vg)
    end
    -- 横线
    for i = 1, 4 do
        local y = goalTop + (goalBottom - goalTop) * (i / 5)
        nvgBeginPath(vg)
        nvgMoveTo(vg, goalLeft, y)
        nvgLineTo(vg, goalRight, y)
        nvgStroke(vg)
    end

    -- 门柱（白色）
    nvgBeginPath(vg)
    nvgRect(vg, goalLeft - postWidth, goalTop, postWidth, goalBottom - goalTop)
    nvgRect(vg, goalRight, goalTop, postWidth, goalBottom - goalTop)
    nvgRect(vg, goalLeft - postWidth, goalTop - postWidth, goalRight - goalLeft + postWidth * 2, postWidth)
    nvgFillColor(vg, nvgRGBA(C.goal[1], C.goal[2], C.goal[3], C.goal[4]))
    nvgFill(vg)
end

--- 绘制守门员
function DrawKeeper()
    local kx = screenW * game.keeper.x
    local ky = screenH * game.keeper.y
    local bodyW = 24
    local bodyH = 50

    -- 身体（黑色球衣）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, kx - bodyW / 2, ky - bodyH / 2, bodyW, bodyH, 6)
    nvgFillColor(vg, nvgRGBA(C.keeperBody[1], C.keeperBody[2], C.keeperBody[3], C.keeperBody[4]))
    nvgFill(vg)

    -- 手臂（展开状态）
    nvgBeginPath(vg)
    nvgRect(vg, kx - bodyW - 12, ky - 8, 16, 8)
    nvgRect(vg, kx + bodyW - 4, ky - 8, 16, 8)
    nvgFillColor(vg, nvgRGBA(C.keeper[1], C.keeper[2], C.keeper[3], C.keeper[4]))
    nvgFill(vg)

    -- 头部
    nvgBeginPath(vg)
    nvgCircle(vg, kx, ky - bodyH / 2 - 8, 10)
    nvgFillColor(vg, nvgRGBA(C.keeper[1], C.keeper[2], C.keeper[3], C.keeper[4]))
    nvgFill(vg)
end

--- 绘制足球
function DrawBall()
    local bx = screenW * game.ball.x
    local by = screenH * game.ball.y
    local radius = 14

    -- 球在飞行中缩小（透视效果）
    if game.state == STATE.SHOOTING then
        radius = Lerp(14, 10, game.ballProgress)
    end

    -- 阴影
    nvgBeginPath(vg)
    nvgEllipse(vg, bx + 2, by + 4, radius * 0.9, radius * 0.5)
    nvgFillColor(vg, nvgRGBA(C.ballShadow[1], C.ballShadow[2], C.ballShadow[3], C.ballShadow[4]))
    nvgFill(vg)

    -- 球体
    nvgBeginPath(vg)
    nvgCircle(vg, bx, by, radius)
    nvgFillColor(vg, nvgRGBA(C.ball[1], C.ball[2], C.ball[3], C.ball[4]))
    nvgFill(vg)

    -- 球上的花纹（简单十字）
    nvgStrokeColor(vg, nvgRGBA(50, 50, 50, 100))
    nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg)
    nvgMoveTo(vg, bx - radius * 0.5, by)
    nvgLineTo(vg, bx + radius * 0.5, by)
    nvgMoveTo(vg, bx, by - radius * 0.5)
    nvgLineTo(vg, bx, by + radius * 0.5)
    nvgStroke(vg)
end

--- 绘制瞄准十字
function DrawAim()
    if game.state ~= STATE.READY then return end

    -- 鼠标位置作为瞄准指示
    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr

    -- 限制在球门范围内
    local goalLeft = screenW * 0.25
    local goalRight = screenW * 0.75
    local goalTop = screenH * 0.15
    local goalBottom = screenH * 0.38

    mx = Clamp(mx, goalLeft, goalRight)
    my = Clamp(my, goalTop, goalBottom)

    -- 瞄准十字
    local size = 12
    nvgStrokeColor(vg, nvgRGBA(C.aim[1], C.aim[2], C.aim[3], C.aim[4]))
    nvgStrokeWidth(vg, 2)

    nvgBeginPath(vg)
    nvgMoveTo(vg, mx - size, my)
    nvgLineTo(vg, mx + size, my)
    nvgMoveTo(vg, mx, my - size)
    nvgLineTo(vg, mx, my + size)
    nvgStroke(vg)

    -- 瞄准圆环
    nvgBeginPath(vg)
    nvgCircle(vg, mx, my, size + 4)
    nvgStrokeColor(vg, nvgRGBA(C.aim[1], C.aim[2], C.aim[3], 100))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
end

--- 绘制 HUD（比分、轮次）
function DrawHUD()
    -- 顶部比分栏
    local barH = 44
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, barH)
    nvgFillColor(vg, nvgRGBA(C.hudBg[1], C.hudBg[2], C.hudBg[3], C.hudBg[4]))
    nvgFill(vg)

    -- 比分文字
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 玩家比分
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(C.textWhite[1], C.textWhite[2], C.textWhite[3], C.textWhite[4]))
    nvgText(vg, screenW * 0.3, barH / 2, "YOU  " .. game.playerScore)

    -- VS
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 180))
    nvgText(vg, screenW * 0.5, barH / 2, "VS")

    -- 对手比分
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(C.textWhite[1], C.textWhite[2], C.textWhite[3], C.textWhite[4]))
    nvgText(vg, screenW * 0.7, barH / 2, game.opponentScore .. "  CPU")

    -- 轮次
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(C.textGold[1], C.textGold[2], C.textGold[3], C.textGold[4]))
    nvgText(vg, screenW * 0.5, barH + 14, "第 " .. game.round .. " / " .. game.maxRounds .. " 轮")
end

--- 绘制状态提示文字
function DrawStateMessage()
    local msg = nil

    if game.state == STATE.READY then
        msg = "点击球门方向射门!"
    elseif game.state == STATE.GOAL then
        msg = "⚽ GOAL!"
    elseif game.state == STATE.SAVED then
        msg = "❌ 被扑出!"
    elseif game.state == STATE.ROUND_END then
        if game.playerScore > game.opponentScore then
            msg = "🏆 你赢了!"
        elseif game.playerScore < game.opponentScore then
            msg = "💀 你输了..."
        else
            msg = "🤝 平局!"
        end
    end

    if msg then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 28)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 文字阴影
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
        nvgText(vg, screenW * 0.5 + 2, screenH * 0.62 + 2, msg)

        -- 文字
        nvgFillColor(vg, nvgRGBA(C.textWhite[1], C.textWhite[2], C.textWhite[3], C.textWhite[4]))
        nvgText(vg, screenW * 0.5, screenH * 0.62, msg)
    end
end

return GameScene
