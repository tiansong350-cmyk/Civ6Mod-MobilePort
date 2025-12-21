# Civilization VI Mod 移植复盘汇总

本文档记录了将PC版CIV6 mod移植到iPad的详细复盘，包括问题诊断、解决方案、难度评估和经验总结。

---

# 1. Quick Deals (快速交易)

## 📋 基本信息

| 项目 | 内容 |
|------|------|
| **Mod名称** | Quick Deals (快速交易) |
| **原作者** | wltk |
| **功能** | 显示所有AI对你物品的报价，快速找到出价最高者 |
| **原版平台** | PC (Steam) |
| **目标平台** | iPad |

---

## 🔍 问题诊断

### PC版为什么在iPad上不工作？

iPad版CIV6对**UI Context系统**的支持与PC版不同。PC版Quick Deals使用了以下PC专属特性：

| 不兼容特性 | 说明 |
|-----------|------|
| **`<FrontEndActions>`** | iPad不支持前端配置界面 |
| **多Context UI切换** | iPad对动态Context加载支持有限 |
| **`config/` 目录** | iPad不支持mod配置选项 |
| **复杂的Tab Context系统** | 原版用独立Context实现标签页切换 |

---

## ✏️ 修改内容详解

### 1. modinfo 文件修改

```diff
- <FrontEndActions>
-   <UpdateDatabase id="qd_config">
-     <File>config/qd_config.xml</File>
-   </UpdateDatabase>
-   <UpdateText id="qd_options_text">
-     <File Priority="1">config/en_us/qd_options_text.xml</File>
-   </UpdateText>
- </FrontEndActions>
```

**删除了整个`<FrontEndActions>`块**
- 原因：iPad不支持mod配置界面
- 影响：玩家无法自定义mod设置（但核心功能不受影响）

### 2. 删除config目录

整个`config/`目录被移除：
- `config/qd_config.xml`
- `config/en_us/qd_options_text.xml`

### 3. 创建简化的单文件UI (核心修改)

原版架构：
```
qd_popuptab_sale.lua    ─┐
qd_popuptab_purchase.lua ├─ 独立Context，动态加载
qd_popuptab_exchange.lua─┘
```

iPad版架构：
```
qd_ipad.lua ─── 单文件包含所有标签页逻辑
              └── 用SetHide()切换显示，不用Context切换
```

**关键代码变化：**

```lua
-- 原版：复杂的Context切换
LuaEvents.QD_PopupShowTab.Add(function(tabType)
    ContextPtr:SetHide(true);  -- 隐藏当前Context
    -- 加载新Context...
end);

-- iPad版：简单的Container显隐
function SwitchToTab(tabType)
    Controls.SaleContent:SetHide(true);
    Controls.PurchaseContent:SetHide(true);
    Controls.ExchangeContent:SetHide(true);
    
    if tabType == TAB_TYPE.SALE then
        Controls.SaleContent:SetHide(false);
    end
end
```

---

## 🎯 难度评估

| 维度 | 评分 (1-10) | 说明 |
|------|-------------|------|
| **问题诊断** | 7 | 需要理解CIV6的Context系统差异 |
| **代码修改** | 6 | 需要重写标签页切换逻辑 |
| **测试验证** | 5 | 需要iPad真机测试 |
| **总体难度** | **6/10** | 中等偏难 |

---

## ⚠️ 重要反思：过度工程化警示

> **这是一个"换火花塞被搞成发动机大修"的典型案例**

### 实际问题 vs 最终方案

| 实际问题 | 理论上的最小修改 | 实际修改 |
|----------|------------------|----------|
| UI整体尺寸过大 | 改XML的Size参数 | 删除config目录 |
| 标签被原生UI遮挡 | 改XML的Offset参数 | 新增439行lua文件 |
| 左右超出屏幕 | 调整容器宽度 | 重写标签页系统 |

**PC原版在iPad上是可以运行的，功能完全正常，只是UI显示超出屏幕。**

### 教训归档

1. **坚持最小作用量原理** - 一次只改一处，验证后再继续
2. **区分"不能用"和"显示不对"** - 功能正常时不要碰逻辑代码
3. **保留每个版本** - 可以回溯定位问题
4. **用户直觉很重要** - 用户说"只是UI太大"，应该相信

