-- ============================================================================
-- 点球SlowMo - 主菜单
-- 5秒决胜负！
-- ============================================================================

require "LuaScripts/Utilities/Sample"
local UI = require("urhox-libs/UI")

-- ============================================================================
-- 配色方案
-- ============================================================================
local COLORS = {
    -- 主背景：深绿色（足球场感觉）
    bgTop = { 15, 55, 35, 255 },
    bgBottom = { 8, 30, 18, 255 },
    -- 强调色：金色
    accent = { 255, 200, 50, 255 },
    accentDark = { 200, 155, 30, 255 },
    -- 按钮
    btnPrimary = { 40, 180, 80, 255 },
    btnPrimaryHover = { 50, 210, 95, 255 },
    btnSecondary = { 30, 120, 60, 255 },
    btnSecondaryHover = { 40, 150, 75, 255 },
    -- 文字
    textWhite = { 255, 255, 255, 255 },
    textLight = { 220, 240, 220, 200 },
    textGold = { 255, 210, 60, 255 },
}

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    SampleStart()

    -- 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 构建主菜单
    CreateMainMenu()

    -- 鼠标可见（菜单界面）
    SampleInitMouseMode(MM_FREE)

    print("=== 点球SlowMo 主菜单 ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 主菜单 UI
-- ============================================================================

function CreateMainMenu()
    -- 菜单按钮生成函数
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
            -- 按钮边框增强质感
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

    -- 根容器
    local root = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.bgTop,
        justifyContent = "center",
        alignItems = "center",
        children = {
            -- 内容容器（垂直居中）
            UI.Panel {
                alignItems = "center",
                justifyContent = "center",
                gap = 12,
                children = {
                    -- 足球装饰 emoji
                    UI.Label {
                        text = "⚽",
                        fontSize = 48,
                        marginBottom = 8,
                    },

                    -- 主标题
                    UI.Label {
                        text = "点球SlowMo",
                        fontSize = 36,
                        fontColor = COLORS.textWhite,
                        textAlign = "center",
                    },

                    -- 副标题
                    UI.Label {
                        text = "5秒决胜负",
                        fontSize = 16,
                        fontColor = COLORS.textGold,
                        textAlign = "center",
                        marginBottom = 32,
                    },

                    -- 按钮组
                    MenuButton("单人游戏", true, function()
                        -- TODO: 进入单人游戏
                        print("进入单人游戏")
                    end),

                    MenuButton("多人游戏", false, function()
                        -- TODO: 进入多人游戏
                        print("进入多人游戏")
                    end),

                    MenuButton("游戏玩法", false, function()
                        -- TODO: 显示玩法说明
                        print("显示游戏玩法")
                    end),

                    -- 底部版本信息
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

    UI.SetRoot(root)
end
