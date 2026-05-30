# 点球 Slowmo：2D 素材清单与生成提示词

## 目标

这份文档用于指导 GameJam agent 生成或制作《点球 Slowmo：54321》的 2D 素材。优先保证可玩闭环需要的素材，再补表现和氛围。

## 美术总方向

- 类型：2D Q 版足球点球大战。
- 视角：点球手背后伪透视视角。
- 氛围：紧张、比赛现场、倒计时压迫感。
- 场景：夜间或黄昏足球场，球门清晰，观众席可简化。
- 角色：Q 版大头短身，动作夸张，表情明显。
- 制作原则：宁可简单清楚，不要复杂难做。

## 必须素材

### 角色

- 点球手待机图。
- 点球手助跑动画。
- 点球手射门动画。
- 点球手进球庆祝图或动画。
- 点球手射失懊恼图或动画。
- 守门员待机图。
- 守门员左扑动画。
- 守门员右扑动画。
- 守门员中路接球动画。
- 守门员脚挡动画。
- 守门员扑救成功图或动画。
- 守门员失球反应图或动画。

### 场景

- 伪透视草地球场背景。
- 点球点。
- 球门。
- 球网。
- 观众席背景。
- 足球。
- 足球阴影。

### UI

- 巨大倒计时数字：5、4、3、2、1。
- 比分板。
- 当前轮次提示。
- 鼠标拖拽箭头。
- 射门力量条或力量提示。
- 扑救方向提示。
- 结果文字：进球、扑出、射失。

### 特效

- 足球飞行拖尾。
- 球网震动效果。
- 扑救碰撞效果。
- slowmo 启动效果。

## 建议素材

- 裁判站立图。
- 裁判吹哨动画。
- 中线列队队员剪影。
- 草地前景装饰。
- 体育场聚光灯。
- 观众欢呼动画。
- 足球打中门柱效果。
- 足球打中横梁效果。
- 门将提前移动残影。
- 关键球红色倒计时 UI。

## 有时间再做

- 点球手紧张深呼吸动画。
- 守门员拍手套动画。
- 点球手不同球衣颜色。
- 守门员不同球衣颜色。
- 胜利界面插画。
- 失败界面插画。
- 慢动作回放边框。
- 观众席动态波浪。
- 广告牌。
- 更丰富的表情变化。

## 推荐图层结构

从后到前：

1. 天空或暗色体育场背景。
2. 聚光灯。
3. 观众席。
4. 中线列队队员剪影。
5. 草地球场。
6. 球门后层和球网。
7. 守门员。
8. 足球飞行轨迹和特效。
9. 点球手和足球。
10. UI、倒计时、比分板。

## 角色尺寸建议

- 点球手：画面高度的 25%-35%。
- 守门员：球门高度的 45%-60%。
- 足球：正常状态清晰可点，飞行中可通过缩放表现远近。
- 倒计时数字：画面中心或球门上方，占画面高度 20%-35%。

## 角色设计提示词

### 点球手中文提示词

2D Q版足球点球手，大头短身，卡通体育游戏角色，穿红色球衣，站在点球点前，准备射门，动作夸张，表情紧张，可爱但有竞技感，干净描边，游戏精灵，透明背景，简单帧动画风格。

### 点球手英文提示词

2D chibi football penalty kicker, big head small body, cartoon sports game character, red jersey, standing before penalty kick, exaggerated pose, nervous expression, cute but competitive, clean outline, game sprite, transparent background, simple frame animation style.

### 守门员中文提示词

2D Q版足球守门员，大头短身，穿蓝色守门员球衣和手套，站在球门前，准备扑救，动作夸张，表情专注，卡通体育游戏角色，干净描边，游戏精灵，透明背景，简单帧动画风格。

### 守门员英文提示词

2D chibi football goalkeeper, big head small body, blue goalkeeper jersey and gloves, standing in front of goal, ready to dive, exaggerated pose, focused expression, cartoon sports game character, clean outline, game sprite, transparent background, simple frame animation style.

## 场景提示词

### 中文提示词

2D伪透视足球点球场景，点球手背后视角，画面上方是球门和守门员，画面下方是点球点和足球，夜间体育场，聚光灯，观众席剪影，草地纹理，卡通体育游戏背景，紧张比赛氛围。

### 英文提示词

2D pseudo perspective football penalty shootout scene, behind kicker view, goal and goalkeeper at the top of the screen, penalty spot and football at the bottom, night stadium, floodlights, crowd silhouettes, grass texture, cartoon sports game background, tense match atmosphere.

## UI 提示词

### 中文提示词

体育游戏UI，巨大54321倒计时数字，强对比，高紧张感，足球点球大战比分板，鼠标拖拽箭头，力量条，扑救方向提示，街机体育游戏风格，清晰易读。

### 英文提示词

sports game UI, huge 54321 countdown numbers, high contrast, tense atmosphere, football penalty shootout scoreboard, mouse drag arrow, power meter, save direction indicator, arcade sports game style, clear and readable.

## 音效清单

必须音效：

- 裁判哨声。
- 踢球声。
- 扑救声。
- 球网声。
- 倒计时滴答声。
- 进球欢呼。
- 扑救成功欢呼。
- 射失叹息。

建议音效：

- 心跳声。
- 慢动作启动音。
- 足球飞行声。
- 门柱撞击声。
- 最后一球紧张背景音。

## 素材命名建议

- player_idle
- player_run
- player_kick
- player_celebrate
- player_miss
- keeper_idle
- keeper_dive_left
- keeper_dive_right
- keeper_catch_center
- keeper_kick_save
- keeper_celebrate
- keeper_fail
- field_background
- goal
- net
- ball
- ball_shadow
- ball_trail
- ui_countdown_5
- ui_countdown_4
- ui_countdown_3
- ui_countdown_2
- ui_countdown_1
- ui_scoreboard
- ui_drag_arrow
- ui_power_meter

## 素材优先级

第一优先级：

- 点球手基础动作。
- 守门员基础动作。
- 足球。
- 球门球网。
- 球场背景。
- 倒计时数字。
- 拖拽箭头。
- 比分板。

第二优先级：

- 裁判。
- 观众席。
- 中线列队队员。
- 球网震动。
- 足球拖尾。
- 心跳和倒计时音效。

第三优先级：

- 慢动作回放。
- 表情变化。
- 残影特效。
- 胜负界面。
- 多球衣颜色。
