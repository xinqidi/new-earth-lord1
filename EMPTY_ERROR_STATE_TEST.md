# 空状态和错误状态测试指南

## 📝 概述

本指南说明如何测试探索模块各页面的空状态和错误状态显示。

---

## 1. POI列表页 (POIListView)

### 测试场景1: 完全没有POI
**前置条件**: `allPOIs` 数组为空

**显示效果**:
- 图标: `map` (地图图标，60pt)
- 主标题: "附近暂无兴趣点"
- 副标题: "点击搜索按钮发现周围的废墟"
- 文字颜色: 灰色
- 居中显示

**测试步骤**:
1. 修改 `POIListView.swift` 第22行
   ```swift
   @State private var allPOIs: [POI] = []  // 改为空数组
   ```
2. 运行App，进入资源Tab → POI分段
3. 验证空状态显示正确

**恢复**:
```swift
@State private var allPOIs: [POI] = MockExplorationData.mockPOIs
```

---

### 测试场景2: 筛选后没有结果
**前置条件**: `allPOIs` 有数据，但筛选后 `filteredPOIs` 为空

**显示效果**:
- 图标: `mappin.slash` (60pt)
- 主标题: "没有找到该类型的地点"
- 副标题: "尝试搜索或切换其他分类"
- 文字颜色: 灰色
- 居中显示

**测试步骤**:
1. 运行App，进入资源Tab → POI分段
2. 点击筛选工具栏中的"学校"分类
3. 验证空状态显示正确（因为mock数据中没有学校类型的POI）

---

## 2. 背包页 (BackpackView)

### 测试场景1: 背包完全为空
**前置条件**: `backpackItems` 数组为空

**显示效果**:
- 图标: `backpack` (背包图标，60pt)
- 主标题: "背包空空如也"
- 副标题: "去探索收集物资吧"
- 文字颜色: 灰色
- 居中显示

**测试步骤**:
1. 修改 `BackpackView.swift` 第22行
   ```swift
   @State private var backpackItems: [BackpackItem] = []  // 改为空数组
   ```
2. 运行App，进入资源Tab → 背包分段
3. 验证空状态显示正确

**恢复**:
```swift
@State private var backpackItems: [BackpackItem] = MockExplorationData.mockBackpackItems
```

---

### 测试场景2: 搜索/筛选后没有结果
**前置条件**: `backpackItems` 有数据，但筛选后为空

**显示效果**:
- 图标: `magnifyingglass` (放大镜图标，60pt)
- 主标题: "没有找到相关物品"
- 副标题: "尝试其他搜索关键词或分类"
- 文字颜色: 灰色
- 居中显示

**测试步骤**:
1. 运行App，进入资源Tab → 背包分段
2. 在搜索框输入"测试123"（一个不存在的物品名称）
3. 验证空状态显示正确

或

1. 运行App，进入资源Tab → 背包分段
2. 点击筛选工具栏中的"工具"分类
3. 验证空状态显示正确（因为mock数据中没有工具类型的物品）

---

## 3. 探索结果页 (ExplorationResultView)

### 测试场景1: 探索成功（默认）
**前置条件**: `hasFailed = false`

**显示效果**:
- 正常显示成就标题、统计数据、奖励物品
- 标题: "探索完成"
- 带数字跳动动画
- 物品依次出现动画

**测试步骤**:
1. 运行App，进入资源Tab → POI分段
2. 点击任意POI进入详情页
3. 点击"搜寻此POI"按钮
4. 验证成功状态显示正确

---

### 测试场景2: 探索失败
**前置条件**: `hasFailed = true`

**显示效果**:
- 图标: `exclamationmark.triangle.fill` (感叹号三角形，60pt)
- 红色圆形背景（半透明）
- 标题: "探索失败"
- 错误信息: 自定义错误消息
- 重试按钮（如果提供了 `onRetry` 回调）
- 居中显示

**测试步骤**:
1. 修改 `POIDetailView.swift` 的 `handleExplore()` 方法（约第116行）
   ```swift
   private func handleExplore() {
       print("🔍 [POI详情] 开始搜寻: \(poi.name)")
       explorationResult = ExplorationResult(
           hasFailed: true,
           errorMessage: "GPS信号丢失，无法完成探索"
       )
       showExplorationResult = true
   }
   ```

