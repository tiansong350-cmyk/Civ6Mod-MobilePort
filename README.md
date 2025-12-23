[English](README.md) | [中文](README.zh-CN.md)

# Civilization VI Mobile Mods (iPad Port)

PC Civilization VI mods ported to mobile (mainly iPad).

> ⚠️ **Development Device**: 11-inch iPad Pro. Compatibility with other devices is not guaranteed.

---

## 📦 Mod List

| Mod | Description | Original Author |
|-----|-------------|-----------------|
| **Quick Deals** | Shows all AI offers for your items at once | wltk |
| **Detailed Map Tacks** | Auto-calculates yields and adjacency bonuses for map pins | wltk, DeepLogic |
| **Extended Policy Cards** | Displays actual yield values on policy cards | Aristos |
| **Force End Turn** | Click "SE" button to force end turn (like PC's Shift+Enter) | Song |

---

## 📥 Installation

1. Download the mod zip from [Releases](../../releases)
2. Extract and copy the folder to iPad's mod directory
3. Enable the mod in-game

**iPad mod directory**:  
`Files → On My iPad → Civilization VI → Mods`

### 📹 Video Tutorial (Chinese)
- [Bilibili - iPad Mod Installation Guide](https://www.bilibili.com/video/BV1shv6eqEqf/)

### 📖 Detailed Tutorial
For detailed installation steps, see this [Tieba Tutorial](https://tieba.baidu.com/p/5491508467) by user **Toringel**.

**Key steps summary**:
1. Connect iPad to PC with iTunes/iTools/iFunBox
2. Navigate to Civ VI app → File Sharing → Mods folder
3. Import the mod folder
4. For leader mods with missing images: copy `Platforms/Windows` folder content to `Platforms/iOS` (i lowercase, OS uppercase)

---

## 🔗 More Mods

**Civ6 Mod Download Site**:  
[SMods Civ6 Catalogue](https://catalogue.smods.ru/archives/category/mod?app=289070) - Comprehensive collection of Civ6 mods

---

## ⚠️ PC Mod Compatibility on iPad

| Mod Type | Compatibility |
|----------|---------------|
| **Non-UI mods** (Cheat Menu, Map Editor, etc.) | ✅ Usually works directly |
| **UI-modifying mods** | ⚠️ May or may not work, needs testing |
| **Leader/Civilization mods** | ⚠️ Works but images may not display (see tutorial above for fix) |

---

## 🎮 Mod Details

### Quick Deals
Quickly view all AI offers for your items and find the best deal.

**Changes for iPad**:
- Removed `<FrontEndActions>` (not supported)
- Removed config directory
- Replaced Context switching with `SetHide()`

---

### Detailed Map Tacks
Automatically calculates yields and adjacency bonuses for map pin locations.

**Changes for iPad**:
- Removed `ReplaceUIScript` (not supported on iPad)
- Implemented Hook mechanism
- Uses `ContextPtr:LookUpControl` for dynamic attachment

---

### Extended Policy Cards
Shows actual yield values at the bottom of policy cards.

**Changes for iPad**:
- Inlined RealModifierAnalysis module (removed external dependency)
- Adjusted modinfo load order

---

### Force End Turn
Click the "SE" button in the top-right corner to force end turn.

**Features**:
- Minimal design - small "SE" text
- Single click activation
- Non-intrusive UI

---

## ⚖️ License

For learning and personal use only. Original mod copyrights belong to their respective authors.

---

*Ported by [Song](https://github.com/tiansong350-cmyk) with Antigravity AI assistance*
