<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />
    <title>取餐显示 · 已完成订单</title>

    <!-- Firebase -->
    <script src="https://www.gstatic.com/firebasejs/10.5.2/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.5.2/firebase-database-compat.js"></script>

    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background: #0b1a1f;
            color: #eef4ea;
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            padding: 16px;
            min-height: 100vh;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        /* 顶部 */
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 15px;
            margin-bottom: 20px;
            padding: 12px 20px;
            background: #13242c;
            border-radius: 60px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        }

        .header h1 {
            font-size: 1.8rem;
            display: flex;
            align-items: center;
            gap: 12px;
            color: #ffd966;
        }

        .header h1:before {
            content: "✅";
            font-size: 2rem;
        }

        .header-actions {
            display: flex;
            gap: 12px;
            align-items: center;
            flex-wrap: wrap;
        }

        .stats {
            display: flex;
            gap: 20px;
            font-size: 0.95rem;
            color: #bcd0d0;
        }

        .stats span {
            color: #ffb347;
            font-weight: bold;
        }

        .btn-clear {
            background: #5a3e3e;
            color: #ffb3b3;
            border: none;
            padding: 8px 22px;
            border-radius: 40px;
            font-weight: bold;
            cursor: pointer;
            transition: 0.2s;
            font-size: 0.85rem;
        }

        .btn-clear:hover {
            background: #7a4a4a;
            transform: scale(1.02);
        }

        /* 网格 */
        .orders-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
            gap: 18px;
        }

        /* 卡片 */
        .order-card {
            background: #1a2f33;
            border-radius: 28px;
            padding: 20px 22px;
            border-left: 8px solid #2ecc71;
            box-shadow: 0 6px 20px rgba(0,0,0,0.4);
            animation: popIn 0.4s cubic-bezier(0.175,0.885,0.32,1.275);
            transition: 0.3s;
            position: relative;
            overflow: hidden;
        }

        .order-card::after {
            content: "✅";
            position: absolute;
            bottom: -10px;
            right: -5px;
            font-size: 5rem;
            opacity: 0.06;
            pointer-events: none;
        }

        @keyframes popIn {
            0% {
                opacity: 0;
                transform: scale(0.8) translateY(30px);
            }

            100% {
                opacity: 1;
                transform: scale(1) translateY(0);
            }
        }

        .order-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 12px 30px rgba(46,204,113,0.15);
        }

        /* 订单号 */
        .order-number {
            background: #2ecc71;
            color: #0b1a1f;
            font-weight: 800;
            font-size: 1.8rem;
            padding: 4px 20px;
            border-radius: 60px;
            display: inline-block;
            letter-spacing: 1px;
        }

        .table-number {
            font-size: 2.2rem;
            font-weight: 800;
            color: #ffd966;
            background: #2ecc7120;
            padding: 4px 20px;
            border-radius: 60px;
            display: inline-block;
        }

        .order-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 12px;
            border-bottom: 1px dashed #3a5a5a;
            padding-bottom: 10px;
        }

        .order-header-left {
            display: flex;
            align-items: center;
            gap: 15px;
            flex-wrap: wrap;
        }

        .complete-time {
            font-size: 0.85rem;
            color: #9bb5b5;
            background: #0f2227;
            padding: 4px 14px;
            border-radius: 30px;
        }

        /* 明细 */
        .items-list {
            margin: 12px 0 8px 0;
        }

        .item-row {
            display: flex;
            justify-content: space-between;
            padding: 5px 0;
            border-bottom: 1px solid #2a4848;
            font-size: 0.95rem;
        }

        .item-qty {
            color: #ffb347;
            font-weight: bold;
        }

        .order-total {
            text-align: right;
            margin-top: 10px;
            font-size: 1.2rem;
            font-weight: bold;
            color: #7effb3;
            border-top: 1px solid #2a4848;
            padding-top: 10px;
        }

        /* 已取餐按钮 */
        .pickup-btn {
            width: 100%;
            margin-top: 14px;
            padding: 12px;
            border: none;
            border-radius: 16px;
            background: #27ae60;
            color: white;
            font-size: 1rem;
            font-weight: bold;
            cursor: pointer;
            transition: 0.2s;
        }

        .pickup-btn:hover {
            background: #2ecc71;
            transform: scale(1.02);
        }

        /* 空状态 */
        .empty-state {
            grid-column: 1 / -1;
            text-align: center;
            padding: 80px 20px;
            background: #13242c;
            border-radius: 40px;
            color: #6b9b9b;
            font-size: 1.4rem;
        }

        .empty-state .big {
            font-size: 3rem;
            display: block;
            margin-bottom: 15px;
        }

        /* 加载 */
        .loading {
            grid-column: 1 / -1;
            text-align: center;
            padding: 50px;
            color: #ffb347;
            font-size: 1.2rem;
        }

        /* 手机 */
        @media (max-width: 700px) {
            body {
                padding: 10px;
            }

            .header {
                flex-direction: column;
                align-items: stretch;
                text-align: center;
            }

            .header h1 {
                font-size: 1.4rem;
                justify-content: center;
            }

            .stats {
                justify-content: center;
            }

            .orders-grid {
                grid-template-columns: 1fr;
            }

            .order-number {
                font-size: 1.4rem;
            }

            .table-number {
                font-size: 1.6rem;
            }
        }
    </style>