2. 添加 `ExplorationResult` 结构体（在文件顶部）
   ```swift
   struct ExplorationResult {
       let hasFailed: Bool
       let errorMessage: String

       init(hasFailed: Bool = false, errorMessage: String = "探索过程中发生了未知错误") {
           self.hasFailed = hasFailed
           self.errorMessage = errorMessage
       }
   }
   ```

3. 修改 state 属性（约第19行）
   ```swift
   @State private var explorationResult: ExplorationResult? = nil
   ```

4. 修改 sheet 调用（约第75行）
   ```swift
   .sheet(isPresented: $showExplorationResult) {
       if let result = explorationResult {
           ExplorationResultView(
               hasFailed: result.hasFailed,
               errorMessage: result.errorMessage,
               onRetry: {
                   // 关闭弹窗并重新探索
                   showExplorationResult = false
                   handleExplore()
               }
           )
       } else {
           ExplorationResultView()
       }
   }
   ```

5. 运行App，进入资源Tab → POI分段
6. 点击任意POI进入详情页
7. 点击"搜寻此POI"按钮
8. 验证错误状态显示正确
9. 点击"重试"按钮，验证回调执行

**恢复**: 将 `handleExplore()` 改回原样
```swift
private func handleExplore() {
    print("🔍 [POI详情] 开始搜寻: \(poi.name)")
    showExplorationResult = true
}
```

---

## 🎯 设计规范验证

### 空状态规范
- ✅ 图标大小: 60pt
- ✅ 图标颜色: `ApocalypseTheme.textMuted`
- ✅ 主标题字体: `.headline`
- ✅ 主标题颜色: `ApocalypseTheme.textSecondary`
- ✅ 副标题字体: `.caption`
- ✅ 副标题颜色: `ApocalypseTheme.textMuted`
- ✅ 布局: 垂直居中，最大宽度
- ✅ 间距: `spacing: 16`
- ✅ 内边距: `padding(.vertical, 60)`

### 错误状态规范
- ✅ 图标: `exclamationmark.triangle.fill`
- ✅ 图标大小: 60pt
- ✅ 图标颜色: `ApocalypseTheme.danger`
- ✅ 背景圆形: 120pt，红色半透明
- ✅ 标题: "探索失败"
- ✅ 错误信息: 可自定义
- ✅ 重试按钮: 渐变背景，带图标
- ✅ 布局: 垂直居中

---

## 📊 测试检查清单

### POIListView
- [ ] 完全无POI时显示正确空状态
- [ ] 筛选后无结果时显示正确空状态
- [ ] 图标大小和颜色符合规范
- [ ] 文字内容正确

### BackpackView
- [ ] 背包为空时显示正确空状态
- [ ] 搜索无结果时显示正确空状态
- [ ] 筛选无结果时显示正确空状态
- [ ] 图标大小和颜色符合规范
- [ ] 文字内容正确

### ExplorationResultView
- [ ] 成功状态显示正常
- [ ] 失败状态显示错误视图
- [ ] 错误图标和文字正确
- [ ] 重试按钮可用且回调正确
- [ ] 导航栏标题根据状态切换
- [ ] 图标大小和颜色符合规范

---

## 🐛 常见问题

### Q: 为什么空状态没有显示？
A: 检查数据源是否真的为空，确认条件判断逻辑正确。

### Q: 错误状态的重试按钮没有显示？
A: 确保传入了 `onRetry` 回调参数。

### Q: 切换分类时空状态闪烁？
A: 这是正常的，因为列表有fade动画。

---

## 📱 测试环境

- ✅ iOS 17.6+
- ✅ iPhone模拟器
- ✅ 深色模式支持
- ✅ 文字自适应大小

---

## 🎉 验收标准

完成以下测试即为成功：
1. ✅ POI列表的两种空状态都正确显示
2. ✅ 背包页的两种空状态都正确显示
3. ✅ 探索结果的失败状态正确显示
4. ✅ 所有图标大小为60pt
5. ✅ 所有文字颜色为灰色系
6. ✅ 所有状态居中显示
7. ✅ 重试按钮功能正常

**所有状态美观、清晰、易懂！**
