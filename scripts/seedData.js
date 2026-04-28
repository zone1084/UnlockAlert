/**
 * 初始化脚本：将初始数据写入 Firestore
 * 使用方式：node scripts/seedData.js
 * 
 * 前提：需要安装 firebase-admin 和设置 GOOGLE_APPLICATION_CREDENTIALS
 */

const admin = require('firebase-admin');
const path = require('path');

// 初始化 Firebase Admin
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS 
    || path.join(__dirname, '..', 'functions', 'service-account.json');

admin.initializeApp({
    credential: admin.credential.applicationDefault()
});

const db = admin.firestore();
const fallbackData = require('../functions/src/fallbackData.json');

async function seedData() {
    console.log('🌱 开始写入初始数据...');
    
    const batch = db.batch();
    let count = 0;
    
    for (const token of fallbackData) {
        const docRef = db.collection('tokens').doc(token.id);
        
        // 计算下次解锁日期
        const futureUnlocks = token.unlocks
            .filter(u => new Date(u.date) > new Date())
            .sort((a, b) => new Date(a.date) - new Date(b.date));
        
        const nextUnlock = futureUnlocks[0] || null;
        const nextUnlockValueUsd = nextUnlock
            ? nextUnlock.amount * token.currentPrice
            : 0;
        
        batch.set(docRef, {
            ...token,
            nextUnlockDate: nextUnlock ? new Date(nextUnlock.date) : null,
            nextUnlockValueUsd: nextUnlockValueUsd,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        
        count++;
        console.log(`  ✅ ${token.symbol} (${token.name})`);
    }
    
    await batch.commit();
    console.log(`\n🎉 成功写入 ${count} 个代币到 Firestore!`);
}

seedData().catch(error => {
    console.error('❌ 写入失败:', error);
    process.exit(1);
});
