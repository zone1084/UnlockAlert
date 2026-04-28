const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// CoinGecko API 配置
// ============================================================
const COINGECKO_BASE = 'https://api.coingecko.com/api/v3';
const INTERESTING_TOKENS = [
    'arbitrum', 'aptos', 'sui', 'worldcoin', 'ethena',
    'dydx', 'immutable-x', 'sei-network', 'celestia', 'injective',
    'near', 'internet-computer', 'filecoin', 'aptos', 'optimism',
    'zksync', 'strk', 'pixel', 'portal', 'wormhole',
    'aevo', 'ether-fi', 'altlayer', 'saga', 'omni-network',
    'memecoin', 'notcoin', 'dogs', 'catizen', 'hamster-kombat',
    'tia', 'dymension', 'saga', 'sui', 'scroll',
];

// ============================================================
// 1. 从 CoinGecko 获取代币行情数据
// ============================================================
async function fetchTokenMarketData(tokenIds) {
    try {
        const url = `${COINGECKO_BASE}/coins/markets`;
        const response = await axios.get(url, {
            params: {
                vs_currency: 'usd',
                ids: tokenIds.join(','),
                order: 'market_cap_desc',
                per_page: 100,
                page: 1,
                sparkline: false,
                price_change_percentage: '7d'
            },
            timeout: 15000,
            headers: { 'Accept': 'application/json' }
        });
        return response.data;
    } catch (error) {
        console.error('❌ CoinGecko API 失败:', error.message);
        return [];
    }
}

// ============================================================
// 2. 从 Etherscan/BSCScan 获取合约解锁数据
//    （使用公开的代币解锁合约地址）
// ============================================================
const KNOWN_UNLOCK_CONTRACTS = {
    'arbitrum': { chain: 'ethereum', address: '0xD5954c3084a1cCd70B4dA011E67760B8e78aeE84' },
    'aptos': { chain: 'ethereum', address: '0x1a60dE079aB8507C8e5A08b5Bc3e198160d4b0d3' },
    'sui': { chain: 'ethereum', address: '0xcf6114308a3EA4B155250323B648DeE2C99241f7' },
    // 更多合约地址可以后续扩展
};

async function fetchChainUnlockData(contract) {
    try {
        // 使用 Etherscan API 获取合约事件
        // 注意：需要 ETHERSCAN_API_KEY
        const apiKey = process.env.ETHERSCAN_API_KEY || 'YourApiKey';
        const baseUrl = contract.chain === 'ethereum'
            ? 'https://api.etherscan.io/api'
            : 'https://api.bscscan.com/api';

        const response = await axios.get(baseUrl, {
            params: {
                module: 'account',
                action: 'tokentx',
                contractaddress: contract.address,
                sort: 'desc',
                apikey: apiKey,
                limit: 50
            },
            timeout: 10000
        });

        return response.data;
    } catch (error) {
        console.error('❌ 链上数据获取失败:', error.message);
        return null;
    }
}

// ============================================================
// 3. 内置解锁数据（当API不可用时的备用数据）
//    Coingecko和链上API受限时使用静态数据保证App可用
// ============================================================
function getFallbackUnlockData() {
    return require('./fallbackData.json');
}

