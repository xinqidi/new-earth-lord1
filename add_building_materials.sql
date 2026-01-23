-- 添加建造材料到 item_definitions 表
-- 在 Supabase 控制台的 SQL Editor 中执行此脚本

-- 1. 木材 (Wood)
INSERT INTO item_definitions (id, name, description, category, rarity, weight, icon, stackable, max_stack_size, durability)
VALUES (
    'wood',
    '木材',
    '基础建筑材料，可用于建造和升级建筑',
    'material',
    'common',
    1.0,
    'tree.fill',
    true,
    999,
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- 2. 石头 (Stone)
INSERT INTO item_definitions (id, name, description, category, rarity, weight, icon, stackable, max_stack_size, durability)
VALUES (
    'stone',
    '石头',
    '坚固的建筑材料，用于加固建筑结构',
    'material',
    'common',
    2.0,
    'square.3.layers.3d',
    true,
    999,
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- 3. 金属 (Metal)
INSERT INTO item_definitions (id, name, description, category, rarity, weight, icon, stackable, max_stack_size, durability)
VALUES (
    'metal',
    '金属',
    '稀有的金属材料，用于高级建筑',
    'material',
    'rare',
    3.0,
    'gearshape.2.fill',
    true,
    999,
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- 4. 玻璃 (Glass)
INSERT INTO item_definitions (id, name, description, category, rarity, weight, icon, stackable, max_stack_size, durability)
VALUES (
    'glass',
    '玻璃',
    '透明材料，用于能源建筑',
    'material',
    'rare',
    1.5,
    'square.grid.3x3.fill',
    true,
    999,
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- 验证插入结果
SELECT id, name, category, rarity FROM item_definitions
WHERE id IN ('wood', 'stone', 'metal', 'glass')
ORDER BY id;
