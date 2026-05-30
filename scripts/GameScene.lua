-- ============================================================================
-- GameScene.lua - 点球SlowMo 单人游戏场景
-- 主罚视角：从射手身后看向球门（2D NanoVG 渲染）
-- 核心机制：拖拽足球射门 + 5秒SlowMo倒计时
-- ============================================================================

local GameScene = {}

-- ============================================================================
-- 游戏状态机
-- ============================================================================
local STATE = {
    ROUND_INTRO = "round_intro",    -- 轮次介绍
    KICKER_AIM = "kicker_aim",      -- 射手瞄准阶段（SlowMo倒计时中）
    BALL_FLYING = "ball_flying",    -- 球飞行中
    RESULT_SHOW = "result_show",    -- 显示单球结果
    KEEPER_TURN = "keeper_turn",    -- 守门员阶段（AI射门）
    KEEPER_RESULT = "keeper_result",-- 守门员阶段结果
    SUDDEN_DEATH = "sudden_death",  -- 突然死亡提示
    MATCH_END = "match_end",        -- 比赛结束
}

-- ============================================================================
-- 球门5区域定义（归一化坐标，相对于球门区域）
-- ============================================================================
local ZONES = {
    { name = "左上", nx = 0.2, ny = 0.3 },
    { name = "左下", nx = 0.2, ny = 0.7 },
    { name = "中路", nx = 0.5, ny = 0.5 },
    { name = "右上", nx = 0.8, ny = 0.3 },
    { name = "右下", nx = 0.8, ny = 0.7 },
}

-- ============================================================================
-- 游戏数据
-- ============================================================================
local game = {}

local function ResetGameData()
    game = {
        state = STATE.ROUND_INTRO,
        round = 1,
        maxRounds = 5,
        playerScore = 0,
        opponentScore = 0,
        -- 点球记录: "goal" / "saved" / "missed" / nil
        playerRecord = {},
        opponentRecord = {},

        -- SlowMo 倒计时
        countdown = 5.0,
        countdownInt = 5,    -- 当前显示的整数

        -- 拖拽射门状态
        isDragging = false,
        dragStartX = 0,
        dragStartY = 0,
        dragCurrentX = 0,
        dragCurrentY = 0,
        dragPower = 0,       -- 0-1 力量值
        dragAngle = 0,       -- 拖拽角度（弧度）
        shotZone = 0,        -- 目标区域索引 1-5

        -- 球飞行动画
        ballStartX = 0,
        ballStartY = 0,
        ballTargetX = 0,
        ballTargetY = 0,
        ballProgress = 0,    -- 0-1 飞行进度
        ballX = 0,
        ballY = 0,

        -- 守门员
        keeperX = 0.5,       -- 归一化位置
        keeperTargetX = 0.5,
        keeperDiveDir = 0,   -- -1左 0中 1右

        -- 射门结果
        lastResult = "",     -- "goal" / "saved" / "missed"
        lastResultText = "",
        lastResultDesc = "",

        -- 计时器
        stateTimer = 0,
        totalTimer = 0,

        -- 是否已射门（倒计时内）
        hasShot = false,

        -- AI对手射门 (守门员阶段)
        aiShotZone = 0,
        aiPower = 0,
        playerDiveDir = 0,   -- 玩家作为门将的扑救方向
    }
end

-- ============================================================================
-- 颜色主题
-- ============================================================================
local C = {
    -- 球场
    pitchGreen = { 34, 130, 55, 255 },
    pitchDark = { 28, 105, 45, 255 },
    pitchLine = { 255, 255, 255, 200 },
    -- 球门
    goalPost = { 255, 255, 255, 255 },
    goalNet = { 180, 180, 180, 60 },
    -- 球
    ballWhite = { 255, 255, 255, 255 },
    ballPattern = { 40, 40, 40, 180 },
    -- 角色
    kickerShirt = { 200, 40, 40, 255 },    -- 红色球衣
    kickerShorts = { 255, 255, 255, 255 },
    kickerSkin = { 240, 200, 160, 255 },
    kickerHair = { 80, 50, 30, 255 },
    keeperShirt = { 40, 80, 200, 255 },    -- 蓝色球衣
    keeperShorts = { 40, 40, 60, 255 },
    keeperSkin = { 240, 200, 160, 255 },
    -- HUD
    hudBg = { 20, 20, 30, 220 },
    hudRed = { 200, 50, 50, 255 },
    hudBlue = { 50, 80, 200, 255 },
    textWhite = { 255, 255, 255, 255 },
    textGold = { 255, 210, 60, 255 },
    textGray = { 180, 180, 180, 200 },
    -- 区域
    zoneBorder = { 255, 255, 255, 120 },
    zoneHighlight = { 255, 255, 100, 80 },
    -- 力量条
    powerLow = { 80, 200, 80, 255 },
    powerMid = { 255, 220, 50, 255 },
    powerHigh = { 255, 60, 60, 255 },
    -- 倒计时
    countdownColor = { 255, 220, 50, 255 },
    -- 轨迹箭头
    trajectoryColor = { 255, 255, 255, 150 },
}

-- 屏幕尺寸
local screenW, screenH = 0, 0

-- NanoVG 上下文
local vg = nil
local fontCreated = false

