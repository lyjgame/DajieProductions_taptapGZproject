-- ============================================================================
-- 点球SlowMo - 游戏入口
-- 5秒决胜负！
-- ============================================================================

require "LuaScripts/Utilities/Sample"
local UI = require("urhox-libs/UI")
local GameScene = require("GameScene")

-- ============================================================================
-- 场景管理
-- ============================================================================
local currentScene = "menu"  -- "menu" or "game"

-- ============================================================================
-- 配色方案
-- ============================================================================
local COLORS = {
    bgTop = { 15, 55, 35, 255 },
    bgBottom = { 8, 30, 18, 255 },
    accent = { 255, 200, 50, 255 },
    accentDark = { 200, 155, 30, 255 },
    btnPrimary = { 40, 180, 80, 255 },
    btnPrimaryHover = { 50, 210, 95, 255 },
    btnSecondary = { 30, 120, 60, 255 },
    btnSecondaryHover = { 40, 150, 75, 255 },
    textWhite = { 255, 255, 255, 255 },
    textLight = { 220, 240, 220, 200 },
    textGold = { 255, 210, 60, 255 },
}

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    SampleStart()

    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 显示主菜单
    ShowMainMenu()

    SampleInitMouseMode(MM_FREE)
    print("=== 点球SlowMo ===")
end

function Stop()
    if currentScene == "game" then
        GameScene.Shutdown()
    end
    UI.Shutdown()
end

-- ============================================================================
-- 场景切换
-- ============================================================================

function ShowMainMenu()
    -- 如果从游戏场景返回，先清理
    if currentScene == "game" then
        GameScene.Shutdown()
    end
    currentScene = "menu"
    CreateMainMenu()
end

function StartSinglePlayer()
    currentScene = "game"
    -- 清空 UI 根（游戏场景用 NanoVG 自绘）
    local gameUI = UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
    }
    UI.SetRoot(gameUI, true)

    -- 启动游戏场景
    GameScene.Init()
end

-- ============================================================================
-- 主菜单 UI
-- ============================================================================

function CreateMainMenu()
    local function MenuButton(text, isPrimary, onClickFn)
        local bgColor = isPrimary and COLORS.btnPrimary or COLORS.btnSecondary
        local hoverColor = isPrimary and COLORS.btnPrimaryHover or COLORS.btnSecondaryHover

        return UI.Button {
            text = text,
            fontSize = 18,
            fontColor = COLORS.textWhite,
            width = 240,
            height = 52,
            borderRadius = 26,
            backgroundColor = bgColor,
            justifyContent = "center",
            alignItems = "center",
            borderWidth = isPrimary and 2 or 1,
            borderColor = isPrimary and COLORS.accent or { 80, 200, 120, 100 },
            onClick = function(self)
                print("[Menu] Clicked: " .. text)
                if onClickFn then onClickFn() end
            end,
            onHoverIn = function(self)
                self:SetStyle({ backgroundColor = hoverColor })
            end,
            onHoverOut = function(self)
                self:SetStyle({ backgroundColor = bgColor })
            end,
        }
    end

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.bgTop,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                alignItems = "center",
                justifyContent = "center",
                gap = 12,
                children = {
                    UI.Label {
                        text = "⚽",
                        fontSize = 48,
                        marginBottom = 8,
                    },
                    UI.Label {
                        text = "点球SlowMo",
                        fontSize = 36,
                        fontColor = COLORS.textWhite,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "5秒决胜负",
                        fontSize = 16,
                        fontColor = COLORS.textGold,
                        textAlign = "center",
                        marginBottom = 32,
                    },

                    MenuButton("单人游戏", true, function()
                        StartSinglePlayer()
                    end),

                    MenuButton("多人游戏", false, function()
                        -- TODO: 多人游戏
                        print("多人游戏（开发中）")
                    end),

                    MenuButton("游戏玩法", false, function()
                        -- TODO: 玩法说明
                        print("游戏玩法（开发中）")
                    end),

                    UI.Label {
                        text = "大杰出品 · TapTap GameJam 广州",
                        fontSize = 11,
                        fontColor = COLORS.textLight,
                        textAlign = "center",
                        marginTop = 40,
                    },
                }
            }
        }
    }

    UI.SetRoot(root, true)
end
