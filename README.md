# 🔓 Unlock Alert — 代币解锁预警 iOS App

> 币圈散户的「代币解禁日历」— 再也不用被团队/VC解锁砸盘

---

## 这是什么？

追踪**代币解锁事件**的 iOS App。关注任意代币，在解锁前自动推送通知提醒你。

**核心功能：**
- 📋 所有代币的解锁时间表（按时间排序）
- 🔔 解锁前 7天/3天/1天/当日推送通知
- 💰 显示解锁金额（USD）和占总流通百分比
- ⭐ 关注列表，只看你关心的币
- 🔍 搜索代币

---

## 🧱 技术架构

```
┌─────────────────────────────┐
│      iOS App (SwiftUI)       │
│  Firestore SDK + Cloud Msg   │
└──────────┬──────────────────┘
           │ 读取解锁数据
           ▼
┌─────────────────────────────┐
│    Firebase Firestore        │  ← 数据存储，免费
│    (Google Cloud)            │
└──────────┬──────────────────┘
           │ 每天 UTC 2:00 更新
           ▼
┌─────────────────────────────┐
│  Cloud Functions (Node.js)   │  ← 数据抓取+推送，免费
│  + GitHub Actions            │
└─────────────────────────────┘
```

| 组件 | 用途 | 费用 |
|:---|---|:---:|
| Firebase Firestore | 存代币解锁数据 | **免费**（<1GB） |
| Firebase Cloud Messaging | 推送通知 | **免费** |
| Firebase Cloud Functions | 定时更新数据 | **免费**（<200万次/月） |
| GitHub Actions | 每日自动抓数据 | **免费** |
| CoinGecko API | 获取币价/市值 | **免费** |
| Apple Developer | App Store 上架 | **$99/年**（唯一成本） |

---

## 🚀 部署教程（约30分钟）

### 第一步：注册 Firebase

1. 打开 [console.firebase.google.com](https://console.firebase.google.com)
2. 创建项目 → 名称填 `UnlockAlert`
3. 禁用 Google Analytics（可选）
4. 左侧菜单 → **Firestore Database** → 创建数据库
   - 位置选 `asia-east2`（香港，离中国近）
   - 安全规则选「测试模式」
5. 左侧菜单 → **Authentication** → 开始使用
   - 添加 `Anonymous` 登录（让用户无需注册也能关注）

### 第二步：下载 Firebase 配置

1. ⚙️ 项目设置 → 常规 → 您的应用 → **iOS 应用**
2. 填写 Bundle ID: `com.yourname.UnlockAlert`
3. 下载 `GoogleService-Info.plist`
4. 把这个文件放到: `ios/UnlockAlert/Resources/GoogleService-Info.plist`

### 第三步：初始化 Firestore 数据

```bash
# 安装 Firebase CLI
npm install -g firebase-tools

# 登录 Firebase
firebase login

# 进入项目目录
cd UnlockAlert

# 关联 Firebase 项目
firebase use --add
# 选择刚才创建的 UnlockAlert 项目

# 部署 Firestore 规则
firebase deploy --only firestore

# 写入初始数据
cd scripts
npm install firebase-admin
GOOGLE_APPLICATION_CREDENTIALS=../functions/service-account.json node seedData.js
```

### 第四步：部署 Cloud Functions

```bash
# 在 Firebase 控制台升级项目为 Blaze 计划（按用量计费）
# 注意：Cloud Functions 需要 Blaze 计划，但免费额度足够用
# Firestore 本身仍免费

# 部署 Functions
cd ../functions
npm install
cd ..
firebase deploy --only functions

# 设置环境变量（可选，有CoinGecko API key更好）
firebase functions:config:set coingecko.api_key=""
```

### 第五步：配置 GitHub Actions 自动化

1. 创建 Firebase 服务账号密钥：
   - Firebase 控制台 → ⚙️ → 服务账号 → 生成新私钥
   - 下载 JSON 文件
2. GitHub 仓库 → Settings → Secrets → 添加 `FIREBASE_SERVICE_ACCOUNT`
   - 值：上一步下载的 JSON 文件内容
3. Push 到 GitHub

### 第六步：打开 Xcode 运行 App

```bash
# 确保已安装 CocoaPods
cd ios
pod init
# 编辑 Podfile 添加 Firebase 依赖
pod install
```

或者用 Swift Package Manager（推荐）：
- 在 Xcode 中打开 `ios/` 目录
- File → Add Package Dependencies → 搜索 `firebase-ios-sdk`
- 勾选 `FirebaseFirestore`、`FirebaseMessaging`、`FirebaseAnalytics`

然后：
1. 把 `GoogleService-Info.plist` 拖进 Xcode 项目
2. 选择真机或模拟器运行
3. 第一次启动会请求通知权限，点「允许」

---

## 📱 App Store 上架注意事项

| 项目 | 说明 |
|:---|---|
| **分类** | 工具 / 财务 |
| **年龄分级** | 4+ |
| **隐私政策** | 需要准备一份（简单声明不收集用户数据即可） |
| **审核风险** | 🟢 **低** — 该 App 仅展示公开数据，不含交易/钱包/金融建议 |
| **免责声明** | 已在设置页面内置，建议在 App Store 描述中也加上 |
| **费用** | Apple Developer **$99/年**（唯一硬性成本） |

> 推荐在 App Store 描述中加入：
> ```
> Unlock Alert 不提供投资建议。
> 所有数据来源于 CoinGecko 等公开 API，
> 仅供参考，不构成买卖建议。
> ```

---

## 🔧 后续扩展方向

| 功能 | 复杂度 | 说明 |
|:---|:---:|:---|
| 代币解锁日历视图 | ⭐ | 日历形式的解锁时间线 |
| 解锁历史与价格对比 | ⭐⭐ | 过去解锁后价格跌了多少 |
| 中英文多语言 | ⭐ | 切换语言 |
| Widget（桌面小组件） | ⭐⭐ | 桌面显示即将解锁 |
| 自定义推送时间 | ⭐ | 用户设置提前几天推送 |
| 关注数/解锁热度排行 | ⭐ | 最多人关注的解锁事件 |
| Apple Watch 支持 | ⭐⭐⭐ | 手表查看解锁提醒 |

---

## License

MIT — 随便用，欢迎 PR。
