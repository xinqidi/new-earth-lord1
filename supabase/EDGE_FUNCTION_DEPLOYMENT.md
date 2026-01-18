# Edge Function 部署指南

## 前置条件

### 1. 安装 Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# 或使用 npm
npm install -g supabase
```

验证安装：
```bash
supabase --version
```

### 2. 登录 Supabase

```bash
supabase login
```

这会打开浏览器进行身份验证。

### 3. 获取阿里云百炼 API Key

1. 访问 [阿里云百炼控制台](https://bailian.console.aliyun.com/)
2. 创建应用并获取 API Key
3. 记录下你的 `DASHSCOPE_API_KEY`

## 部署步骤

### 1. 部署 Edge Function

在项目根目录执行：

```bash
cd "/Users/xinqidian/Desktop/AI学习/new earth lord1"
supabase functions deploy generate-ai-items --project-ref ipvkhcrgbbcccwiwlofd
```

### 2. 配置环境变量

在 Supabase Dashboard 中设置环境变量：

1. 访问 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择项目 `ipvkhcrgbbcccwiwlofd`
3. 进入 **Settings** → **Edge Functions** → **Environment Variables**
4. 添加环境变量：
   - Name: `DASHSCOPE_API_KEY`
   - Value: 你的阿里云百炼 API Key

或者使用 CLI 设置：

```bash
supabase secrets set DASHSCOPE_API_KEY=your-api-key-here --project-ref ipvkhcrgbbcccwiwlofd
```

### 3. 测试 Edge Function

使用 curl 测试：

```bash
curl -X POST \
  https://ipvkhcrgbbcccwiwlofd.supabase.co/functions/v1/generate-ai-items \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "poiType": "废弃超市",
    "poiName": "废弃的华联超市",
    "dangerLevel": 3,
    "itemCount": 3
  }'
```

预期响应：
```json
{
  "success": true,
  "items": [
    {
      "itemId": "ai_1705000000_0",
      "name": "过期能量棒",
      "category": "food",
      "rarity": "uncommon",
      "story": "包装上的日期显示这是三年前的产品...",
      "icon": "fork.knife",
      "quantity": 1
    }
  ]
}
```

## 本地测试（可选）

如果想在本地测试 Edge Function：

```bash
# 启动 Supabase 本地开发环境
supabase start

# 部署到本地
supabase functions serve generate-ai-items --env-file ./supabase/.env.local

# 测试本地 Edge Function
curl -X POST \
  http://localhost:54321/functions/v1/generate-ai-items \
  -H "Authorization: Bearer YOUR_LOCAL_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "poiType": "废弃超市",
    "poiName": "废弃的华联超市",
    "dangerLevel": 3,
    "itemCount": 3
  }'
```

## 故障排查

### 错误：API key not configured

确保已在 Supabase Dashboard 或通过 CLI 设置了 `DASHSCOPE_API_KEY` 环境变量。

### 错误：AI API error: 401

阿里云百炼 API Key 无效或已过期，请检查：
1. API Key 是否正确
2. API Key 是否有权限调用 qwen-turbo 模型

### 错误：AI API error: 429

API 请求频率超限，请稍后再试或升级阿里云百炼套餐。

### 错误：Function timeout

AI 生成物品可能需要较长时间，可以：
1. 减少 itemCount
2. 在 Supabase Dashboard 中增加 Edge Function 超时时间

## 监控和日志

查看 Edge Function 日志：

1. 访问 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择项目
3. 进入 **Edge Functions** → **generate-ai-items** → **Logs**

或使用 CLI：

```bash
supabase functions logs generate-ai-items --project-ref ipvkhcrgbbcccwiwlofd
```

## 更新 Edge Function

修改代码后重新部署：

```bash
supabase functions deploy generate-ai-items --project-ref ipvkhcrgbbcccwiwlofd
```

## 完成检查清单

- [ ] 安装 Supabase CLI
- [ ] 登录 Supabase
- [ ] 获取阿里云百炼 API Key
- [ ] 部署 Edge Function
- [ ] 配置 DASHSCOPE_API_KEY 环境变量
- [ ] 测试 Edge Function（curl 或 App 内测试）
- [ ] 验证 AI 生成物品功能正常工作

## 下一步

Edge Function 部署完成后，App 中的 POI 搜刮功能将自动使用 AI 生成物品。如果 AI 生成失败，会自动降级使用备用物品生成逻辑（已在 `AIItemGenerator.swift` 中实现）。
