# Spec: mimi 生成信号 Adapter 方案

## 1. 背景

当前版本想解决的问题不是“猫能不能看到哪里在动”，而是“猫能不能更像知道用户正在等待大模型输出”。

仅靠以下信号还不够：

1. 文本光标位置
2. 键盘 / 鼠标活动
3. 局部屏幕变化

这些信号可以帮助角色判断“看哪里”，但不能稳定回答：

1. 当前是否真的进入了生成阶段
2. 生成是否仍在持续
3. 当前生成来自哪个工具

因此，需要在注意力系统之上增加一层“生成信号适配层”。

## 2. 目标

本次目标：

1. 优先通过 `codex / claude / ide` 的结构化事件、日志或可观察状态，判断“是否正在生成”。
2. 将“生成信号”和“看哪里”解耦：
   - `生成信号` 决定是否切入“好奇等待”
   - `位置来源` 决定猫具体看向哪里
3. 为后续逐个接入真实环境保留统一抽象，而不是把逻辑写死在 `AppDelegate` 中。

非目标：

1. 不在本轮实现所有适配器。
2. 不做通用网页 DOM 抓取方案。
3. 不承诺所有工具都能拿到精确输出区域坐标。

## 3. 核心原则

### 3.1 事件优先于屏幕猜测

信号优先级应为：

1. 工具显式事件
2. 工具可观察状态或日志
3. 局部屏幕变化
4. 纯时间推断

原因：

1. 显式事件最接近真实语义
2. 日志 / 状态通常比屏幕 diff 更省资源
3. 屏幕变化只能作为辅助，不应成为主真相源

### 3.2 生成信号与位置信号分层

需要避免把两个问题绑死：

1. “现在是否在生成”
2. “生成内容大概在哪里”

例如：

- `codex` 日志可以告诉我们“正在生成”
- 文本光标 / 窗口布局规则可以帮助估计“该看哪里”

### 3.3 先做高频工作流

不平均支持所有工具，优先级建议：

1. `Codex CLI / 本地 agent 会话`
2. `Claude Code / Claude CLI`
3. `Cursor / VSCode / IDE AI 面板`
4. 其他聊天应用

## 4. 抽象设计

### 4.1 统一状态模型

建议新增：

```swift
enum GenerationPhase {
    case inactive
    case preparing
    case streaming
    case settling
}
```

语义：

1. `inactive`
   当前没有可靠生成信号
2. `preparing`
   用户刚提交请求，工具已进入处理但尚未稳定输出
3. `streaming`
   明确正在输出
4. `settling`
   输出刚结束，保留短暂“盯住结果”的尾巴，避免立刻回弹

### 4.2 统一快照模型

建议新增：

```swift
struct GenerationSessionSnapshot {
    let providerId: String
    let sessionId: String
    let phase: GenerationPhase
    let updatedAt: Date
    let workDir: String?
    let terminalType: String?
    let outputAnchorRect: CGRect?
}

struct GenerationSignalSnapshot {
    let phase: GenerationPhase
    let source: String
    let confidence: Double
    let updatedAt: Date
    let outputAnchorRect: CGRect?
    let sessionId: String
    let workDir: String?
    let terminalType: String?
    let activeSessionCount: Int
    let debugSummary: String
}
```

字段说明：

1. `phase`
   当前生成阶段
2. `source`
   信号来源，例如 `codex-log`、`claude-log`、`cursor-adapter`
3. `confidence`
   当前信号可信度
4. `updatedAt`
   最近一次更新时刻
5. `sessionId`
   当前被选中的主 session
6. `outputAnchorRect`
   若适配器能提供输出区域估计，则直接返回
7. `debugSummary`
   用于菜单栏调试

### 4.3 统一适配器协议

建议新增：

```swift
protocol GenerationSignalProvider {
    var id: String { get }
    func start()
    func stop()
    func currentSessions(now: Date) -> [GenerationSessionSnapshot]
}
```

聚合层：

```swift
final class GenerationSessionCoordinator {
    func start()
    func stop()
    func currentSnapshot(now: Date, frontmostAppName: String?) -> GenerationSignalSnapshot?
}
```

