#!/bin/bash
# ============================================================
# Unlock Alert — 一键部署脚本
# 在你自己 Mac 上运行一次即可完成所有设置
# ============================================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   🔓 Unlock Alert — 一键部署脚本${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ============================================================
# Step 0: 检查环境
# ============================================================
echo -e "${YELLOW}[0/6] 检查环境...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ 需要安装 Node.js: https://nodejs.org${NC}"
    exit 1
fi
echo -e "  ✅ Node.js $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm 未安装${NC}"
    exit 1
fi
echo -e "  ✅ npm $(npm --version)"

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${YELLOW}  ⚠️  Xcode 未安装（运行 iOS App 需要）${NC}"
    echo -e "    安装命令: xcode-select --install"
fi

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}  ⚠️  git 未安装${NC}"
fi

# ============================================================
# Step 1: 安装 Firebase CLI
# ============================================================
echo ""
echo -e "${YELLOW}[1/6] 安装 Firebase CLI...${NC}"

if command -v firebase &> /dev/null; then
    echo -e "  ✅ Firebase CLI $(firebase --version) 已安装"
else
    # Fix npm cache if needed
    if [ -d ~/.npm/_cacache ]; then
        OWNER=$(stat -f "%Su" ~/.npm/_cacache 2>/dev/null || echo "")
        if [ "$OWNERT" != "$(whoami)" ] && [ -n "$OWNER" ]; then
            echo -e "  🔧 修复 npm 缓存权限..."
            sudo chown -R $(whoami) ~/.npm
        fi
    fi
    
    npm install -g firebase-tools 2>&1 | tail -3
    echo -e "  ✅ Firebase CLI 安装完成"
fi

# ============================================================
# Step 2: 登录 Firebase
# ============================================================
echo ""
echo -e "${YELLOW}[2/6] 登录 Firebase...${NC}"
echo -e "  即将打开浏览器，请用你的 Google 账号登录"
echo -e "  登录后会自动回到终端"
echo ""
read -p "  按 Enter 键继续登录..." 

firebase login --no-localhost 2>&1 | head -10 || firebase login

echo -e "  ✅ Firebase 登录完成"

# ============================================================
# Step 3: 创建 Firebase 项目
# ============================================================
echo ""
echo -e "${YELLOW}[3/6] 创建 Firebase 项目...${NC}"

PROJECT_ID="unlock-alert-$(date +%s | tail -c 6)"
echo -e "  项目ID: ${PROJECT_ID}"
echo -e "  项目名: Unlock Alert"

# 通过 Firebase CLI 创建项目
firebase projects:create "$PROJECT_ID" --display-name "Unlock Alert" 2>&1 || {
    echo -e "  ⚠️  创建失败，请手动在 https://console.firebase.google.com 创建项目"
    echo -e "  创建后输入项目ID:"
    read -p "  Project ID: " PROJECT_ID
}

echo -e "  ✅ 项目 ${PROJECT_ID} 就绪"

# ============================================================
# Step 4: 启用 Firestore
# ============================================================
echo ""
echo -e "${YELLOW}[4/6] 配置 Firestore 数据库...${NC}"

# 使用 gcloud 启用 Firestore（需要先启用 Firestore API）
echo -e "  📋 请在 Firebase 控制台手动完成以下步骤："
echo -e "     1. 打开 https://console.firebase.google.com/project/${PROJECT_ID}/firestore"
echo -e "     2. 点击「创建数据库」"
echo -e "     3. 位置选择 asia-east2（香港）"
echo -e "     4. 安全规则选择「测试模式」"
echo ""
read -p "  完成后按 Enter 继续..."

# 部署 Firestore 规则
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

firebase use "$PROJECT_ID"
firebase deploy --only firestore:rules,firestore:indexes 2>&1 | tail -5

echo -e "  ✅ Firestore 配置完成"

# ============================================================
# Step 5: 写入初始数据
# ============================================================
echo ""
echo -e "${YELLOW}[5/6] 写入初始代币数据...${NC}"

cd "$PROJECT_DIR/scripts"
npm install firebase-admin 2>&1 | tail -3

# 获取服务账号密钥
echo -e "  📋 请在 Firebase 控制台获取服务账号密钥："
echo -e "     1. 打开 ⚙️ → 服务账号"
echo -e "     2. 点击「生成新私钥」"
echo -e "     3. 下载 JSON 文件"
echo -e ""
read -p "  请输入 JSON 文件的完整路径: " SA_PATH

if [ -f "$SA_PATH" ]; then
    cp "$SA_PATH" "$PROJECT_DIR/functions/service-account.json"
    export GOOGLE_APPLICATION_CREDENTIALS="$PROJECT_DIR/functions/service-account.json"
    node seedData.js 2>&1
    echo -e "  ✅ 初始数据写入完成"
else
    echo -e "  ${RED}❌ 文件不存在，请稍后手动运行: cd scripts && node seedData.js${NC}"
fi

# ============================================================
# Step 6: 部署 Cloud Functions
# ============================================================
echo ""
echo -e "${YELLOW}[6/6] 部署 Cloud Functions...${NC}"

cd "$PROJECT_DIR/functions"
npm install 2>&1 | tail -3

cd "$PROJECT_DIR"
firebase deploy --only functions 2>&1 | tail -5

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   🎉 部署完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "下一步：在 Xcode 中打开 iOS App"
echo ""
echo -e "  ${BLUE}1. 下载 GoogleService-Info.plist${NC}"
echo -e "     Firebase 控制台 → ⚙️ → 应用设置 → iOS 应用"
echo -e "     放到: ios/UnlockAlert/Resources/"
echo ""
echo -e "  ${BLUE}2. 在 Xcode 中打开项目${NC}"
echo -e "     打开 ios/ 目录"
echo -e "     等 Swift Package 自动下载 Firebase SDK"
echo -e ""
echo -e "  ${BLUE}3. 选择模拟器运行${NC}"
echo -e "     Product → Run (Cmd+R)"
echo ""
echo -e "  ${BLUE}4. 可选：部署到 App Store${NC}"
echo -e "    需要 Apple Developer 账号（$99/年）"
echo -e "    用 Xcode 打包上传即可"
echo ""
