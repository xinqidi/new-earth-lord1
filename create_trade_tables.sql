-- ============================================
-- 交易系统数据库表创建脚本
-- 游戏：地球新主
-- 创建时间：2026-01-23
-- ============================================

-- ============================================
-- 1. 创建 trade_offers 表（交易挂单）
-- ============================================

CREATE TABLE IF NOT EXISTS public.trade_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_username TEXT NOT NULL,
    offering_items JSONB NOT NULL DEFAULT '[]',  -- 出售物品 [{"item_id": "wood", "quantity": 10}]
    requesting_items JSONB NOT NULL DEFAULT '[]', -- 需要物品 [{"item_id": "stone", "quantity": 5}]
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'expired')),
    message TEXT,  -- 留言（可选）
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,  -- 过期时间（可选，NULL表示永不过期）
    completed_at TIMESTAMPTZ,  -- 完成时间
    completed_by_user_id UUID REFERENCES auth.users(id),  -- 接受者ID
    completed_by_username TEXT  -- 接受者用户名
);

-- 添加表注释
COMMENT ON TABLE public.trade_offers IS '交易挂单表';
COMMENT ON COLUMN public.trade_offers.offering_items IS '出售物品列表，JSON格式 [{"item_id": "wood", "quantity": 10}]';
COMMENT ON COLUMN public.trade_offers.requesting_items IS '需要物品列表，JSON格式 [{"item_id": "stone", "quantity": 5}]';

-- ============================================
-- 2. 创建 trade_history 表（交易历史）
-- ============================================

CREATE TABLE IF NOT EXISTS public.trade_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID NOT NULL REFERENCES public.trade_offers(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES auth.users(id),
    seller_username TEXT NOT NULL,
    buyer_id UUID NOT NULL REFERENCES auth.users(id),
    buyer_username TEXT NOT NULL,
    items_exchanged JSONB NOT NULL,  -- {"seller_gave": [...], "buyer_gave": [...]}
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    seller_rating INT CHECK (seller_rating >= 1 AND seller_rating <= 5),  -- 卖家对买家的评分
    buyer_rating INT CHECK (buyer_rating >= 1 AND buyer_rating <= 5),   -- 买家对卖家的评分
    seller_comment TEXT,  -- 卖家评语
    buyer_comment TEXT    -- 买家评语
);

-- 添加表注释
COMMENT ON TABLE public.trade_history IS '交易历史记录表';
COMMENT ON COLUMN public.trade_history.items_exchanged IS '交换详情，JSON格式 {"seller_gave": [...], "buyer_gave": [...]}';

-- ============================================
-- 2.5 创建 pending_items 表（待领取物品）
-- ============================================

CREATE TABLE IF NOT EXISTS public.pending_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL,           -- 物品ID（如 "wood", "stone"）
    quantity INT NOT NULL CHECK (quantity > 0),
    source_type TEXT NOT NULL,       -- 来源类型（trade/gift/reward）
    source_id UUID,                  -- 来源ID（如交易历史ID）
    source_description TEXT,         -- 来源描述
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    claimed_at TIMESTAMPTZ           -- 领取时间（NULL表示未领取）
);

-- 添加表注释
COMMENT ON TABLE public.pending_items IS '待领取物品表';
COMMENT ON COLUMN public.pending_items.source_type IS '来源类型：trade=交易, gift=赠送, reward=奖励';

-- ============================================
-- 3. 创建索引
-- ============================================