职责：

1. 挂载多个 provider
2. 选择当前最可信的快照
3. 负责阶段保活与短时去抖

## 5. Provider 分类

### 5.1 显式事件型

适用于：

1. IDE 插件事件
2. 本地 agent runtime 回调
3. 明确的 IPC / socket / file append event

优点：

1. 语义最强
2. 资源最低
3. 误判最少

缺点：

1. 需要针对具体工具做接入

### 5.2 日志型

适用于：

1. `codex` 会话 transcript
2. `claude` 本地运行日志
3. IDE AI 输出日志或本地状态文件

建议只监听与当前前台工作流强相关的文件，不做全盘扫描。

优点：

1. 相比截图更轻
2. 对 CLI / 本地 agent 工作流更现实

缺点：

1. 日志格式可能变
2. 不一定能拿到位置
3. 不同版本工具兼容性差异大

### 5.3 几何 / 屏幕辅助型

只用于补位置，不作为第一真相源。

可选来源：

1. 最近输入文本光标
2. 当前前台窗口主内容区
3. 局部屏幕变化热点

## 6. 最小产品策略

### 6.1 推荐的 MVP 组合

建议先做：

1. `GenerationSessionCoordinator`
2. `TraceCodexProvider`
3. `ClaudeGenerationProvider`
4. 现有 `AttentionMode` 与 `TrackingTarget` 的轻量接线

行为规则：

1. 若 provider 返回 `streaming`
   - 进入“好奇等待”
   - 优先看 `outputAnchorRect`
   - 若无 `outputAnchorRect`，则看最近输入焦点附近
2. 若 provider 返回 `preparing`
   - 保持最近输入焦点
   - 轻微预备态
3. 若 provider 返回 `settling`
   - 继续看最近输出区域短时间
4. 若无 provider 信号
   - 再退回现有 `Wait + 最近输入焦点 + 局部屏幕变化` 逻辑

### 6.2 不要先做的事

1. 不要一开始就做所有工具适配
2. 不要把日志解析硬编码在 `AppDelegate`
3. 不要把“是否生成”与“眼睛看哪里”写成一套不可拆逻辑

## 7. 候选适配方向

### 7.1 Codex

优先级最高。

原因：

1. 本地 agent / CLI 工作流更容易观测
2. 通常存在明确的会话事件、输出流或 transcript
3. 更适合作为第一个端到端样板

可能信号：

1. stdout / stderr 中的流式输出事件
2. 本地会话 transcript 文件变化
3. agent 运行状态文件

位置策略：

1. 优先取当前工作窗口主内容区
2. 若用户最近在 IDE 输入，则可继续看最近输入区

### 7.1.1 当前确定采用的接入方式

本轮 `Codex` 适配改为直接监听本地 `Codex home` 下的原始会话文件追加变化。

已确认的本地输入：

1. `~/.codex_aicodewith/sessions/YYYY/MM/DD/*.jsonl`
2. `~/.codex/sessions/YYYY/MM/DD/*.jsonl`
3. 每个 session 文件的 `mtime`
4. 每个 session 文件的 `size / offset` 增量

采用这条链路的原因：

1. 原始 session transcript 是当前机器上确认会实时追加的第一手数据源
2. 对 `mimi` 当前目标，只需要判断“是否持续生成”，不需要理解生成内容
3. 仅依赖文件追加变化即可得到 `streaming / settling / inactive` 三段体验，成本更低
4. `@ali/ai-coding-trace` 的 `codex-session-state-v1.json` 在本机上已确认可能滞后，因此不再作为实时真相源
5. 不同 `Codex` 安装 / 启动方式可能使用不同 home 目录，因此 provider 需要同时兼容多个本地 root

### 7.1.2 多 session 策略

`Codex` 允许同时存在多个 CLI / Desktop 会话。

本轮策略不是“小分身”，而是：

1. `TraceCodexProvider` 输出多个 session 快照
2. `GenerationSessionCoordinator` 在同一时刻只选一个 `active session`
3. 宠物始终只跟随一个主 session

