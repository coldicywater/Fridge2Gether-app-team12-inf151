# Fridge2Gether (iOS)

INF 151 Team 12。用 SwiftUI 按 Figma Make 原型重写的原生 iOS app，数据存在 Firebase，室友之间实时同步。

## 第一次运行（大约 15 分钟）

### 1. 装 XcodeGen（只需一次）

项目用 `project.yml` 生成 Xcode 工程，避免多人改 `.xcodeproj` 冲突。

```bash
brew install xcodegen
```

没有 Homebrew 的话先装：https://brew.sh

### 2. 建 Firebase 项目（免费 Spark 方案就够）

1. 打开 https://console.firebase.google.com ，新建项目（可以关掉 Google Analytics）。
2. 点 iOS 图标添加 app，Bundle ID 填 `edu.uci.team12.fridge2gether`。
3. 下载 `GoogleService-Info.plist`，放进这个仓库的 `Fridge2Gether/` 文件夹（和 `App/`、`Views/` 同级）。后面几步 SDK 安装指引都可以直接跳过。
4. 左侧 **Build → Authentication → Get started → Sign-in method**，打开 **Anonymous**。
5. 左侧 **Build → Firestore Database → Create database**，选离你近的区域，选 production mode。
6. 进 Firestore 的 **Rules** 标签，把仓库里 `firestore.rules` 的内容整段贴进去，点 Publish。

> 不需要 Firebase Storage，也不需要升级 Blaze 付费方案。食物贴纸图片压缩后直接存在 Firestore 里。

### 3. 放 DeepSeek API key

`Secrets.xcconfig` 已经填好 key。这个文件在 `.gitignore` 里，不会被推到 GitHub。队友 clone 之后自己复制一份：

```bash
cp Secrets.example.xcconfig Secrets.xcconfig
# 然后把里面的 key 换成真的
```

### 4. 生成工程并运行

```bash
cd 这个文件夹
xcodegen
open Fridge2Gether.xcodeproj
```

第一次打开 Xcode 会自动下载 Firebase 包，等左边 Package Dependencies 转完。

- 跑模拟器：顶部选一个 iPhone 模拟器，按 ▶。模拟器没有相机，扫描页会让你从相册选图（把食物照片拖进模拟器就能进相册）。
- 跑真机：iPhone 用线连 Mac，Xcode 里点项目 → Signing & Capabilities → Team 选你的 Apple ID。手机第一次要去 设置 → 通用 → VPN与设备管理 里信任开发者。抠图（Vision subject lifting）只在真机上有效。

改了 `project.yml` 或新增/删除 Swift 文件后，重新跑一次 `xcodegen`。

## 测试室友共享

需要两台设备（两台模拟器或一台模拟器一台手机都行），每台设备是一个独立用户：

1. 设备 A：输入名字 → With roommates → Start a new fridge，记下 6 位邀请码。
2. 设备 B：输入名字 → With roommates → Join a roommate's fridge，输入邀请码。
3. A 扫描食物，设成 Everyone，B 的 Shared 区立刻出现。
4. A 把快过期的食物点开 → Share it with... → 选 B。B 首页出现提醒，点 I'll Take It 认领。

想重置成新用户：删掉 app 重装。

## 和原型的对应关系

| 原型 (App.tsx) | iOS 文件 |
|---|---|
| Onboarding | `Views/Onboarding/OnboardingView.swift` |
| Home + Fridge 三个区 | `Views/Home/MainView.swift`, `FridgeView.swift` |
| CategoryScreen | `Views/Home/MainView.swift` 里的 `CategoryView` |
| DetailSheet + PortionSelector | `Views/Detail/FoodDetailSheet.swift` |
| Camera + FoodForm (Review & Edit) | `Views/Scan/ScanFlowView.swift`, `ReviewEditView.swift` |
| RecipesScreen（列表/详情/做饭/更新用量） | `Views/Recipes/` |
| localStorage 状态 | `Store/AppStore.swift`（Firestore 实时同步） |
| 头像 → 编辑资料 | `Views/Home/ProfileSheet.swift` |

### 为了做成真 app 改动的地方

- **室友用邀请码加入**：原型里是手动输入室友名字，真实同步需要每个室友是真实账号，所以改成"建冰箱拿邀请码 / 输邀请码加入"（和 Week 3 流程图里的 Join / Create Fridge 一致）。
- **识别和菜谱是真 AI**：拍照后 DeepSeek (`deepseek-flash`) 识别食物、数量、保质期和位置，Apple Vision 把每个食物抠成贴纸；菜谱由 AI 根据冰箱里的东西生成，优先用快过期的。菜谱图片用 emoji 卡片代替。
- **首页提示**：按组会笔记，把 "fresh & happy" 换成了快过期提醒。
- **用量设成 Empty 会直接移除**这个食材。
- **过期提醒**是本地通知（过期前一天早上 9 点），不需要服务器或付费开发者账号。

## 数据结构（Firestore）

```
users/{uid}                  name, fridgeId
fridges/{fridgeId}           inviteCode, memberIds[], memberNames{uid:name}
  foods/{foodId}             name, imageData(base64), expiry, amount, fullAmount, unit,
                             ownerId, ownerName, sharing(justMe|everyone|selected), sharedWith[]
  offers/{offerId}           foodId, foodName, fromId, fromName, recipientIds[],
                             claimedById, dismissedBy[]
```

Freshness 按过期天数算：≤1 天红圈 (urgent)，≤3 天黄圈 (soon)，其余正常。

## 注意

- API key 打包在 app 里，课程 demo 没问题；如果要上 App Store，应该改成走自己的服务器转发。
- key 已经在聊天里出现过，项目结束后建议在 DeepSeek 后台换一个新的。
