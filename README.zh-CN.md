[English](README.md) | [中文](README.zh-CN.md)

# 文明6移动端Mod（iPad移植版）

PC版文明6 mod的移动端（主要是iPad）移植版本。

> ⚠️ **开发设备**：11寸 iPad Pro，不确定其他设备是否通用。如有问题欢迎反馈！

---

## 📦 Mod 列表

| Mod | 功能 | 原作者 |
|-----|------|--------|
| **Quick Deals** | 显示所有AI对你物品的报价 | wltk |
| **Detailed Map Tacks** | 自动计算地图钉位置的产出和相邻加成 | wltk, DeepLogic |
| **Extended Policy Cards** | 政策卡底部显示具体产出数值 | Aristos |
| **Force End Turn** | 点击SE按钮强制结束回合（等同PC的Shift+Enter） | Song |

---

## 📥 安装方法

1. 从 [Releases](../../releases) 下载你需要的mod压缩包
2. 解压后将文件夹复制到iPad的mod目录
3. 在游戏中启用mod

**iPad mod目录位置**：  
`文件 → 我的iPad → Civilization VI → Mods`

### 📹 视频教程
- [B站 - iPad Mod安装教程](https://www.bilibili.com/video/BV1shv6eqEqf/)

### 📖 详细图文教程
详细安装步骤可参考贴吧用户 **Toringel** 的[教程帖](https://tieba.baidu.com/p/5491508467)。

**关键步骤摘要**：
1. 用数据线连接iPad到电脑，使用iTunes/iTools/爱思助手
2. 找到Civ VI应用 → 文件共享 → Mods文件夹
3. 导入mod文件夹
4. 如果领袖mod图片不显示：将`Platforms/Windows`文件夹内容复制到`Platforms/iOS`（i小写，OS大写）

---

## 🔗 更多Mod下载

**文明6 Mod下载网站**：  
[SMods 文明6目录](https://catalogue.smods.ru/archives/category/mod?app=289070) - 非常全面的Civ6 mod合集

---

## ⚠️ PC Mod在iPad上的兼容性

| Mod类型 | 兼容性 |
|---------|--------|
| **非UI类mod**（作弊菜单、地图编辑器等） | ✅ 通常可以直接使用 |
| **涉及UI修改的mod** | ⚠️ 不一定能用，需要测试 |
| **领袖/文明mod** | ⚠️ 可以加载但图片可能不显示（参考上方教程修复） |

---

## 🎮 Mod 详情

### Quick Deals（快速交易）
快速查看所有AI对你物品的报价，一键找到出价最高者。

**移植改动**：
- 删除`<FrontEndActions>`（iPad不支持）
- 移除config目录
- 用`SetHide()`替代Context切换

---

### Detailed Map Tacks（高级地图钉）
自动计算地图钉位置的产出和相邻加成。

**移植改动**：
- 删除`ReplaceUIScript`（iPad不支持）
- 新增Hook机制替代脚本替换
- 使用`ContextPtr:LookUpControl`动态挂载

---

### Extended Policy Cards（政策卡收益显示）
在政策卡底部显示具体的产出效果数值。

**移植改动**：
- 将RealModifierAnalysis模块内联（消除外部依赖）
- 调整modinfo加载顺序

---

### Force End Turn（强制结束回合）
点击右上角的SE按钮强制跳过回合。

**特点**：
- 极简设计，右上角小字"SE"
- 点击即触发，无需长按
- 不干扰游戏界面

---

## ⚖️ 许可

本仓库仅用于学习和个人使用。原mod版权归各原作者所有。

---

*移植工作由 [Song](https://github.com/tiansong350-cmyk) 完成，借助 Antigravity AI 辅助开发*