仲裁优先级：

1. 前台应用与 session 终端类型匹配优先
2. `streaming` 高于 `preparing`
3. `preparing` 高于 `settling`
4. 最近更新时间更新的 session 优先

### 7.1.3 本轮实现边界

本轮只解决：

1. 基于 `~/.codex_aicodewith/sessions/**/*.jsonl` 与 `~/.codex/sessions/**/*.jsonl` 文件追加变化的 `Codex` 生成状态识别
2. 多 session 到单 active session 的仲裁
3. 将 active session 接入现有 `AttentionMode`

本轮暂不解决：

1. Web 端 GPT / Gemini
2. 通过浏览器网络层识别生成状态
3. 对每个 terminal 窗口做精确几何定位

### 7.1.4 位置降级策略

当前 raw session 文件能稳定提供会话 id、工作目录与最近活动时间，但不直接提供屏幕几何信息。

因此本轮对 `Codex` 的“看哪里”采用降级策略：

1. 若当前或最近文本光标位于终端 / Codex Desktop，则取光标上方区域作为输出关注锚点
2. 若拿不到终端文本光标，则退回最近输入焦点
3. 若再失败，则退回现有鼠标 / 屏幕变化兜底

### 7.2 Claude

优先级第二。

可能形态：

1. `Claude Code` CLI 事件 / 日志
2. 本地会话文件
3. 编辑器内集成状态

风险：

1. 不同运行方式的可观测性差异较大

### 7.3 Cursor / IDE

优先级第三。

理想信号：

1. 扩展事件
2. AI panel 状态
3. 输出面板文本增量

位置策略更自然：

1. 可直接看聊天面板区域
2. 或看编辑器中被修改 / 高亮的区域

## 8. 风险

1. “监听日志”不是通用银弹，不同工具版本和安装方式差异很大。
2. 某些工具没有稳定公开日志或事件，需要定制适配。
3. 即使知道“正在生成”，仍可能拿不到精确屏幕坐标。
4. 多 provider 并存时，需要处理优先级冲突和保活时间。

## 9. 推荐实施顺序

1. 先抽象 `GenerationSignalProvider` 和 `GenerationSessionCoordinator`
2. 先实现一个最容易验证的 provider，优先 `Codex`
3. 把 provider 信号接入现有注意力系统
4. 再决定是否继续保留屏幕变化检测作为辅助层

## 10. Change Log

截至 `2026-03-20`，本轮方案已收敛为：

1. 首个 provider 只做 `Codex`
2. `Codex` 改为优先消费本地 `Codex home` 下原始会话文件变化，当前兼容 `~/.codex_aicodewith/sessions/**/*.jsonl` 与 `~/.codex/sessions/**/*.jsonl`
3. 新增 `GenerationSessionCoordinator`，显式支持多 session 到单 active session 的仲裁
4. `web GPT / Gemini` 暂不走网络监听方案
5. 已落地 `TraceCodexProvider.swift` 与 `GenerationSessionCoordinator.swift` 两个最小实现文件
6. 已把 `Codex` generation snapshot 接入 `AppDelegate` 的注意力与跟随链路

## 11. Validation

1. 当前只完成静态实现，未运行 Xcode 编译。
2. 当前 `Codex` provider 主要依赖本地 `Codex home` 下 session jsonl 的 `mtime/size` 变化推断 `streaming / settling / inactive`；首次扫描到最近仍在写入的 session 时，也允许直接按 `mtime` 进入 `streaming` 或 `settling`，避免漏掉已在运行的会话。
3. 多 session 仲裁已在代码层显式支持，但真实体验仍需手动验证：
   - 同时开多个 Codex CLI / Desktop 会话
   - 切换前台 app 时 active session 是否符合预期
   - 终端输出关注点是否比单纯盯光标更自然

## 12. 当前结论

相比持续监控屏幕，`日志 / 事件 / 状态` 驱动的 adapter 方案更符合 `mimi` 想要的“像是知道你在等什么”的体验方向，也更可能把资源占用控制在可接受范围内；屏幕变化检测更适合作为降级补位，而不是主方案。