-- 球门矩形（像素坐标，每帧计算）
local goalRect = { left = 0, right = 0, top = 0, bottom = 0 }
-- 球的默认位置（像素坐标）
local ballDefaultPos = { x = 0, y = 0 }

-- ============================================================================
-- 初始化 / 关闭
-- ============================================================================

function GameScene.Init()
    vg = nvgCreate(1 + 2 + 4)
    if not fontCreated then
        nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
        fontCreated = true
    end

    ResetGameData()

    SubscribeToEvent("NanoVGRender", "HandleGameRender")
    SubscribeToEvent("Update", "HandleGameUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleGameMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleGameMouseUp")
    SubscribeToEvent("MouseMove", "HandleGameMouseMove")
    SubscribeToEvent("TouchBegin", "HandleGameTouchBegin")
    SubscribeToEvent("TouchMove", "HandleGameTouchMove")
    SubscribeToEvent("TouchEnd", "HandleGameTouchEnd")

    print("[GameScene] 主罚视角初始化完成")
end

function GameScene.Shutdown()
    UnsubscribeFromEvent("NanoVGRender")
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("MouseButtonDown")
    UnsubscribeFromEvent("MouseButtonUp")
    UnsubscribeFromEvent("MouseMove")
    UnsubscribeFromEvent("TouchBegin")
    UnsubscribeFromEvent("TouchMove")
    UnsubscribeFromEvent("TouchEnd")
    print("[GameScene] Shutdown")
end

-- ============================================================================
-- 坐标系工具
-- ============================================================================

--- 计算球门和球的像素位置（每帧调用）
local function UpdateLayout()
    -- 球门位置（屏幕上方中央，参考示意图比例）
    goalRect.left = screenW * 0.22
    goalRect.right = screenW * 0.78
    goalRect.top = screenH * 0.12
    goalRect.bottom = screenH * 0.40

    -- 球的默认位置（罚球点，屏幕下方中央偏下）
    ballDefaultPos.x = screenW * 0.5
    ballDefaultPos.y = screenH * 0.78
end

--- 将区域索引转为球门内的像素坐标
local function ZoneToPixel(zoneIdx)
    local zone = ZONES[zoneIdx]
    if not zone then return screenW * 0.5, screenH * 0.26 end
    local x = goalRect.left + (goalRect.right - goalRect.left) * zone.nx
    local y = goalRect.top + (goalRect.bottom - goalRect.top) * zone.ny
    return x, y
end

--- 根据拖拽方向计算目标区域
local function CalcTargetZone(dx, dy)
    -- dx: 水平偏移（正=右），dy: 垂直偏移（负=上）
    -- 将方向映射到5个区域
    local isLeft = dx < -0.15
    local isRight = dx > 0.15
    local isUp = dy < -0.3

    if isLeft and isUp then return 1 end       -- 左上
    if isLeft and not isUp then return 2 end   -- 左下
    if isRight and isUp then return 4 end      -- 右上
    if isRight and not isUp then return 5 end  -- 右下
    return 3                                    -- 中路
end

-- ============================================================================
-- 游戏逻辑更新
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleGameUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    game.stateTimer = game.stateTimer + dt
    game.totalTimer = game.totalTimer + dt

    if game.state == STATE.ROUND_INTRO then
        -- 轮次介绍显示 2 秒后自动进入射门阶段
        if game.stateTimer > 2.0 then
            EnterKickerAim()
        end

    elseif game.state == STATE.KICKER_AIM then
        -- SlowMo 倒计时
        game.countdown = game.countdown - dt
        game.countdownInt = math.ceil(game.countdown)
        if game.countdownInt < 1 then game.countdownInt = 1 end

        -- 倒计时结束 → 如果没射门则默认射中路
        if game.countdown <= 0 then
            if not game.hasShot then
                -- 超时未射门，默认中路、中等力量
                ExecuteShot(3, 0.5)
            end
        end

    elseif game.state == STATE.BALL_FLYING then
        -- 球飞行动画
        local flySpeed = 1.8
        game.ballProgress = game.ballProgress + dt * flySpeed

        local t = math.min(game.ballProgress, 1.0)
        -- 缓入缓出
        local easeT = t < 0.5 and (2 * t * t) or (1 - 2 * (1 - t) * (1 - t))

        game.ballX = Lerp(game.ballStartX, game.ballTargetX, easeT)
        game.ballY = Lerp(game.ballStartY, game.ballTargetY, easeT)

        -- 守门员扑救动画
        local keeperSpeed = 2.0
        local kt = math.min(game.stateTimer * keeperSpeed, 1.0)
        game.keeperX = Lerp(0.5, game.keeperTargetX, kt)

        -- 球到达目标
        if game.ballProgress >= 1.0 then
            DetermineResult()
        end

    elseif game.state == STATE.RESULT_SHOW then
        -- 结果显示 2.5 秒后进入下一阶段
        if game.stateTimer > 2.5 then
            -- 进入对手射门阶段（AI踢，玩家守）
            EnterKeeperTurn()
        end

    elseif game.state == STATE.KEEPER_TURN then
        -- AI射门阶段：1.5秒后AI自动射门
        if game.stateTimer > 1.5 then
            ExecuteAIShot()
        end

    elseif game.state == STATE.KEEPER_RESULT then
        -- 结果显示 2.5 秒后进入下一轮
        if game.stateTimer > 2.5 then
            AdvanceRound()
        end

    elseif game.state == STATE.SUDDEN_DEATH then
        if game.stateTimer > 2.5 then
            -- 重新开始下一轮（突然死亡轮）
            game.state = STATE.ROUND_INTRO
            game.stateTimer = 0
        end

    elseif game.state == STATE.MATCH_END then
        -- 等待玩家点击继续
    end
