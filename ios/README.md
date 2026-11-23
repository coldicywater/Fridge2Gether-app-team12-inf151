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

### 3. 部署 AI 转发服务器（Cloudflare Worker，免费）

DeepSeek key 不放在 app 里，放在 Cloudflare Worker 上。app 带着用户的 Firebase 登录凭证请求 Worker，Worker 验证通过后再用 key 调 DeepSeek。代码在仓库根目录 `ai-proxy/worker.js`。

网页操作（手机也能做）：

1. 注册 / 登录 https://dash.cloudflare.com → **Workers & Pages** → **Create** → **Create Worker**，名字填 `fridge2gether-ai`，点 Deploy。
2. 点 **Edit code**，把 `ai-proxy/worker.js` 整段贴进去替换原来的代码，点 **Deploy**。
3. 回到这个 Worker → **Settings → Variables and Secrets**：
   - 加 **Secret** `DEEPSEEK_API_KEY`，值是 DeepSeek key（建议在 DeepSeek 后台新建一个，旧的在聊天里出现过）
   - 加 **Text** `FIREBASE_PROJECT_ID`，值在 Firebase 控制台 → 齿轮 → Project settings → General → Project ID
4. 记下 Worker 的地址，形如 `fridge2gether-ai.你的名字.workers.dev`。

或者在 Mac 上用命令行：`cd ai-proxy`，改好 `wrangler.toml` 里的 project ID，然后 `npx wrangler deploy` 和 `npx wrangler secret put DEEPSEEK_API_KEY`。

然后在 app 这边：

```bash
cp Secrets.example.xcconfig Secrets.xcconfig
# 把 AI_PROXY_HOST 换成上面记下的地址（不要写 https://）
```

`Secrets.xcconfig` 在 `.gitignore` 里，不会被推到 GitHub。

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

## 新手引导

- **介绍页**（`Views/Onboarding/IntroView.swift`）：新用户第一次打开，先看 3 页一句话介绍，再输名字、建冰箱或加入冰箱。
- **动手引导**（`Views/Tutorial/TutorialOverlay.swift`）：进入冰箱后自动开始，是一条连贯的流程，用户要真的点按钮、拍照、做菜。屏幕变暗，高亮要点的地方；卡片上写 "Your turn" 的步骤要用户自己去点，其他步骤点 Next：
  1. **Add food**：点相机 → 拍一张（没相机就从相册选）→ Review & Edit 里介绍名字、数量、日期、共享 → 点 Add 保存
  2. **Your fridge**：指着刚拍的食物，讲外圈颜色（白 / 黄 / 红），Personal、Shared（有室友才有），快过期横幅和过期通知
  3. **Chat**：点开聊天 → + 和输入框 → 关掉
  4. **Roommates**：点头像 → 邀请码让冰箱变成多人共享 → 切换冰箱 → 关掉
  5. **Recipes**：点 Recipes → 选食材 → Make recipes → 打开一道菜 → Start Cooking → 一步步做到 Finish → 更新剩余用量
- 中途关掉某个页面会自动回到那一段的开头（比如没拍照就关了相机，会再提示点相机）。
- 页面上没有的东西自动跳过（比如没室友就不讲 Shared）。
- 随时可以点 **Skip tour** 跳过。想再看一次：头像 → **Show app tutorial**。
- 想重新看介绍页：删掉 app 重装。

## 冰箱群聊

首页和菜谱页右上角，头像左边的气泡按钮。每个冰箱一个群，成员就是共享这个冰箱的室友，切换冰箱就换群。有新消息时按钮上有红色数字。

- 普通文字消息
- **+ → Ask for food**：发请求卡片，别人点 "I've got it"
- **+ → Offer my food**：选自己的食物分享给所有人，室友在群里点 I'll Take It 认领
- **自动提示**（灰色小字）：加入共享食物、用掉一部分、用完、认领、做菜用了共享食材、有人加入或离开。只提示设成 Everyone 的食物，Just Me 和 Selected 的不会出现在群里

**升级注意**：`firestore.rules` 新增了 `messages` 规则，要重新整段贴到 Firebase 控制台的 Rules 里点 Publish，不然发不出消息。新增了 `Views/Chat/ChatView.swift`，要重新跑一次 `xcodegen`。

## 和原型的对应关系

| 原型 (App.tsx) | iOS 文件 |
|---|---|
| Onboarding | `Views/Onboarding/OnboardingView.swift` |
| Home + Fridge（一个人只有 Personal，有室友时 Personal + Shared） | `Views/Home/MainView.swift`, `FridgeView.swift` |
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
users/{uid}                  name, fridgeId (当前打开的冰箱), fridgeIds[] (加入的所有冰箱)
fridges/{fridgeId}           inviteCode, memberIds[], memberNames{uid:name}
  foods/{foodId}             name, imageData(base64), expiry, amount, fullAmount, unit,
                             ownerId, ownerName, sharing(justMe|everyone|selected), sharedWith[]
  offers/{offerId}           foodId, foodName, fromId, fromName, recipientIds[],
                             claimedById, dismissedBy[]
  messages/{messageId}       kind(text|event|request|offer), text, senderId, senderName,
                             offerId, fulfilledById, fulfilledByName, createdAt
```

Freshness 按过期天数算：≤1 天红圈 (urgent)，≤3 天黄圈 (soon)，其余正常。

## 上传 TestFlight

1. **重新发布 Firestore 规则**：`firestore.rules` 收紧了加入冰箱的权限（陌生人只能把自己加进去，不能改别人），整段贴到 Firebase 控制台 Rules 里点 Publish。
2. **重新跑 `xcodegen`**（新增了 `PrivacyInfo.xcprivacy`，没有它 App Store Connect 会拒收）。
3. Xcode → 项目 → Signing & Capabilities → Team 选你的付费开发者账号，勾 Automatically manage signing。
4. 在 https://appstoreconnect.apple.com → My Apps → + New App：Bundle ID 选 `edu.uci.team12.fridge2gether`（第 3 步之后会自动注册出来），名字填 Fridge2Gether（被占用就换一个，比如 Fridge2Gether Team12）。
5. Xcode 顶部设备选 **Any iOS Device (arm64)** → Product → **Archive** → Distribute App → **TestFlight & App Store** → Upload。
6. 等 10 到 30 分钟处理完，在 App Store Connect 的 TestFlight 标签里：
   - **内部测试**（团队成员，最多 100 人，不用审核）：Users and Access 里把队友加进团队，再加进 Internal Testing 组。
   - **外部测试**（朋友，用邮箱或公开链接）：要填 Test Information（反馈邮箱、简介、隐私政策链接，可以用仓库里 `PRIVACY.md` 的 GitHub 链接），第一次要过 Beta App Review，一般一天内。
7. 以后每次上传新版本，把 `project.yml` 里的 `CURRENT_PROJECT_VERSION` 加 1，重新 `xcodegen` 再 Archive。同一个版本号不能传两次。

App Store Connect 的 App Privacy 问卷按 `PRIVACY.md` 填：收集 Name、User ID、Photos、Other User Content，都用于 App Functionality，都和用户关联，不用于追踪。

## 注意

- AI 请求只接受已登录 Fridge2Gether 用户，模型和 token 上限由 Worker 决定，app 改不了。想看用量或换 key，只改 Worker 的设置，不用重新发 app。