</head>

<body>

<div class="container">

    <!-- 顶部 -->
    <div class="header">
        <h1>取餐完成板</h1>

        <div class="header-actions">

            <div class="stats">
                <div>📦 已完成：<span id="completedCount">0</span></div>
                <div>🕒 更新：<span id="lastUpdate">--:--</span></div>
            </div>

            <button class="btn-clear" id="clearBtn">
                🗑️ 清屏（仅隐藏）
            </button>

        </div>
    </div>

    <!-- 订单 -->
    <div id="ordersGrid" class="orders-grid">
        <div class="loading">
            ⏳ 正在加载已完成订单...
        </div>
    </div>

</div>

<script>

    // Firebase
    const firebaseConfig = {
        apiKey: "YOUR_API_KEY",
        authDomain: "YOUR_DOMAIN",
        databaseURL: "YOUR_DATABASE_URL",
        projectId: "YOUR_PROJECT_ID",
        storageBucket: "YOUR_BUCKET",
        messagingSenderId: "YOUR_SENDER_ID",
        appId: "YOUR_APP_ID"
    };

    if (!firebase.apps.length) {
        firebase.initializeApp(firebaseConfig);
    }

    const database = firebase.database();
    const allOrdersRef = database.ref('orders');

    const grid = document.getElementById('ordersGrid');
    const completedCountSpan = document.getElementById('completedCount');
    const lastUpdateSpan = document.getElementById('lastUpdate');
    const clearBtn = document.getElementById('clearBtn');

    const completedOrders = new Map();

    // 更新时间
    function updateTime() {
        lastUpdateSpan.textContent =
            new Date().toLocaleTimeString([], {
                hour: '2-digit',
                minute: '2-digit'
            });
    }

    // 更新数量
    function updateCount() {
        completedCountSpan.textContent = completedOrders.size;
    }

    // 防 XSS
    function escapeHtml(str) {
        if (!str) return '';

        return String(str).replace(/[&<>]/g, m =>
            m === '&'
                ? '&amp;'
                : m === '<'
                ? '&lt;'
                : '&gt;'
        );
    }

    // 时间格式
    function formatTime(timeVal) {

        if (!timeVal) return '--:--';

        try {

            const d = new Date(timeVal);

            if (!isNaN(d.getTime())) {
                return d.toLocaleTimeString([], {
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit'
                });
            }

            return String(timeVal).slice(0, 8);

        } catch (e) {

            return String(timeVal).slice(0, 8);

        }
    }

    // 创建卡片
    function createCompletedCard(orderId, data) {

        const card = document.createElement('div');

        card.className = 'order-card';
        card.dataset.id = orderId;

        const orderNum =
            data.orderNumber
                ? `#${data.orderNumber}`
                : `#${orderId.slice(-5)}`;

        const tableText =
            data.table
                ? `桌 ${data.table}`
                : '🥡 外带';

        const doneTime =
            data.completedAt ||
            data.timestamp ||
            data.time ||
            '';

        const timeStr = formatTime(doneTime);

        // 菜品
        let itemsHtml = '';

        if (data.items && Array.isArray(data.items)) {

            data.items.forEach(item => {

                const name = escapeHtml(item.name);
                const qty = item.qty || 1;

                itemsHtml += `
                    <div class="item-row">
                        <span>🍽️ ${name}</span>
                        <span class="item-qty">×${qty}</span>
                    </div>
                `;
            });

        } else {

            itemsHtml = `
                <div class="item-row">
                    <span>（无明细）</span>
                </div>
            `;
        }

        const total =
            data.total !== undefined &&
            data.total !== null
                ? Number(data.total).toFixed(2)
                : '—';

        card.dataset.total = total;

        card.innerHTML = `
            <div class="order-header">

                <div class="order-header-left">

                    <span class="order-number">
                        ${escapeHtml(orderNum)}
                    </span>

                    <span class="table-number">
                        ${escapeHtml(tableText)}
                    </span>

                </div>

                <span class="complete-time">
                    ✅ ${timeStr}
                </span>

            </div>

            <div class="items-list">
                ${itemsHtml}
            </div>

            <div class="order-total">
                💰 合计：¥${total}
            </div>

            <button
                class="pickup-btn"
                onclick="markAsPickedUp('${orderId}')"
            >
                ✅ 已取餐
            </button>
        `;

        return card;
    }

    // 添加卡片
    function addCard(orderId, data) {

        if (completedOrders.has(orderId)) return;

        const card = createCompletedCard(orderId, data);

        const firstCard = grid.querySelector('.order-card');

        if (firstCard) {
            grid.insertBefore(card, firstCard);
        } else {
            grid.appendChild(card);
        }

        completedOrders.set(orderId, card);

        updateCount();
        updateTime();

        hideEmptyState();
    }

    // 删除卡片
    function removeCard(orderId) {

        const card = completedOrders.get(orderId);

        if (card) {

            card.remove();

            completedOrders.delete(orderId);

            updateCount();
            updateTime();

            if (completedOrders.size === 0) {
                showEmptyState();
            }
        }
    }

    // 空状态
    function showEmptyState(msg = '🎉 暂无已完成订单') {

        let emptyEl = document.getElementById('emptyState');

        if (!emptyEl) {

            emptyEl = document.createElement('div');

            emptyEl.id = 'emptyState';
            emptyEl.className = 'empty-state';

            grid.appendChild(emptyEl);
        }

        emptyEl.innerHTML = `
            <span class="big">✅</span>
            ${msg}
        `;

        emptyEl.style.display = 'block';
    }

    function hideEmptyState() {

        const emptyEl = document.getElementById('emptyState');

        if (emptyEl) {
            emptyEl.style.display = 'none';
        }
    }

    // 顾客已取餐
    function markAsPickedUp(orderId) {

        database.ref('orders/' + orderId).update({

            pickedUp: true,
            pickedUpAt: Date.now()

        }).then(() => {

            console.log('订单已取餐:', orderId);

        }).catch(err => {

            console.error('更新失败:', err);

        });
    }

    // Firebase 监听
    function initFirebaseListeners() {

        allOrdersRef.on('value', snapshot => {

            const allData = snapshot.val();

            if (!allData) {

                grid.innerHTML = '';

                completedOrders.clear();

                updateCount();

                showEmptyState('📭 数据库暂无订单');

                return;
            }

            const currentKeys = new Set(Object.keys(allData));

            // 删除不存在
            for (const key of completedOrders.keys()) {

                if (!currentKeys.has(key)) {
                    removeCard(key);
                }
            }

            let hasCompleted = false;

            for (const [key, data] of Object.entries(allData)) {

                // 只显示：
                // completed=true
                // pickedUp != true

                if (
                    data.completed === true &&
                    data.pickedUp !== true
                ) {

                    hasCompleted = true;

                    if (!completedOrders.has(key)) {

                        addCard(key, data);

                    } else {

                        const oldCard = completedOrders.get(key);

                        const newTotal = data.total;
                        const oldTotal = oldCard.dataset.total;

                        if (String(newTotal) !== String(oldTotal)) {

                            removeCard(key);
                            addCard(key, data);
                        }
                    }

                } else {

                    // 已取餐 → 删除
                    if (completedOrders.has(key)) {
                        removeCard(key);
                    }
                }
            }

            if (!hasCompleted && completedOrders.size === 0) {

                showEmptyState('🎉 暂无已完成订单');

            } else {

                hideEmptyState();
            }

            // 去掉 loading
            const loader = grid.querySelector('.loading');

            if (loader) loader.remove();

            updateCount();
            updateTime();
        });

        // child_changed
        allOrdersRef.on('child_changed', snapshot => {

            const data = snapshot.val();
            const key = snapshot.key;

            if (
                data.completed === true &&
                data.pickedUp !== true
            ) {

                removeCard(key);
                addCard(key, data);

            } else {

                removeCard(key);
            }
        });

        // child_removed
        allOrdersRef.on('child_removed', snapshot => {

            const key = snapshot.key;

            removeCard(key);
        });
    }

    // 清屏（仅前端）
    clearBtn.addEventListener('click', () => {

        for (const [key, card] of completedOrders.entries()) {
            card.remove();
        }

        completedOrders.clear();

        updateCount();

        showEmptyState('🧹 已清屏，新订单仍会显示');

        updateTime();
    });

    // 启动
    function init() {

        grid.innerHTML = `
            <div class="loading">
                ⏳ 正在加载已完成订单...
            </div>
        `;

        initFirebaseListeners();

        setInterval(updateTime, 15000);
    }

    init();

</script>

</body>
</html>