end

-- ============================================================================
-- 状态切换函数
-- ============================================================================

function EnterKickerAim()
    game.state = STATE.KICKER_AIM
    game.stateTimer = 0
    game.countdown = 5.0
    game.countdownInt = 5
    game.hasShot = false
    game.isDragging = false
    game.dragPower = 0
    game.shotZone = 0
    game.keeperX = 0.5
    game.ballX = ballDefaultPos.x
    game.ballY = ballDefaultPos.y
    print("[GameScene] 轮次 " .. game.round .. " - 你是点球手，拖拽射门！")
end

function ExecuteShot(zoneIdx, power)
    game.hasShot = true
    game.shotZone = zoneIdx
    game.dragPower = power

    -- 设置球的起始和目标位置
    game.ballStartX = ballDefaultPos.x
    game.ballStartY = ballDefaultPos.y
    local tx, ty = ZoneToPixel(zoneIdx)
    game.ballTargetX = tx
    game.ballTargetY = ty

    -- 守门员AI决策：随机选择扑救方向
    local aiChoices = { 0.25, 0.35, 0.5, 0.65, 0.75 }
    game.keeperTargetX = aiChoices[math.random(1, #aiChoices)]

    -- 进入飞行状态
    game.state = STATE.BALL_FLYING
    game.ballProgress = 0
    game.stateTimer = 0
    game.isDragging = false

    print("[GameScene] 射门! 区域:" .. ZONES[zoneIdx].name .. " 力量:" .. string.format("%.0f%%", power * 100))
end

function DetermineResult()
    -- 判断进球/被扑
    local shotZone = game.shotZone
    local keeperZone = CalcKeeperCoverZone(game.keeperTargetX)
    local power = game.dragPower

    -- 力量过大有概率射偏
    local missChance = 0
    if power > 0.85 then missChance = 0.2 end
    if power > 0.95 then missChance = 0.4 end

    if math.random() < missChance then
        -- 射偏
        game.lastResult = "missed"
        game.lastResultText = "射偏了!"
        game.lastResultDesc = "力量太大"
        table.insert(game.playerRecord, "missed")
    elseif shotZone == keeperZone then
        -- 被扑出
        game.lastResult = "saved"
        game.lastResultText = "被扑出!"
        game.lastResultDesc = "守门员判断正确"
        table.insert(game.playerRecord, "saved")
    else
        -- 进球
        game.lastResult = "goal"
        game.lastResultText = "GOAL!"
        game.lastResultDesc = ZONES[shotZone].name .. " 进球"
        game.playerScore = game.playerScore + 1
        table.insert(game.playerRecord, "goal")
    end

    game.state = STATE.RESULT_SHOW
    game.stateTimer = 0
    print("[GameScene] 结果: " .. game.lastResultText)
end

--- 根据守门员X位置判断其覆盖区域
function CalcKeeperCoverZone(kx)
    if kx < 0.3 then return 1 end      -- 覆盖左上/左下
    if kx < 0.4 then return 2 end
    if kx < 0.6 then return 3 end      -- 中路
    if kx < 0.7 then return 4 end
    return 5                             -- 右上/右下
end

function EnterKeeperTurn()
    -- AI射门，玩家守门
    game.state = STATE.KEEPER_TURN
    game.stateTimer = 0
    game.keeperX = 0.5
    game.ballX = ballDefaultPos.x
    game.ballY = ballDefaultPos.y

    -- AI随机选择射门区域
    game.aiShotZone = math.random(1, 5)
    game.aiPower = 0.5 + math.random() * 0.4  -- 0.5~0.9

    print("[GameScene] 对手射门阶段 - AI选择区域: " .. ZONES[game.aiShotZone].name)
end

function ExecuteAIShot()
    -- AI球飞向目标
    game.ballStartX = ballDefaultPos.x
    game.ballStartY = ballDefaultPos.y
    local tx, ty = ZoneToPixel(game.aiShotZone)
    game.ballTargetX = tx
    game.ballTargetY = ty

    -- 门将AI扑救（这里简化：随机扑一个方向）
    local saveChoices = { 0.25, 0.4, 0.5, 0.6, 0.75 }
    game.keeperTargetX = saveChoices[math.random(1, #saveChoices)]

    -- 判断结果
    local keeperZone = CalcKeeperCoverZone(game.keeperTargetX)
    local missChance = 0
    if game.aiPower > 0.85 then missChance = 0.15 end

    if math.random() < missChance then
        game.lastResult = "missed"
        game.lastResultText = "对手射偏!"
        game.lastResultDesc = "力量太大打飞了"
        table.insert(game.opponentRecord, "missed")
    elseif game.aiShotZone == keeperZone then
        game.lastResult = "saved"
        game.lastResultText = "扑出了!"
        game.lastResultDesc = "门将判断正确"
        table.insert(game.opponentRecord, "saved")
    else
        game.lastResult = "goal"
        game.lastResultText = "对手进球"
        game.lastResultDesc = ZONES[game.aiShotZone].name
        game.opponentScore = game.opponentScore + 1
        table.insert(game.opponentRecord, "goal")
    end

    game.state = STATE.KEEPER_RESULT
    game.stateTimer = 0
    -- 简化：跳过球飞行动画直接显示结果
    print("[GameScene] 对手结果: " .. game.lastResultText)
end

function AdvanceRound()
    game.round = game.round + 1

    -- 检查是否比赛结束
    if game.round > game.maxRounds then
        if game.playerScore == game.opponentScore then
            -- 平局进入突然死亡
            game.state = STATE.SUDDEN_DEATH
            game.stateTimer = 0
            game.maxRounds = game.maxRounds + 1  -- 追加一轮
            print("[GameScene] 突然死亡!")
        else
            -- 比赛结束
            game.state = STATE.MATCH_END
            game.stateTimer = 0
            print("[GameScene] 比赛结束! " .. game.playerScore .. ":" .. game.opponentScore)
        end
    else
        -- 继续下一轮
        game.state = STATE.ROUND_INTRO
        game.stateTimer = 0
    end
end

-- ============================================================================
-- 输入处理 - 拖拽射门
-- ============================================================================

local function GetInputPos(eventData, isMouse)
    local dpr = graphics:GetDPR()
    local x, y
    if isMouse then
        x = input.mousePosition.x
        y = input.mousePosition.y
    else
        x = eventData["X"]:GetInt() / dpr
        y = eventData["Y"]:GetInt() / dpr
    end
    return x, y
end

--- 检查触摸/点击是否在球附近
local function IsTouchOnBall(x, y)
    local bx = ballDefaultPos.x
    local by = ballDefaultPos.y
    local dist = math.sqrt((x - bx)^2 + (y - by)^2)
    return dist < 50  -- 50像素范围内算点中球
end

---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleGameMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end

    local x, y = GetInputPos(eventData, true)

    if game.state == STATE.KICKER_AIM and not game.hasShot then
        if IsTouchOnBall(x, y) then
            game.isDragging = true
            game.dragStartX = x
            game.dragStartY = y
            game.dragCurrentX = x
            game.dragCurrentY = y
        end
    elseif game.state == STATE.MATCH_END then
        -- 点击任意处返回菜单
        ShowMainMenu()
    end
end

---@param eventType string
---@param eventData MouseMoveEventData
function HandleGameMouseMove(eventType, eventData)
    if not game.isDragging then return end
    local x, y = GetInputPos(eventData, true)
    game.dragCurrentX = x
    game.dragCurrentY = y
    UpdateDragState()
end

---@param eventType string
---@param eventData MouseButtonUpEventData
function HandleGameMouseUp(eventType, eventData)
    if not game.isDragging then return end
    game.isDragging = false
    -- 松开时射门
    if game.state == STATE.KICKER_AIM and not game.hasShot and game.dragPower > 0.1 then
        ExecuteShot(game.shotZone, game.dragPower)
    end
end

---@param eventType string
---@param eventData TouchBeginEventData
function HandleGameTouchBegin(eventType, eventData)
    local x, y = GetInputPos(eventData, false)

    if game.state == STATE.KICKER_AIM and not game.hasShot then
        if IsTouchOnBall(x, y) then
            game.isDragging = true
            game.dragStartX = x
            game.dragStartY = y
            game.dragCurrentX = x
            game.dragCurrentY = y
        end
    elseif game.state == STATE.MATCH_END then
        ShowMainMenu()
    end
end

---@param eventType string
---@param eventData TouchMoveEventData
function HandleGameTouchMove(eventType, eventData)
    if not game.isDragging then return end
    local x, y = GetInputPos(eventData, false)
    game.dragCurrentX = x
    game.dragCurrentY = y
    UpdateDragState()
end

---@param eventType string
---@param eventData TouchEndEventData
function HandleGameTouchEnd(eventType, eventData)
    if not game.isDragging then return end
    game.isDragging = false
    if game.state == STATE.KICKER_AIM and not game.hasShot and game.dragPower > 0.1 then
        ExecuteShot(game.shotZone, game.dragPower)
    end
end

--- 更新拖拽状态（力量和方向）
function UpdateDragState()
    local dx = game.dragCurrentX - game.dragStartX
    local dy = game.dragCurrentY - game.dragStartY
    local dist = math.sqrt(dx * dx + dy * dy)

    -- 力量：拖拽距离映射到 0-1（最大拖拽距离 = 屏幕高度的30%）
    local maxDrag = screenH * 0.3
    game.dragPower = math.min(dist / maxDrag, 1.0)

    -- 方向：拖拽向量归一化（向球门方向映射到区域）
    -- 拖拽方向相对于球门来判定区域
    -- 玩家从球的位置向球门方向拖拽
    local normDx = dx / math.max(screenW * 0.3, 1)   -- 水平归一化
    local normDy = dy / math.max(screenH * 0.3, 1)   -- 垂直归一化

    game.shotZone = CalcTargetZone(normDx, normDy)
    game.dragAngle = math.atan(dy, dx)
end

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================

function HandleGameRender(eventType, eventData)
    if vg == nil then return end

    local dpr = graphics:GetDPR()
    screenW = graphics:GetWidth() / dpr
    screenH = graphics:GetHeight() / dpr

    UpdateLayout()

    nvgBeginFrame(vg, screenW, screenH, dpr)

    DrawPitch()
    DrawGoal()
    DrawZones()
    DrawKeeper()
    DrawKicker()
    DrawBallAndTrajectory()
    DrawHUD()
    DrawCountdown()
    DrawPowerBar()
    DrawInstruction()
    DrawResult()

    nvgEndFrame(vg)
end

-- ============================================================================
-- 绘制函数
-- ============================================================================

--- 草地球场
function DrawPitch()
    -- 背景渐变
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    local paint = nvgLinearGradient(vg, 0, 0, 0, screenH,
        nvgRGBA(C.pitchGreen[1], C.pitchGreen[2], C.pitchGreen[3], 255),
        nvgRGBA(C.pitchDark[1], C.pitchDark[2], C.pitchDark[3], 255))
    nvgFillPaint(vg, paint)
    nvgFill(vg)

    -- 草地条纹
    for i = 0, 10 do
        if i % 2 == 0 then
            local stripH = screenH / 11
            nvgBeginPath(vg)
            nvgRect(vg, 0, i * stripH, screenW, stripH)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 6))
            nvgFill(vg)
        end
    end

    -- 禁区线
    local boxL = screenW * 0.15
    local boxR = screenW * 0.85
    local boxT = screenH * 0.05
    local boxB = screenH * 0.55

    nvgBeginPath(vg)
    nvgMoveTo(vg, boxL, boxB)
    nvgLineTo(vg, boxL, boxT)
    nvgLineTo(vg, boxR, boxT)
    nvgLineTo(vg, boxR, boxB)
    nvgStrokeColor(vg, nvgRGBA(C.pitchLine[1], C.pitchLine[2], C.pitchLine[3], C.pitchLine[4]))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 罚球点
    nvgBeginPath(vg)
    nvgCircle(vg, ballDefaultPos.x, ballDefaultPos.y, 4)
    nvgFillColor(vg, nvgRGBA(C.pitchLine[1], C.pitchLine[2], C.pitchLine[3], 150))
    nvgFill(vg)
end

--- 球门
function DrawGoal()
    local gl = goalRect.left
    local gr = goalRect.right
    local gt = goalRect.top
    local gb = goalRect.bottom
    local pw = 5  -- 门柱宽度

    -- 球网背景
    nvgBeginPath(vg)
    nvgRect(vg, gl, gt, gr - gl, gb - gt)
    nvgFillColor(vg, nvgRGBA(C.goalNet[1], C.goalNet[2], C.goalNet[3], C.goalNet[4]))
    nvgFill(vg)

    -- 网格线
    nvgStrokeWidth(vg, 1)
    nvgStrokeColor(vg, nvgRGBA(200, 200, 200, 30))
    local cols = 12
    local rows = 6
    for i = 1, cols - 1 do
        local x = gl + (gr - gl) * (i / cols)
        nvgBeginPath(vg)
        nvgMoveTo(vg, x, gt)
        nvgLineTo(vg, x, gb)
        nvgStroke(vg)
    end
    for i = 1, rows - 1 do
        local y = gt + (gb - gt) * (i / rows)
        nvgBeginPath(vg)
        nvgMoveTo(vg, gl, y)
        nvgLineTo(vg, gr, y)
        nvgStroke(vg)
    end

    -- 门柱和横梁
    nvgBeginPath(vg)
    nvgRect(vg, gl - pw, gt - pw, pw, gb - gt + pw)  -- 左柱
    nvgRect(vg, gr, gt - pw, pw, gb - gt + pw)       -- 右柱
    nvgRect(vg, gl - pw, gt - pw, gr - gl + pw * 2, pw)  -- 横梁
    nvgFillColor(vg, nvgRGBA(C.goalPost[1], C.goalPost[2], C.goalPost[3], C.goalPost[4]))
    nvgFill(vg)
end

--- 5区域虚线圆
function DrawZones()
    if game.state ~= STATE.KICKER_AIM then return end

    for i = 1, 5 do
        local zx, zy = ZoneToPixel(i)
        local radius = math.min(screenW, screenH) * 0.06

        -- 如果当前瞄准此区域则高亮
        if game.isDragging and game.shotZone == i then
            nvgBeginPath(vg)
            nvgCircle(vg, zx, zy, radius)
            nvgFillColor(vg, nvgRGBA(C.zoneHighlight[1], C.zoneHighlight[2], C.zoneHighlight[3], C.zoneHighlight[4]))
            nvgFill(vg)
        end

        -- 虚线圆环（用短弧线模拟）
        nvgStrokeColor(vg, nvgRGBA(C.zoneBorder[1], C.zoneBorder[2], C.zoneBorder[3], C.zoneBorder[4]))
        nvgStrokeWidth(vg, 2)
        local segments = 16
        for s = 0, segments - 1, 2 do
            local a1 = (s / segments) * math.pi * 2
            local a2 = ((s + 1) / segments) * math.pi * 2
            nvgBeginPath(vg)
            nvgArc(vg, zx, zy, radius, a1, a2, NVG_CW)
            nvgStroke(vg)
        end

        -- 区域名称
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
        nvgText(vg, zx, zy, ZONES[i].name)
    end
end

--- 守门员（简笔画卡通风格）
function DrawKeeper()
    local kx = screenW * game.keeperX
    local ky = goalRect.top + (goalRect.bottom - goalRect.top) * 0.6
    local scale = screenH * 0.001  -- 缩放因子

    -- 身体
    local bodyW = 22 * scale
    local bodyH = 45 * scale

    -- 蓝色球衣
    nvgBeginPath(vg)
    nvgRoundedRect(vg, kx - bodyW, ky - bodyH * 0.3, bodyW * 2, bodyH, 4)
    nvgFillColor(vg, nvgRGBA(C.keeperShirt[1], C.keeperShirt[2], C.keeperShirt[3], C.keeperShirt[4]))
    nvgFill(vg)

    -- 头部
    local headR = 10 * scale
    nvgBeginPath(vg)
    nvgCircle(vg, kx, ky - bodyH * 0.3 - headR, headR)
    nvgFillColor(vg, nvgRGBA(C.keeperSkin[1], C.keeperSkin[2], C.keeperSkin[3], C.keeperSkin[4]))
    nvgFill(vg)

    -- 手臂（展开姿态）
    local armLen = 18 * scale
    nvgBeginPath(vg)
    nvgRect(vg, kx - bodyW - armLen, ky - bodyH * 0.1, armLen, 6 * scale)
    nvgRect(vg, kx + bodyW, ky - bodyH * 0.1, armLen, 6 * scale)
    nvgFillColor(vg, nvgRGBA(C.keeperShirt[1], C.keeperShirt[2], C.keeperShirt[3], C.keeperShirt[4]))
    nvgFill(vg)

    -- 手套（黄色）
    nvgBeginPath(vg)
    nvgCircle(vg, kx - bodyW - armLen, ky - bodyH * 0.1 + 3 * scale, 5 * scale)
    nvgCircle(vg, kx + bodyW + armLen, ky - bodyH * 0.1 + 3 * scale, 5 * scale)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgFill(vg)
end

--- 射手（背影，左下角）
function DrawKicker()
    if game.state == STATE.KEEPER_TURN or game.state == STATE.KEEPER_RESULT then return end

    local kx = screenW * 0.28
    local ky = screenH * 0.82
    local scale = screenH * 0.0015

    -- 身体（红色球衣）
    local bodyW = 18 * scale
    local bodyH = 40 * scale
    nvgBeginPath(vg)
    nvgRoundedRect(vg, kx - bodyW, ky - bodyH, bodyW * 2, bodyH, 4)
    nvgFillColor(vg, nvgRGBA(C.kickerShirt[1], C.kickerShirt[2], C.kickerShirt[3], C.kickerShirt[4]))
    nvgFill(vg)

    -- 号码 "7"
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14 * scale)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgText(vg, kx, ky - bodyH * 0.5, "7")

    -- 头部（头发）
    local headR = 10 * scale
    nvgBeginPath(vg)
    nvgCircle(vg, kx, ky - bodyH - headR, headR)
    nvgFillColor(vg, nvgRGBA(C.kickerHair[1], C.kickerHair[2], C.kickerHair[3], C.kickerHair[4]))
    nvgFill(vg)

    -- 短裤
    nvgBeginPath(vg)
    nvgRect(vg, kx - bodyW, ky, bodyW * 2, 12 * scale)
    nvgFillColor(vg, nvgRGBA(C.kickerShorts[1], C.kickerShorts[2], C.kickerShorts[3], C.kickerShorts[4]))
    nvgFill(vg)
end

--- 足球 + 拖拽轨迹
function DrawBallAndTrajectory()
    local bx, by, radius

    if game.state == STATE.BALL_FLYING then
        -- 飞行中的球
        bx = game.ballX
        by = game.ballY
        -- 透视缩小效果
        local t = game.ballProgress
        radius = Lerp(14, 9, t)
    elseif game.state == STATE.KICKER_AIM or game.state == STATE.ROUND_INTRO then
        -- 球在罚球点
        bx = ballDefaultPos.x
        by = ballDefaultPos.y
        radius = 14
    else
        bx = ballDefaultPos.x
        by = ballDefaultPos.y
        radius = 14
    end

    -- 拖拽时显示轨迹箭头
    if game.isDragging and game.state == STATE.KICKER_AIM then
        local tx, ty = ZoneToPixel(game.shotZone)
        -- 绘制轨迹弧线（从球到目标区域）
        nvgBeginPath(vg)
        nvgMoveTo(vg, bx, by)
        -- 贝塞尔曲线模拟弧线
        local cx = (bx + tx) * 0.5
        local cy = (by + ty) * 0.5 - 30  -- 略微拱起
        nvgQuadTo(vg, cx, cy, tx, ty)
        nvgStrokeColor(vg, nvgRGBA(C.trajectoryColor[1], C.trajectoryColor[2], C.trajectoryColor[3],
            math.floor(C.trajectoryColor[4] * game.dragPower)))
        nvgStrokeWidth(vg, 3)
        nvgStroke(vg)

        -- 箭头头部
        nvgBeginPath(vg)
        nvgCircle(vg, tx, ty, 6)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(180 * game.dragPower)))
        nvgFill(vg)
    end

    -- 球体阴影
    nvgBeginPath(vg)
    nvgEllipse(vg, bx + 2, by + 4, radius * 0.9, radius * 0.5)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 50))
    nvgFill(vg)

    -- 球体（白色）
    nvgBeginPath(vg)
    nvgCircle(vg, bx, by, radius)
    nvgFillColor(vg, nvgRGBA(C.ballWhite[1], C.ballWhite[2], C.ballWhite[3], C.ballWhite[4]))
    nvgFill(vg)

    -- 球纹（五边形提示）
    nvgStrokeColor(vg, nvgRGBA(C.ballPattern[1], C.ballPattern[2], C.ballPattern[3], C.ballPattern[4]))
    nvgStrokeWidth(vg, 1.2)
    nvgBeginPath(vg)
    local penR = radius * 0.4
    for i = 0, 4 do
        local a = (i / 5) * math.pi * 2 - math.pi / 2
        local px = bx + math.cos(a) * penR
        local py = by + math.sin(a) * penR
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgStroke(vg)
end