---

## 📌 案例定性

**类型**: 过度工程化反面教材 → **存疑，需要进一步验证**  
**根因**: AI未遵循最小修改原则 + 无调试环境 + 误诊问题类型  
**结果**: 能用，但过程浪费了大量时间，最终方案可能过度复杂

---

# 2. Detailed Map Tacks (高级地图钉)

## 📋 基本信息

| 项目 | 内容 |
|------|------|
| **Mod名称** | Detailed Map Tacks (高级地图钉) |
| **原作者** | wltk, DeepLogic, JamieNyanchi |
| **功能** | 自动计算地图钉位置的产出和相邻加成 |
| **原版平台** | PC (Steam) |
| **目标平台** | iPad |

---

## 🔍 问题诊断

### PC原版在iPad上的表现

| 症状 | 严重程度 |
|------|----------|
| 地图钉**图标不显示** | 严重 |
| 地图钉**列表可见** | 部分功能 |
| 没有任何数值显示 | 完全失效 |

**这与Quick Deals不同 —— Quick Deals功能正常只是UI太大，而Detailed Map Tacks根本无法工作。**

### 根本原因：`ReplaceUIScript`在iPad上失效

PC版使用`ReplaceUIScript`来替换游戏原生的MapPinManager.lua：

```xml
<!-- PC版 modinfo -->
<ReplaceUIScript id="mappinmanager">
  <LuaContext>MapPinManager</LuaContext>
  <LuaReplace>ui/mappinmanager_dmt.lua</LuaReplace>
</ReplaceUIScript>
```

**iPad版CIV6不支持`ReplaceUIScript`**，这个标签被完全忽略。
- 结果：mod的lua代码从未被加载
- 游戏使用原生MapPinManager.lua，不知道DMT的扩展
- 地图钉图标无法正确渲染

---

## 🔧 修复过程（V1 - V39迭代记录）

### 阶段一：尝试标准方法（V1-V9）

| 版本 | 尝试 | 结果 |
|------|------|------|
| V1-V5 | 用`pcall`包装防止崩溃 | 仍然不工作 |
| V7 | 暴力`include`多种大小写 | 失败 |
| V9 | 完全复制替换整个lua | 损坏 |

### 阶段二：发现问题本质（V10-V16）

| 版本 | 发现 | 说明 |
|------|------|------|
| V10 | 钉子出现了 | XML替换成功 |
| V12 | 感叹号到处都是 | 说明XML被使用，但脚本逻辑未运行 |
| V14 | ReplaceUIScript被忽略 | iPad不支持此功能 |
| V16 | 钉子出现但没数字 | 确认需要"Hook"方案 |

### 阶段三：Hook方案（V18-V21）

```lua
-- V18核心思路：不替换脚本，而是"钩住"原有逻辑
-- 1. 用AddUserInterfaces加载我们的脚本
-- 2. 用ContextPtr:LookUpControl找到原有UI
-- 3. 监听相同的Events
-- 4. 直接操作UI控件
```

### 最终方案（V39）

| 改动 | 说明 |
|------|------|
| 删除`ReplaceUIScript` | 因为iPad不支持 |
| 新增`dmt_hook.lua/xml` | 在根目录创建单独的hook模块 |
| 替换mappinmanager_dmt.lua → MapPinManager.lua | 使用完整替代而非修补 |
| 提高`LoadOrder`到20000 | 确保后加载 |
| 在XML中添加调试框 | 用于无日志环境下的可视化调试 |

---

## 🎯 难度评估

| 维度 | 评分 (1-10) | 说明 |
|------|-------------|------|
| **问题诊断** | 9 | 需要理解iPad对mod系统的限制 |
| **代码修改** | 8 | 需要重写整个hook机制 |
| **测试验证** | 9 | 无日志，需创造性调试方法 |
| **总体难度** | **8.5/10** | 高难度 |

---

## 🔑 核心经验总结

### iPad的真正限制

1. **`ReplaceUIScript`不工作** - 无法替换游戏原生lua脚本
2. **`include()`路径可能不同** - 大小写敏感问题
3. **无调试日志** - 必须用可视化方法调试

### Hook模式（适用于无法替换脚本的情况）