-- trade_offers 索引
CREATE INDEX IF NOT EXISTS idx_trade_offers_owner_id ON public.trade_offers(owner_id);
CREATE INDEX IF NOT EXISTS idx_trade_offers_status ON public.trade_offers(status);
CREATE INDEX IF NOT EXISTS idx_trade_offers_created_at ON public.trade_offers(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trade_offers_expires_at ON public.trade_offers(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_trade_offers_active ON public.trade_offers(status, created_at DESC) WHERE status = 'active';

-- trade_history 索引
CREATE INDEX IF NOT EXISTS idx_trade_history_seller_id ON public.trade_history(seller_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_buyer_id ON public.trade_history(buyer_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_completed_at ON public.trade_history(completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_trade_history_offer_id ON public.trade_history(offer_id);

-- pending_items 索引
CREATE INDEX IF NOT EXISTS idx_pending_items_user_id ON public.pending_items(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_items_unclaimed ON public.pending_items(user_id, created_at DESC) WHERE claimed_at IS NULL;

-- ============================================
-- 4. 启用 RLS（行级安全）
-- ============================================

ALTER TABLE public.trade_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_items ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 5. 创建 RLS 策略
-- ============================================

-- trade_offers 策略

-- 所有人可以查看活跃的挂单
CREATE POLICY "Anyone can view active offers"
ON public.trade_offers
FOR SELECT
USING (status = 'active' OR owner_id = auth.uid());

-- 用户只能插入自己的挂单（通过RPC）
CREATE POLICY "Users can insert own offers"
ON public.trade_offers
FOR INSERT
WITH CHECK (owner_id = auth.uid());

-- 用户可以更新自己的挂单或完成别人的挂单
CREATE POLICY "Users can update offers"
ON public.trade_offers
FOR UPDATE
USING (owner_id = auth.uid() OR (status = 'active' AND auth.uid() IS NOT NULL));

-- 用户只能删除自己的挂单
CREATE POLICY "Users can delete own offers"
ON public.trade_offers
FOR DELETE
USING (owner_id = auth.uid());

-- trade_history 策略

-- 用户可以查看自己参与的历史
CREATE POLICY "Users can view own history"
ON public.trade_history
FOR SELECT
USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- 插入通过RPC控制
CREATE POLICY "System can insert history"
ON public.trade_history
FOR INSERT
WITH CHECK (true);

-- 用户可以更新自己的评分
CREATE POLICY "Users can update own rating"
ON public.trade_history
FOR UPDATE
USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- pending_items 策略

-- 用户只能查看自己的待领取物品
CREATE POLICY "Users can view own pending items"
ON public.pending_items
FOR SELECT
USING (user_id = auth.uid());

-- 插入通过RPC控制（SECURITY DEFINER）
CREATE POLICY "System can insert pending items"
ON public.pending_items
FOR INSERT
WITH CHECK (true);

-- 用户可以更新自己的待领取物品（领取）
CREATE POLICY "Users can update own pending items"
ON public.pending_items
FOR UPDATE
USING (user_id = auth.uid());

-- ============================================
-- 6. 创建 RPC 函数
-- ============================================

-- 6.1 创建交易挂单
CREATE OR REPLACE FUNCTION public.create_trade_offer(
    p_owner_username TEXT,
    p_offering_items JSONB,
    p_requesting_items JSONB,
    p_message TEXT DEFAULT NULL,
    p_expires_in_hours INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_offer_id UUID;
    v_expires_at TIMESTAMPTZ;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '用户未登录');
    END IF;

    -- 计算过期时间
    IF p_expires_in_hours IS NOT NULL AND p_expires_in_hours > 0 THEN
        v_expires_at := now() + (p_expires_in_hours || ' hours')::interval;
    ELSE
        v_expires_at := NULL;
    END IF;

    -- 插入挂单
    INSERT INTO public.trade_offers (
        owner_id,
        owner_username,
        offering_items,
        requesting_items,
        status,
        message,
        expires_at
    ) VALUES (
        v_user_id,
        p_owner_username,
        p_offering_items,
        p_requesting_items,
        'active',
        p_message,
        v_expires_at
    )
    RETURNING id INTO v_offer_id;

    RETURN jsonb_build_object(
        'success', true,
        'offer_id', v_offer_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 6.2 接受交易挂单（带行级锁确保并发安全）
CREATE OR REPLACE FUNCTION public.accept_trade_offer(
    p_offer_id UUID,
    p_buyer_username TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_buyer_id UUID;
    v_offer RECORD;
    v_history_id UUID;
    v_items_exchanged JSONB;
    v_item RECORD;
BEGIN
    -- 获取当前用户ID
    v_buyer_id := auth.uid();

    IF v_buyer_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '用户未登录');
    END IF;

    -- 使用 FOR UPDATE 锁定挂单记录，防止并发
    SELECT * INTO v_offer
    FROM public.trade_offers
    WHERE id = p_offer_id
    FOR UPDATE;

    -- 检查挂单是否存在
    IF v_offer IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '挂单不存在');
    END IF;

    -- 检查是否是自己的挂单
    IF v_offer.owner_id = v_buyer_id THEN
        RETURN jsonb_build_object('success', false, 'error', '不能接受自己的挂单');
    END IF;

    -- 检查状态
    IF v_offer.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', '挂单已不可用');
    END IF;

    -- 检查是否过期
    IF v_offer.expires_at IS NOT NULL AND v_offer.expires_at <= now() THEN
        -- 标记为过期
        UPDATE public.trade_offers
        SET status = 'expired'
        WHERE id = p_offer_id;

        RETURN jsonb_build_object('success', false, 'error', '挂单已过期');
    END IF;

    -- 构建交换信息
    v_items_exchanged := jsonb_build_object(
        'seller_gave', v_offer.offering_items,
        'buyer_gave', v_offer.requesting_items
    );

    -- 更新挂单状态为已完成
    UPDATE public.trade_offers
    SET
        status = 'completed',
        completed_at = now(),
        completed_by_user_id = v_buyer_id,
        completed_by_username = p_buyer_username
    WHERE id = p_offer_id;

    -- 创建交易历史记录
    INSERT INTO public.trade_history (
        offer_id,
        seller_id,
        seller_username,
        buyer_id,
        buyer_username,
        items_exchanged
    ) VALUES (
        p_offer_id,
        v_offer.owner_id,
        v_offer.owner_username,
        v_buyer_id,
        p_buyer_username,
        v_items_exchanged
    )
    RETURNING id INTO v_history_id;

    -- 为卖家创建待领取物品（买家支付的物品）
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_offer.requesting_items) AS x(item_id TEXT, quantity INT)
    LOOP
        INSERT INTO public.pending_items (
            user_id,
            item_id,
            quantity,
            source_type,
            source_id,
            source_description
        ) VALUES (
            v_offer.owner_id,
            v_item.item_id,
            v_item.quantity,
            'trade',
            v_history_id,
            '交易所得：来自 ' || p_buyer_username
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'history_id', v_history_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 6.3 取消交易挂单
CREATE OR REPLACE FUNCTION public.cancel_trade_offer(
    p_offer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_offer RECORD;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '用户未登录');
    END IF;

    -- 锁定并获取挂单
    SELECT * INTO v_offer
    FROM public.trade_offers
    WHERE id = p_offer_id
    FOR UPDATE;

    -- 检查挂单是否存在
    IF v_offer IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '挂单不存在');
    END IF;

    -- 检查是否是自己的挂单
    IF v_offer.owner_id != v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', '只能取消自己的挂单');
    END IF;

    -- 检查状态
    IF v_offer.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', '挂单已不可用');
    END IF;

    -- 更新状态为已取消
    UPDATE public.trade_offers
    SET status = 'cancelled'
    WHERE id = p_offer_id;

    -- 物品退还在客户端处理

    RETURN jsonb_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 6.4 批量处理过期挂单
CREATE OR REPLACE FUNCTION public.process_expired_offers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    -- 将所有过期的活跃挂单标记为过期
    UPDATE public.trade_offers
    SET status = 'expired'
    WHERE status = 'active'
      AND expires_at IS NOT NULL
      AND expires_at <= now();

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object('processed_count', v_count);
END;
$$;

-- 6.5 获取待领取物品列表
CREATE OR REPLACE FUNCTION public.get_pending_items()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_items JSONB;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '用户未登录');
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'item_id', item_id,
            'quantity', quantity,
            'source_type', source_type,
            'source_description', source_description,
            'created_at', created_at
        ) ORDER BY created_at DESC
    ), '[]'::jsonb) INTO v_items
    FROM public.pending_items
    WHERE user_id = v_user_id AND claimed_at IS NULL;

    RETURN jsonb_build_object(
        'success', true,
        'items', v_items
    );
END;
$$;

-- 6.6 领取待领取物品
CREATE OR REPLACE FUNCTION public.claim_pending_item(
    p_pending_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '用户未登录');
    END IF;

    -- 锁定并获取待领取物品
    SELECT * INTO v_item
    FROM public.pending_items
    WHERE id = p_pending_item_id
    FOR UPDATE;

    -- 检查是否存在
    IF v_item IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '物品不存在');
    END IF;

    -- 检查是否是自己的
    IF v_item.user_id != v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', '无权领取此物品');
    END IF;

    -- 检查是否已领取
    IF v_item.claimed_at IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '物品已领取');
    END IF;

    -- 标记为已领取
    UPDATE public.pending_items
    SET claimed_at = now()
    WHERE id = p_pending_item_id;

    -- 返回物品信息，客户端负责添加到背包
    RETURN jsonb_build_object(
        'success', true,
        'item_id', v_item.item_id,
        'quantity', v_item.quantity
    );
