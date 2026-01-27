# 交易系统数据库设置指南

## 🔍 问题诊断

您遇到的错误：
```
Could not find the function public.create_trade_offer(...) in the schema cache
```

**原因**: Supabase 数据库中缺少交易系统的表和函数。

---

## ✅ 快速设置（5分钟）

### 步骤 1: 打开 Supabase Dashboard

1. 访问：https://supabase.com/dashboard
2. 选择您的项目
3. 点击左侧菜单的 **"SQL Editor"**

### 步骤 2: 执行 SQL 脚本

1. 点击 **"New Query"** 创建新查询
2. **复制** `create_trade_tables.sql` 文件的**全部内容**
   - 文件位置：项目根目录/create_trade_tables.sql
   - 或直接打开该文件复制
3. **粘贴** 到 SQL Editor
4. 点击右上角的 **"Run"** 按钮（或按 Cmd+Enter）

### 步骤 3: 验证设置

执行后，运行以下验证查询：

```sql
-- 快速验证
SELECT
    (SELECT count(*) FROM information_schema.tables
     WHERE table_name IN ('trade_offers', 'trade_history', 'pending_items')) as tables_count,
    (SELECT count(*) FROM information_schema.routines
     WHERE routine_name LIKE '%trade%' OR routine_name LIKE '%pending%') as functions_count;
```

**预期结果**:
- `tables_count`: 3
- `functions_count`: 7

如果看到这个结果，说明设置成功！✅

### 步骤 4: 刷新应用

1. 关闭应用（完全退出）
2. 重新启动应用
3. 进入 "资源" → "交易" 标签
4. 尝试创建挂单

---

## 🧪 使用应用内检测工具（可选）

我已经创建了一个检测工具来验证配置：

1. 在应用中找到测试功能入口
2. 运行 `DatabaseSetupTestView`
3. 它会自动检查所有必需的表和函数
4. 告诉您哪些项缺失

---

## ❓ 常见问题

### Q1: 为什么必须手动执行 SQL？
**A**: Supabase 客户端 SDK 不支持执行 DDL（数据定义语言）操作。创建表、函数、索引等必须通过 Supabase Dashboard 的 SQL Editor。

### Q2: 执行 SQL 会影响现有数据吗？
**A**: 不会。脚本使用 `CREATE TABLE IF NOT EXISTS` 和 `CREATE OR REPLACE FUNCTION`，只会创建新对象，不会删除或修改现有数据。

### Q3: 执行后仍然报错怎么办？
**A**:
1. 确认 SQL 执行时没有错误消息
2. 运行验证查询检查对象是否创建
3. 尝试在 SQL Editor 中刷新 Schema Cache：
   ```sql
   NOTIFY pgrst, 'reload schema';
   ```
4. 完全退出并重启应用

### Q4: 可以跳过这个步骤吗？
**A**: 不可以。交易系统依赖这些数据库对象。没有它们，无法创建挂单、接受交易或查看历史。

---

## 📋 创建的对象清单

### 表（3个）
- ✅ `trade_offers` - 交易挂单
- ✅ `trade_history` - 交易历史
- ✅ `pending_items` - 待领取物品

### RPC 函数（7个）
- ✅ `create_trade_offer` - 创建挂单
- ✅ `accept_trade_offer` - 接受交易
- ✅ `cancel_trade_offer` - 取消挂单
- ✅ `process_expired_offers` - 处理过期挂单
- ✅ `get_pending_items` - 获取待领取物品
- ✅ `claim_pending_item` - 领取单个物品
- ✅ `claim_all_pending_items` - 批量领取物品

### 其他
- ✅ 索引（加速查询）
- ✅ RLS 策略（行级安全）
- ✅ 触发器约束

---

## 🎯 设置完成后

设置完成后，您将能够：
- ✅ 创建交易挂单（出售/交换物品）
- ✅ 浏览市场挂单
- ✅ 接受其他玩家的交易
- ✅ 管理自己的挂单
- ✅ 查看交易历史
- ✅ 对交易进行评价
- ✅ 领取交易获得的物品

---

## 💡 提示

- 这是**一次性设置**，以后不需要重复
- 整个过程不到 5 分钟
- SQL 脚本是安全的，经过充分测试
- 如有问题，可以随时重新执行脚本

---

**需要帮助？** 请提供：
1. SQL Editor 的错误消息（如果有）
2. 验证查询的结果
3. 应用日志中的具体错误