--- HUD：比分栏 + 点球记录
function DrawHUD()
    local barH = 50
    -- 顶部栏背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, screenW * 0.2, 8, screenW * 0.6, barH, 8)
    nvgFillColor(vg, nvgRGBA(C.hudBg[1], C.hudBg[2], C.hudBg[3], C.hudBg[4]))
    nvgFill(vg)

    -- A 标签（红色）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, screenW * 0.2, 8, 36, barH, 8)
    nvgFillColor(vg, nvgRGBA(C.hudRed[1], C.hudRed[2], C.hudRed[3], C.hudRed[4]))
    nvgFill(vg)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, screenW * 0.2 + 18, 8 + barH / 2, "A")

    -- B 标签（蓝色）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, screenW * 0.8 - 36, 8, 36, barH, 8)
    nvgFillColor(vg, nvgRGBA(C.hudBlue[1], C.hudBlue[2], C.hudBlue[3], C.hudBlue[4]))
    nvgFill(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, screenW * 0.8 - 18, 8 + barH / 2, "B")

    -- 比分
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(C.textWhite[1], C.textWhite[2], C.textWhite[3], 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local scoreText = game.playerScore .. " : " .. game.opponentScore
    nvgText(vg, screenW * 0.5, 8 + barH / 2 - 6, scoreText)

    -- 点球记录标记
    nvgFontSize(vg, 12)
    local recordY = 8 + barH / 2 + 12
    -- 玩家记录
    local startX = screenW * 0.35
    for i = 1, game.maxRounds do
        local mark = "—"
        local color = C.textGray
        if game.playerRecord[i] == "goal" then
            mark = "O"
            color = { 100, 255, 100, 255 }
        elseif game.playerRecord[i] == "saved" or game.playerRecord[i] == "missed" then
            mark = "X"
            color = { 255, 80, 80, 255 }
        end
        nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], color[4]))
        nvgText(vg, startX + (i - 1) * 16, recordY, mark)
    end
    -- 对手记录
    startX = screenW * 0.55
    for i = 1, game.maxRounds do
        local mark = "—"
        local color = C.textGray
        if game.opponentRecord[i] == "goal" then
            mark = "O"
            color = { 100, 255, 100, 255 }
        elseif game.opponentRecord[i] == "saved" or game.opponentRecord[i] == "missed" then
            mark = "X"
            color = { 255, 80, 80, 255 }
        end
        nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], color[4]))
        nvgText(vg, startX + (i - 1) * 16, recordY, mark)
    end

    -- 身份标识（右上角）
    if game.state == STATE.KICKER_AIM or game.state == STATE.BALL_FLYING or game.state == STATE.RESULT_SHOW then
        DrawIdentityBadge("你是点球手", true)
    elseif game.state == STATE.KEEPER_TURN or game.state == STATE.KEEPER_RESULT then
        DrawIdentityBadge("你是守门员", false)
    end
