-- ============================================
-- 交易系统数据库验证脚本
-- 用于检查表和函数是否正确创建
-- ============================================

-- 1. 检查表是否存在
SELECT
    '表检查' as check_type,
    table_name,
    CASE
        WHEN table_name IN ('trade_offers', 'trade_history', 'pending_items') THEN '✅ 存在'
        ELSE '❌ 缺失'
    END as status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('trade_offers', 'trade_history', 'pending_items')
ORDER BY table_name;

-- 2. 检查 RPC 函数是否存在
SELECT
    '函数检查' as check_type,
    routine_name as function_name,
    '✅ 存在' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'create_trade_offer',
    'accept_trade_offer',
    'cancel_trade_offer',
    'process_expired_offers',
    'get_pending_items',
    'claim_pending_item',
    'claim_all_pending_items'
)
ORDER BY routine_name;

-- 3. 检查 create_trade_offer 函数的参数
SELECT
    '函数参数检查' as check_type,
    routine_name,
    parameter_name,
    data_type,
    ordinal_position
FROM information_schema.parameters
WHERE specific_schema = 'public'
AND routine_name = 'create_trade_offer'
ORDER BY ordinal_position;

-- 4. 如果上述查询返回空结果，说明函数未创建，需要执行以下检查：

-- 检查是否有任何交易相关的对象
SELECT
    '对象检查' as check_type,
    'trade_offers' as object_name,
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'trade_offers')
        THEN '✅ 表存在'
        ELSE '❌ 表不存在 - 请执行 create_trade_tables.sql'
    END as status
UNION ALL
SELECT
    '对象检查',
    'create_trade_offer',
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'create_trade_offer')
        THEN '✅ 函数存在'
        ELSE '❌ 函数不存在 - 请执行 create_trade_tables.sql'
    END
UNION ALL
SELECT
    '对象检查',
    'accept_trade_offer',
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'accept_trade_offer')
        THEN '✅ 函数存在'
        ELSE '❌ 函数不存在 - 请执行 create_trade_tables.sql'
    END
UNION ALL
SELECT
    '对象检查',
    'process_expired_offers',
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'process_expired_offers')
        THEN '✅ 函数存在'
        ELSE '❌ 函数不存在 - 请执行 create_trade_tables.sql'
    END;