```lua
-- 1. 用AddUserInterfaces加载自己的Context
-- 2. 用LookUpControl找到目标UI
local TargetContext = ContextPtr:LookUpControl("/InGame/MapPinManager");

-- 3. 监听相同的游戏事件
Events.MapPinPlayer_MapPinAdded.Add(OnMapPinChanged);

-- 4. 直接操作目标UI的子控件
local children = TargetContext:GetChildren();
for i, child in ipairs(children) do
    child:LookUpControl("YieldText"):SetText("+5");
end
```

---

## 📌 案例定性

**类型**: 正向技术攻关案例  
**根因**: iPad对mod系统的架构限制（ReplaceUIScript失效）  
**结果**: 成功，方案复杂度与问题难度匹配  
**教训**: 这是一个真正需要重写的案例，不是过度工程化

---

# 3. Extended Policy Cards (扩展政策卡显示效果)

## 📋 基本信息

| 项目 | 内容 |
|------|------|
| **Mod名称** | Extended Policy Cards (扩展政策卡显示效果) |
| **原作者** | Aristos |
| **依赖** | Better Report Screen (BRS) by Infixo |
| **功能** | 在政策卡底部显示具体的产出效果数值 |
| **原版平台** | PC (Steam) |
| **目标平台** | iPad |

---

## 🔍 问题诊断

### 为什么这在iPad上是问题？

1. **依赖管理困难** — iPad上管理多个mod的加载顺序很麻烦
2. **BRS太大** — Better Report Screen有几十个文件，用不到大部分功能
3. **只需要RMA** — Extended Policy Cards只需要BRS中的`RealModifierAnalysis`模块

---

## 🛠️ 修复策略：依赖内联

**核心思路**：把需要的依赖直接复制进来，消除外部依赖。

### iPad版的结构

```
Extended_Policy_Cards_iPad
├── Extended Policy Cards.modinfo   ← 大幅修改
├── BetterReportScreen_Database.sql ← 从BRS复制
├── RealModifierAnalysis.lua        ← 从BRS复制（核心！）
├── RealModifierAnalysis.xml        ← 从BRS复制
├── GovernmentScreen.lua            ← 几乎不变
└── GovernmentScreen.xml            ← 不变
```

---

## 🎯 难度评估

| 维度 | 评分 (1-10) | 说明 |
|------|-------------|------|
| **问题诊断** | 4 | 依赖关系明确，容易理解 |
| **代码修改** | 3 | 主要是复制文件和改modinfo |
| **测试验证** | 4 | 需要确认加载顺序正确 |
| **总体难度** | **3.5/10** | 低难度 |

---

## 🔑 核心经验总结

### "依赖内联"策略

当一个mod依赖另一个大mod时：
1. 分析实际需要哪些文件
2. 只提取需要的部分
3. 用modinfo控制加载顺序
4. 修改mod ID避免冲突

---

## 📌 案例定性

**类型**: 正向教科书案例  
**根因**: PC版依赖外部mod，iPad需要独立运行  
**策略**: 依赖内联（Dependency Inlining）  
**结果**: 成功，改动量与问题难度匹配  
**可复制性**: 高 — 任何有外部依赖的mod都可以用这个方法

---

# 4. Force End Turn (强制结束回合)

## 📋 基本信息

| 项目 | 内容 |
|------|------|
| **Mod名称** | Force End Turn (强制结束回合) |
| **原作者** | Song |
| **功能** | 点击SE按钮强制跳过回合（等同于PC版Shift+Enter） |
| **原版平台** | 无（原创mod） |
| **目标平台** | iPad |

---

## 🔧 版本迭代历程

### V6-V7: 独立浮动按钮（完全失败）

**方案：** 创建独立的Container和Button，尝试用绝对定位放在屏幕右上角。

**问题：**
- ❌ 独立创建的UI元素根本不显示
- ❌ 移动端可能不支持这种"凭空"创建并定位的UI方式

**教训：** 移动端Civ6的UI系统与PC可能有差异，独立浮动元素不可靠。

---

### V8: 模仿CME的LoadOrder + ImportFiles（失败）

**方案：** 添加 `LoadOrder`、`ImportFiles` 导入自定义图标，认为是modinfo格式问题。

