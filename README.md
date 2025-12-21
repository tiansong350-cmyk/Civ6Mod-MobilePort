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
