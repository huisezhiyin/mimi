# Spec: mimi 形态与表达系统

## 1. 背景

当前 `mimi` 已经具备最小的注意力切换能力：

1. 输入时优先监督文本光标
2. 生成时优先进入“好奇等待”
3. `Codex` 已可通过本地 session 文件识别 `preparing / streaming / settling`

但当前角色表现仍然偏弱，主要问题是：

1. 状态已经切换，但视觉变化还不够丰富
2. 文字气泡与形态都还是硬编码的
3. 若未来直接把“说什么”“长什么样”全部交给大模型，容易失控、抖动或风格不一致

因此，需要在注意力系统之上增加一层独立的“形态与表达系统”。

## 2. 目标

本次目标：

1. 定义一套独立于跟随逻辑的角色形态系统
2. 明确哪些决策由规则状态机负责，哪些可以交给大模型点缀
3. 为后续扩展更多预设形态和用户自定义形态留出稳定结构
4. 保持当前 MVP 仍可在无大模型参与时稳定运行

非目标：

1. 本轮不直接接入在线大模型生成形态
2. 不做复杂骨骼动画、逐帧素材系统或完整角色编辑器
3. 不在本轮实现完整的用户素材导入

## 3. 核心原则

### 3.1 状态决定主语义，大模型只做点缀

必须由规则系统决定：

1. 当前优先看哪里
2. 当前属于 `typing / preparing / streaming / settling / idle` 哪一种主语义
3. 哪种行为优先级更高

可以由大模型参与的部分：

1. 短文字气泡
2. 在受限范围内选择更细的表达风格
3. 在同一主语义下选择更偏“认真 / 好奇 / 放松”的细分形态

禁止直接交给大模型的部分：

1. 是否进入生成态
2. 多事件同时发生时的优先级
3. 直接生成任意、不受约束的形态参数

### 3.2 形态层与信号层解耦

需要明确区分：

1. 信号层
   回答“现在发生了什么”
2. 跟随层
   回答“看哪里”
3. 形态层
   回答“现在长成什么样”
4. 表达层
   回答“现在要不要说一句话”

### 3.3 先做形态库，再做智能选择

正确顺序应为：

1. 先定义一批可控预设形态
2. 先让规则系统稳定选择这些形态
3. 再允许大模型在预设形态内做更细粒度选择
4. 最后再考虑用户自定义形态与素材

## 4. 建议分层

### 4.1 主状态层

建议保留现有主状态语义：

1. `typing`
2. `preparing`
3. `streaming`
4. `settling`
5. `idle`

这些状态决定主表达方向，不直接决定具体绘制细节。

### 4.2 形态预设层

建议引入 `ExpressionPreset` 概念。

最小预设集建议包括：

1. `typing_focus`
   认真监督输入
2. `typing_soft`
   输入后短暂保活，不那么紧绷
3. `generation_prepare`
   轻量期待
4. `generation_watch`
   好奇围观生成
5. `generation_review`
   结果刚出来时的短暂停留
6. `idle_rest`
   休息

### 4.3 表达点缀层

在形态预设之上，再加一层轻量表达：

1. 是否允许气泡
2. 气泡频率
3. 候选短句集合
4. 是否允许更明显的耳朵 / 尾巴变化
5. 气泡使用哪一种受控视觉风格

### 4.4 运行时表达状态层

`BubblePolicy` 只描述静态规则，不应直接承载运行时状态。

需要额外引入独立的 `ExpressionRuntimeState`，负责：

1. 当前是否有正在展示的气泡
2. 当前气泡何时过期
3. 每个预设上一次展示时间
4. 每个预设上一次展示文本，用于避免连续重复
5. 对外产出可直接供视图消费的 `BubblePresentation`

这样 `PetView` 只负责：

1. 根据当前信号解析 `ExpressionPreset`
2. 向运行时状态请求当前的 `BubblePresentation`
3. 按预设和运行时结果完成绘制

不再直接持有气泡节流、去重、过期这些运行时逻辑。

## 5. 最小数据模型

建议形态系统最终收敛为数据驱动，而不是全部硬编码在 `PetView`。

建议最小模型：

```swift
struct ExpressionPreset {
    let id: String
    let category: ExpressionCategory
    let eye: EyePreset
    let mouth: MouthPreset
    let ears: EarPreset
    let tail: TailPreset
    let accentStyle: ExpressionAccentStyle
    let bubblePolicy: BubblePolicy
}

enum ExpressionCategory {
    case typing
    case generationPreparing
    case generationStreaming
    case generationSettling
    case idle
}

struct BubblePolicy {
    let enabled: Bool
    let candidates: [String]
    let minInterval: TimeInterval
    let displayDuration: TimeInterval
    let style: BubbleVisualStyle
}

enum BubbleVisualStyle {
    case neutral
    case gentle
    case curious
    case pleased
}

struct BubblePresentation {
    let text: String
    let style: BubbleVisualStyle
}
```

参数不要求一开始全部实现为独立文件，但设计上应朝数据驱动收敛。

## 6. 规则系统与大模型的边界

### 6.1 规则系统负责

规则系统负责：

1. 从主状态映射到可用形态范围
2. 控制气泡是否允许出现
3. 控制气泡最低间隔
4. 在多事件冲突时保持风格稳定

例如：

1. `typing` 时默认禁止气泡
2. `streaming` 时允许低频短气泡
3. `idle` 时禁止频繁变化

### 6.2 大模型负责

大模型未来若接入，只负责：

1. 在候选气泡里做选择
2. 生成一条短句，但必须满足长度、风格和状态约束
3. 在允许的预设集合中选择更细分的表达