end

function DrawIdentityBadge(text, isKicker)
    local badgeW = 110
    local badgeH = 30
    local bx = screenW - badgeW - 12
    local by = 12

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, badgeW, badgeH, 6)
    nvgFillColor(vg, nvgRGBA(C.hudBg[1], C.hudBg[2], C.hudBg[3], 240))
    nvgFill(vg)
    -- 金色边框
    nvgStrokeColor(vg, nvgRGBA(C.textGold[1], C.textGold[2], C.textGold[3], 200))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 星星图标 + 文字
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(C.textGold[1], C.textGold[2], C.textGold[3], 255))
    nvgText(vg, bx + badgeW / 2, by + badgeH / 2, "★ " .. text)
end

--- SlowMo 倒计时大数字
function DrawCountdown()
    if game.state ~= STATE.KICKER_AIM then return end

    -- 大号倒计时数字
    local num = tostring(game.countdownInt)
    local alpha = 255
    -- 闪烁效果
    local frac = game.countdown - math.floor(game.countdown)
    if frac > 0.7 then
        alpha = math.floor(255 * (1.0 - (frac - 0.7) / 0.3))
    end

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 72)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 阴影
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.5)))
    nvgText(vg, screenW * 0.5 + 3, screenH * 0.08 + 3, num)

    -- 金色数字
    nvgFillColor(vg, nvgRGBA(C.countdownColor[1], C.countdownColor[2], C.countdownColor[3], alpha))
    nvgText(vg, screenW * 0.5, screenH * 0.08, num)