**问题：**
- ❌ 仍然什么都不显示
- ❌ 方向错误 —— 问题不在modinfo，而在UI挂载方式

**教训：** 不要盲目复制参数，要理解核心逻辑。

---

### V9: 动态挂载到TopPanel（部分成功）

**方案：** 发现CME的关键代码：
```lua
local tPanRightStack = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents");
Controls.CmeLaunchBarBtn:ChangeParent(tPanRightStack);
tPanRightStack:AddChildAtIndex(Controls.CmeLaunchBarBtn, 3);
```

**问题：**
- ✅ 按钮终于出现了！
- ❌ 索引99导致按钮在回合数下方被遮挡
- ❌ 使用 `LaunchBar_Hook_GovernmentButton` 纹理导致点击上移动画
- ❌ `eMouseDown/eMouseUp` 回调在触摸设备上可能有问题

**教训：** 动态挂载是正确方向，但细节处理还需调整。

---

### V10: 纯文字按钮 + 正确索引（成功！）

**方案：**
1. 移动整个Container而不是Button
2. 使用索引4放在回合数右侧
3. **关键：去掉Button的Texture属性** → 意外变成透明底的纯文字
4. 使用 `Mouse.eLClick` 简单点击回调

**结果：**
- ✅ 位置正确，不被遮挡
- ✅ 无点击动画干扰
- ✅ 功能正常工作
- ✅ 极简设计，不干扰游戏界面

---

## 🎯 难度评估

| 阶段 | 难度 | 原因 |
|------|------|------|
| 初始方案 | 3级 | 看起来简单 |
| 实际调试 | 8级 | 移动端UI机制不透明，需要逆向分析CME |
| 最终解决 | 5级 | 理解核心逻辑后其实不难 |

**总迭代次数：** 5个版本（V6→V10）
**总测试轮次：** 约6-7次iPad部署测试

---

## 🔑 关键学习点

| 问题 | 错误方向 | 正确方向 |
|------|---------|---------|
| UI不显示 | 调整modinfo格式 | 动态挂载到现有UI容器 |
| 位置问题 | 用绝对Offset定位 | 用AddChildAtIndex控制顺序 |
| 点击动画 | 调整回调方式 | 去掉Texture属性 |
| 长按功能 | 复杂的eMouseDown/Up | 简单eLClick就够用 |

---

## 💡 工程思维启发

### 1. 需求抽象的力量

原始需求：长按避免误触  
抽象需求：防止误操作

更优解：**缩小点击区域**（通过去掉Texture只留文字）

> **"最好的解决方案往往不是直接回答问题，而是重新定义问题。"**

### 2. 减法设计

去掉Texture后：
- Button变透明
- 只有Label的文字区域响应点击
- **天然**形成了一个极小的点击热区

通过**移除元素**反而获得更好的效果。

### 3. 拥抱"意外"

去掉Texture是为了解决动画问题，却意外解决了误触问题。调试中的副作用有时是更好的解决方案。

---

## 📌 案例定性

**类型**: 正向技术攻关 + 意外惊喜案例  
**根因**: 需要理解移动端UI挂载机制  
**结果**: 成功，最终方案比预期更简洁  
**教训**: 简单即是终极的复杂

---

# 总结：iPad mod移植通用法则

## 1. iPad的主要限制

| 限制 | 说明 |
|------|------|
| `ReplaceUIScript`不工作 | 无法替换游戏原生lua脚本 |
| `FrontEndActions`不支持 | 无法添加mod配置界面 |
| 动态Context加载受限 | 用SetHide()代替Context切换 |
| 无调试日志 | 需要可视化方法调试 |

## 2. 通用解决策略

| 问题类型 | 策略 |
|----------|------|
| 需要替换脚本 | 使用Hook模式 |
| 有外部依赖 | 依赖内联 |
| UI不显示 | 动态挂载到现有容器 |
| 无法调试 | 在XML中创建可见的DebugLabel |

## 3. 调试技巧

1. 在Lua中大量使用`print()`输出
2. 在XML中创建可见的`Label`作为调试输出
3. 保留每个版本以便回溯
4. 分析已有成功案例（如CME）的核心代码

---

*文档更新日期：2025-12-21*