第一版接入建议进一步收窄为：

1. 只参与短气泡文案
2. 不参与主状态判断
3. 不参与优先级判断
4. 不参与视线目标选择

例如在 `streaming` 状态下，大模型可以在以下范围内工作：

1. 候选形态：`generation_watch`
2. 候选短句：`唔...`、`在写了`、`盯住`
3. 风格约束：短、轻、不过度打扰

### 6.3 不建议的大模型直控方式

以下方式不建议采用：

1. 让大模型每一帧决定眼睛、嘴巴、耳朵参数
2. 让大模型直接决定是否进入某个状态
3. 让大模型自由输出任意长气泡文本

原因：

1. 难以保持风格一致
2. 成本高
3. 交互延迟高
4. 易产生“说得太多、动得太乱”的问题

## 7. 自定义形态方向

未来需要支持“更多形态”与“用户自定义形态”。

建议按三层开放能力：

### 7.1 官方预设扩展

先允许内置更多预设：

1. `curious_peek`
2. `serious_review`
3. `tiny_proud`
4. `sleepy_wait`
5. `confused_pause`

### 7.2 参数级自定义

在不换素材的前提下，允许用户修改：

1. 眼睛大小与圆度
2. 瞳孔大小
3. 嘴型风格
4. 耳朵倾斜程度
5. 尾巴姿态
6. 是否允许气泡
7. 气泡语气

### 7.3 素材级自定义

更后续的方向才考虑：

1. 自定义角色皮肤
2. 自定义耳朵 / 尾巴 / 脸部素材
3. 导入完整形态包

本轮不做这层。

## 8. 推荐落地顺序

建议顺序：

1. 把当前硬编码的 `typing / streaming / settling / idle` 形态先抽成预设
2. 新增 `ExpressionPresetResolver`
3. 让 `PetView` 从预设绘制，而不是直接散落条件判断
4. 新增 `ExpressionRuntimeState` 承接气泡运行时状态
5. 再加 `BubblePolicy`
6. 最后才加大模型参与的短句生成或预设选择

## 9. 与现有系统的关系

这套系统与已有 spec 的关系如下：

1. [mimi_attention_behavior_spec.md](/Users/wuyue/github_project/mimi/docs/spec/mimi_attention_behavior_spec.md)
   负责注意力与优先级
2. [mimi_generation_signal_adapter_spec.md](/Users/wuyue/github_project/mimi/docs/spec/mimi_generation_signal_adapter_spec.md)
   负责识别是否生成中
3. 本 spec
   负责角色在不同主状态下“应该长成什么样、说不说话”

## 10. 当前结论

对于 `mimi`，更优的方向不是“让大模型直接决定一切”，而是：

1. 用规则系统稳定决定状态与优先级
2. 用形态库保证角色一致性
3. 用大模型做轻量点缀与受限选择

这样既能保持“像猫一样活着”的灵动感，又不会让系统变成不可控的随机角色。

## 11. LLM 接入约束

第一版 LLM 接入只允许落在表达层，具体约束如下：

1. 通过独立的 `ExpressionTextProvider` 协议接入
2. `ExpressionRuntimeState` 先生成本地 fallback 气泡
3. 若配置了 LLM provider，则异步请求更短、更贴合状态的文案
4. 若请求失败、超时或返回不合规文本，继续使用本地 fallback
5. `PetView` 不直接发网络请求，只消费 runtime 产出的 `BubblePresentation`

建议通过环境变量启用，最小配置包括：

1. `MIMI_LLM_API_BASE_URL`
2. `MIMI_LLM_API_KEY`
3. `MIMI_LLM_MODEL`

协议上使用 OpenAI-compatible chat completions 即可；未配置时整个系统必须保持现有本地行为不变。

## 12. Change Log

截至 `2026-03-20`，已完成以下最小骨架落地：

1. 新增 `ExpressionPreset.swift`，定义形态预设所需的最小数据结构
2. 新增 `ExpressionPresetResolver.swift`，负责把 `AttentionMode + GenerationPhase` 映射到预设
3. `PetView.swift` 已改为通过 resolver 读取预设绘制，不再只依赖散落的条件判断
4. `BubblePolicy` 已补上最小节流与展示时长，并支持在候选短句中做轻量随机选择
5. 新增 `ExpressionRuntimeState.swift`，负责气泡展示的运行时节流、过期与去重
6. `PetView.swift` 不再直接持有气泡运行时状态，只向 `ExpressionRuntimeState` 请求当前展示结果
7. `ExpressionRuntimeState` 对外接口已从裸字符串收敛为 `BubblePresentation`
8. `BubblePresentation` 已带上受控视觉 style，并由 `PetView` 负责实际绘制映射
9. 新增 `ExpressionTextProvider` 协议，用于把 LLM 文案能力限制在表达层
10. 新增 OpenAI-compatible 文案服务，并支持通过环境变量启用
11. `ExpressionRuntimeState` 已支持“先本地 fallback，再异步尝试替换为 LLM 文案”

## 13. Validation

1. 已通过 `git diff --check` 做静态检查，当前 patch 无明显格式问题。
2. 当前只完成静态代码骨架与文档同步，未运行 Xcode 编译。
3. 当前 bubble 已支持最小节流、展示时长、候选随机、`BubblePresentation` 输出与受控视觉 style。
4. 未配置 `MIMI_LLM_API_BASE_URL / MIMI_LLM_API_KEY / MIMI_LLM_MODEL` 时，系统应保持现有本地 fallback 行为不变。