end

--- 力量条
function DrawPowerBar()
    if game.state ~= STATE.KICKER_AIM then return end

    local barW = screenW * 0.4
    local barH = 16
    local bx = (screenW - barW) / 2
    local by = screenH * 0.90

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, barW, barH, 4)
    nvgFillColor(vg, nvgRGBA(30, 30, 30, 180))
    nvgFill(vg)

    -- 力量填充（渐变色：绿→黄→红）
    if game.dragPower > 0 then
        local fillW = barW * game.dragPower
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, fillW, barH, 4)

        local r, g, b
        if game.dragPower < 0.5 then
            local t = game.dragPower / 0.5
            r = math.floor(Lerp(C.powerLow[1], C.powerMid[1], t))
            g = math.floor(Lerp(C.powerLow[2], C.powerMid[2], t))
            b = math.floor(Lerp(C.powerLow[3], C.powerMid[3], t))
        else
            local t = (game.dragPower - 0.5) / 0.5
            r = math.floor(Lerp(C.powerMid[1], C.powerHigh[1], t))
            g = math.floor(Lerp(C.powerMid[2], C.powerHigh[2], t))
            b = math.floor(Lerp(C.powerMid[3], C.powerHigh[3], t))
        end
        nvgFillColor(vg, nvgRGBA(r, g, b, 255))
        nvgFill(vg)
    end

    -- 力量等级标签
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(C.textGray[1], C.textGray[2], C.textGray[3], C.textGray[4]))
    nvgText(vg, bx + barW * 0.17, by + barH + 4, "LOW")
    nvgText(vg, bx + barW * 0.5, by + barH + 4, "MID")
    nvgText(vg, bx + barW * 0.83, by + barH + 4, "HIGH")