END;
$$;

-- 6.7 批量领取所有待领取物品
CREATE OR REPLACE FUNCTION public.claim_all_pending_items()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_items JSONB;
    v_count INT;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '用户未登录');
    END IF;

    -- 获取所有未领取的物品
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'item_id', item_id,
            'quantity', quantity
        )
    ), '[]'::jsonb) INTO v_items
    FROM public.pending_items
    WHERE user_id = v_user_id AND claimed_at IS NULL;

    -- 标记所有物品为已领取
    UPDATE public.pending_items
    SET claimed_at = now()
    WHERE user_id = v_user_id AND claimed_at IS NULL;

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'items', v_items,
        'claimed_count', v_count
    );
END;
$$;

-- ============================================
-- 7. 授予函数执行权限
-- ============================================

GRANT EXECUTE ON FUNCTION public.create_trade_offer TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_trade_offer TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_trade_offer TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_expired_offers TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_items TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_pending_item TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_all_pending_items TO authenticated;

-- ============================================
-- 8. 验证脚本
-- ============================================

-- 运行以下查询验证表创建成功：
-- SELECT * FROM public.trade_offers LIMIT 1;
-- SELECT * FROM public.trade_history LIMIT 1;

-- 验证RPC函数：
-- SELECT public.create_trade_offer('test_user', '[{"item_id": "wood", "quantity": 10}]'::jsonb, '[{"item_id": "stone", "quantity": 5}]'::jsonb, NULL, 24);