// ============================================================
// 4. 主函数: 抓取并更新所有代币解锁数据
// ============================================================
async function updateAllTokenData() {
    console.log('🔄 开始更新代币解锁数据...');
    
    // 获取市场数据
    const markets = await fetchTokenMarketData(INTERESTING_TOKENS);
    console.log(`📊 获取到 ${markets.length} 个代币的市场数据`);
    
    // 构建价格映射
    const priceMap = {};
    for (const m of markets) {
        priceMap[m.id] = m.current_price;
    }
    
    // 使用内置解锁数据 + 市场数据
    let unlockData;
    try {
        unlockData = require('./fallbackData.json');
    } catch (e) {
        unlockData = getFallbackUnlockData();
    }
    
    // 更新价格和计算值
    const batch = db.batch();
    let count = 0;
    
    for (const token of unlockData) {
        const tokenId = token.id;
        const price = priceMap[tokenId] || token.currentPrice || 0;
        
        // 计算下次解锁日期
        const futureUnlocks = (token.unlocks || [])
            .filter(u => new Date(u.date) > new Date())
            .sort((a, b) => new Date(a.date) - new Date(b.date));
        
        const nextUnlock = futureUnlocks[0] || null;
        const nextUnlockValueUsd = nextUnlock
            ? nextUnlock.amount * price
            : 0;
        
        // 写入 Firestore
        const docRef = db.collection('tokens').doc(tokenId);
        batch.set(docRef, {
            ...token,
            currentPrice: price,
            marketCap: price * (token.circulatingSupply || 0),
            nextUnlockDate: nextUnlock ? new Date(nextUnlock.date) : null,
            nextUnlockValueUsd: nextUnlockValueUsd,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        count++;
    }
    
    await batch.commit();
    console.log(`✅ 成功更新 ${count} 个代币数据`);
    
    return { updated: count };
}

// ============================================================
// 5. Firebase Cloud Function: 定时更新（每天UTC 2:00）
// ============================================================
exports.dailyUpdate = functions.pubsub
    .schedule('0 2 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        try {
            const result = await updateAllTokenData();
            console.log('✅ 每日更新完成:', result);
            return null;
        } catch (error) {
            console.error('❌ 每日更新失败:', error);
            return null;
        }
    });

// ============================================================
// 6. Firebase Cloud Function: HTTP 触发手动更新
// ============================================================
exports.manualUpdate = functions.https.onRequest(async (req, res) => {
    // 简单认证：检查 secret token
    const authHeader = req.headers.authorization;
    if (authHeader !== `Bearer ${process.env.UPDATE_SECRET}`) {
        res.status(403).json({ error: 'Unauthorized' });
        return;
    }
    
    try {
        const result = await updateAllTokenData();
        res.json({ success: true, ...result });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// 7. Firebase Cloud Function: 发送推送通知
//    （对关注了即将解锁代币的用户）
// ============================================================
async function sendUnlockNotifications() {
    const tokensSnap = await db.collection('tokens').get();
    const now = new Date();
    const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in3Days = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    const in7Days = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    
    let notificationsSent = 0;
    
    for (const doc of tokensSnap.docs) {
        const token = doc.data();
        const tokenId = doc.id;
        
        // 查找是否有解锁在接下来1小时/24小时内
        const imminentUnlocks = (token.unlocks || []).filter(u => {
            const d = new Date(u.date);
            return d > now && d < in24Hours;
        });
        
        if (imminentUnlocks.length === 0) continue;
        
        // 查找关注了该代币的所有用户
        // 注意：生产环境应使用 Firebase 的 Subcollections 或 FCM Topics
        const subscriptionsSnap = await db.collection('subscriptions')
            .where('tokenId', '==', tokenId)
            .get();
        
        for (const sub of subscriptionsSnap.docs) {
            const fcmToken = sub.data().fcmToken;
            if (!fcmToken) continue;
            
            const unlock = imminentUnlocks[0];
            const value = formatUsd(unlock.amount * (token.currentPrice || 0));
            
            const message = {
                notification: {
                    title: `🔓 ${token.symbol} 即将解锁`,
                    body: `${value} 将在 24 小时内解锁！当前价格 $${token.currentPrice}`,
                },
                token: fcmToken,
                data: {
                    tokenId: tokenId,
                    unlockDate: unlock.date,
                    type: 'unlock_alert'
                }
            };
            
            try {
                await admin.messaging().send(message);
                notificationsSent++;
            } catch (error) {
                console.error(`❌ 推送失败 (${tokenId}):`, error.message);
            }
        }
    }
    
    console.log(`📬 发送了 ${notificationsSent} 条推送通知`);
    return { sent: notificationsSent };
}

exports.sendNotifications = functions.pubsub
    .schedule('0 8,20 * * *')
    .timeZone('UTC')
    .onRun(async () => {
        return await sendUnlockNotifications();
    });

// ============================================================
// Helper
// ============================================================
function formatUsd(value) {
    if (value >= 1_000_000_000) return `$${(value / 1_000_000_000).toFixed(2)}B`;
    if (value >= 1_000_000) return `$${(value / 1_000_000).toFixed(2)}M`;
    if (value >= 1_000) return `$${(value / 1_000).toFixed(2)}K`;
    return `$${value.toFixed(2)}`;
}