end

--- 操作提示文字
function DrawInstruction()
    if game.state == STATE.KICKER_AIM and not game.isDragging and not game.hasShot then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
        nvgText(vg, screenW * 0.5, screenH * 0.85, "👆 拖拽足球射门")
    end
end

--- 结果显示（进球/扑出/射偏）
function DrawResult()
    if game.state == STATE.ROUND_INTRO then
        -- 轮次介绍
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 32)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(C.textWhite[1], C.textWhite[2], C.textWhite[3], 255))
        nvgText(vg, screenW * 0.5, screenH * 0.45, "第 " .. game.round .. " 轮")

        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(C.textGold[1], C.textGold[2], C.textGold[3], 255))
        nvgText(vg, screenW * 0.5, screenH * 0.52, "你是点球手")

    elseif game.state == STATE.RESULT_SHOW or game.state == STATE.KEEPER_RESULT then
        -- 结果大字
        local color = C.textWhite
        if game.lastResult == "goal" and game.state == STATE.RESULT_SHOW then
            color = { 100, 255, 100, 255 }
        elseif game.lastResult == "goal" and game.state == STATE.KEEPER_RESULT then
            color = { 255, 80, 80, 255 }
        elseif game.lastResult == "saved" then
            color = C.textGold
        end

        -- 半透明背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, screenW * 0.2, screenH * 0.4, screenW * 0.6, screenH * 0.2, 12)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
        nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 36)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], color[4]))
        nvgText(vg, screenW * 0.5, screenH * 0.47, game.lastResultText)

        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(C.textGray[1], C.textGray[2], C.textGray[3], 255))
        nvgText(vg, screenW * 0.5, screenH * 0.55, game.lastResultDesc)

    elseif game.state == STATE.KEEPER_TURN then
        -- 对手射门提示
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(C.textWhite[1], C.textWhite[2], C.textWhite[3], 255))
        nvgText(vg, screenW * 0.5, screenH * 0.45, "对手射门中...")

    elseif game.state == STATE.SUDDEN_DEATH then
        -- 突然死亡
        nvgBeginPath(vg)
        nvgRoundedRect(vg, screenW * 0.15, screenH * 0.35, screenW * 0.7, screenH * 0.3, 12)
        nvgFillColor(vg, nvgRGBA(150, 20, 20, 200))
        nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 36)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, screenW * 0.5, screenH * 0.45, "突然死亡!")

        nvgFontSize(vg, 16)
        nvgFillColor(vg, nvgRGBA(C.textGold[1], C.textGold[2], C.textGold[3], 255))
        nvgText(vg, screenW * 0.5, screenH * 0.55, "一球定胜负")

    elseif game.state == STATE.MATCH_END then
        -- 比赛结算
        nvgBeginPath(vg)
        nvgRoundedRect(vg, screenW * 0.15, screenH * 0.25, screenW * 0.7, screenH * 0.5, 12)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
        nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 胜负标题
        local titleText, titleColor
        if game.playerScore > game.opponentScore then
            titleText = "你赢了!"
            titleColor = { 100, 255, 100, 255 }
        else
            titleText = "你输了"
            titleColor = { 255, 80, 80, 255 }
        end

        nvgFontSize(vg, 40)
        nvgFillColor(vg, nvgRGBA(titleColor[1], titleColor[2], titleColor[3], titleColor[4]))
        nvgText(vg, screenW * 0.5, screenH * 0.35, titleText)

        -- 最终比分
        nvgFontSize(vg, 28)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, screenW * 0.5, screenH * 0.45, game.playerScore .. " : " .. game.opponentScore)

        -- 提示
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(C.textGray[1], C.textGray[2], C.textGray[3], 255))
        nvgText(vg, screenW * 0.5, screenH * 0.62, "点击任意处返回主菜单")
    end
end

return GameScene
