import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// 阿里云百炼API配置
const DASHSCOPE_API_KEY = Deno.env.get("DASHSCOPE_API_KEY");
const DASHSCOPE_API_URL =
  "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
const MODEL = "qwen-turbo";

// 稀有度映射
const RARITY_MAP: Record<string, string> = {
  普通: "common",
  优秀: "uncommon",
  稀有: "rare",
  史诗: "epic",
  传奇: "legendary",
};

// 危险等级对应的稀有度分布提示
const DANGER_PROMPTS: Record<number, string> = {
  1: "危险等级1（低危）：大部分物品应该是普通(70%)，少量优秀(25%)，极少稀有(5%)",
  3: "危险等级3（中危）：普通(50%)，优秀(30%)，稀有(15%)，史诗(5%)",
  4: "危险等级4（高危）：优秀(40%)，稀有(35%)，史诗(20%)，传奇(5%)",
  5: "危险等级5（极危）：稀有(30%)，史诗(40%)，传奇(30%)",
};

// 请求体接口
interface GenerateItemsRequest {
  poiType: string;
  poiName: string;
  dangerLevel: number;
  itemCount: number;
}

// AI生成的物品接口
interface AIGeneratedItem {
  itemId: string;
  name: string;
  category: string;
  rarity: string;
  story: string;
  icon: string;
  quantity: number;
}

// 阿里云百炼响应接口
interface DashScopeResponse {
  choices: {
    message: {
      content: string;
    };
  }[];
}

Deno.serve(async (req: Request) => {
  // 只允许POST请求
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Method not allowed" }),
      {
        status: 405,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  try {
    // 检查API密钥
    if (!DASHSCOPE_API_KEY) {
      console.error("❌ DASHSCOPE_API_KEY 环境变量未设置");
      return new Response(
        JSON.stringify({
          success: false,
          error: "API key not configured",
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // 解析请求体
    const requestBody: GenerateItemsRequest = await req.json();
    const { poiType, poiName, dangerLevel, itemCount } = requestBody;

    console.log(
      `🤖 [AI生成] 开始为 ${poiName} (${poiType}) 生成 ${itemCount} 个物品，危险等级: ${dangerLevel}`
    );

    // 构建提示词
    const dangerPrompt = DANGER_PROMPTS[dangerLevel] ||
      DANGER_PROMPTS[3];
    const systemPrompt = `你是一个末日废土世界的物品生成器。你需要为玩家搜刮POI地点时生成合理的物品。

规则：
1. 物品必须符合POI类型和末日废土世界观
2. ${dangerPrompt}
3. 每个物品需要包含：名称、分类（food/medicine/material/tool/clothing/weapon）、稀有度（普通/优秀/稀有/史诗/传奇）、背景故事（30-50字）、SF Symbols图标名称、数量
4. 物品名称要有末日感，如"沾血的绷带"、"生锈的罐头"、"过期能量棒"
5. 背景故事要简短有氛围感，描述物品的发现过程或状态
6. 图标使用 SF Symbols 名称（如 fork.knife, pills.fill, wrench.fill等）

请以JSON数组格式返回，示例：
[
  {
    "name": "过期能量棒",
    "category": "food",
    "rarity": "优秀",
    "story": "包装上的日期显示这是三年前的产品，但密封完好。撕开包装，依稀能闻到巧克力的香气。",
    "icon": "fork.knife",
    "quantity": 1
  }
]`;

    const userPrompt =
      `在【${poiName}】（类型：${poiType}）这个地点，玩家进行搜刮。请生成 ${itemCount} 个合理的物品。`;

    // 调用阿里云百炼API
    const dashscopeResponse = await fetch(DASHSCOPE_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${DASHSCOPE_API_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.8,
        max_tokens: 2000,
      }),
    });

    if (!dashscopeResponse.ok) {
      const errorText = await dashscopeResponse.text();
      console.error(
        `❌ [阿里云百炼] API调用失败: ${dashscopeResponse.status} ${errorText}`
      );
      return new Response(
        JSON.stringify({
          success: false,
          error: `AI API error: ${dashscopeResponse.status}`,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const aiResponse: DashScopeResponse = await dashscopeResponse.json();
    const aiContent = aiResponse.choices[0].message.content;

    console.log(`🤖 [AI响应] ${aiContent}`);

    // 解析AI返回的JSON（可能被markdown包裹）
    let itemsJson = aiContent.trim();

    // 移除可能的markdown代码块标记
    if (itemsJson.startsWith("```json")) {
      itemsJson = itemsJson.replace(/^```json\s*/, "").replace(/\s*```$/, "");
    } else if (itemsJson.startsWith("```")) {
      itemsJson = itemsJson.replace(/^```\s*/, "").replace(/\s*```$/, "");
    }

    const rawItems = JSON.parse(itemsJson);

    // 转换为标准格式
    const timestamp = Date.now();
    const items: AIGeneratedItem[] = rawItems.map(
      (item: any, index: number) => ({
        itemId: `ai_${timestamp}_${index}`,
        name: item.name,
        category: item.category,
        rarity: RARITY_MAP[item.rarity] || "common",
        story: item.story || `在${poiName}的废墟中发现的物品。`,
        icon: item.icon || "questionmark",
        quantity: item.quantity || 1,
      })
    );

    console.log(`✅ [AI生成] 成功生成 ${items.length} 个物品`);
    for (const item of items) {
      console.log(
        `   - ${item.name} [${item.rarity}] ${item.story.substring(0, 20)}...`
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        items: items,
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Connection": "keep-alive",
        },
      }
    );
  } catch (error) {
    console.error("❌ [Edge Function] 错误:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
