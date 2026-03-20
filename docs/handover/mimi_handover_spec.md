# Spec: mimi 任务交接与后续改进指引

## 1. 文档目的

本文档用于给后续接手 `mimi` 项目的大模型或开发者提供高密度上下文，减少重复探索成本。

阅读目标：

1. 快速理解这个项目的产品目标与当前 MVP 边界
2. 快速理解本轮任务已经完成了什么
3. 知道当前代码的真实运行状态，而不是只看文档想当然
4. 知道下一步最值得优先推进的改进方向

## 2. 项目定位

- 项目名：`mimi`
- 类型：macOS 桌面陪伴工具
- 技术栈：`Swift + AppKit`
- 目标：在用户等待 LLM 输出时，提供不打扰工作流的桌面宠物陪伴

当前 MVP 关注 4 件事：

1. 显示一个透明、置顶、事件穿透的宠物窗口
2. 优先跟随文本光标，失败时回退到鼠标
3. 具备 `Focus / Wait / Idle` 的最小状态感知
4. 提供菜单栏入口和辅助功能权限引导

## 3. 本轮任务完成内容

本轮已经完成从 `CP1` 到 `CP10` 的“实现 + 文档收口”，但注意：

- `CP1` 到 `CP9` 主要是代码实现
- `CP10` 当前完成的是验收材料准备，不是最终运行验收全部完成

### 3.1 已完成的工程与功能

1. 创建了可打开的原生 AppKit 工程：
   - [project.pbxproj](/Users/wuyue/github_project/mimi/mimi.xcodeproj/project.pbxproj)
2. 建立了菜单栏形态的应用入口：
   - [main.swift](/Users/wuyue/github_project/mimi/mimi/App/main.swift)
   - [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)
3. 完成了透明、置顶、事件穿透宠物窗口：
   - [PetWindow.swift](/Users/wuyue/github_project/mimi/mimi/Window/PetWindow.swift)
   - [PetWindowController.swift](/Users/wuyue/github_project/mimi/mimi/Window/PetWindowController.swift)
4. 完成了辅助功能权限检测与跳转：
   - [AccessibilityPermissionService.swift](/Users/wuyue/github_project/mimi/mimi/Support/AccessibilityPermissionService.swift)
5. 完成了文本光标读取 PoC：
   - [AccessibilityCursorService.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/AccessibilityCursorService.swift)
6. 完成了鼠标 fallback 与统一目标抽象：
   - [MouseTrackingService.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/MouseTrackingService.swift)
   - [TrackingTarget.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/TrackingTarget.swift)
7. 完成了全局坐标到宠物窗口本地坐标的映射：
   - [WindowCoordinateMapper.swift](/Users/wuyue/github_project/mimi/mimi/Support/WindowCoordinateMapper.swift)
8. 完成了最小活动监控与状态机：
   - [ActivityMonitorService.swift](/Users/wuyue/github_project/mimi/mimi/Support/ActivityMonitorService.swift)
   - [CompanionStateMachine.swift](/Users/wuyue/github_project/mimi/mimi/State/CompanionStateMachine.swift)
9. 完成了最小角色表现：
   - [PetView.swift](/Users/wuyue/github_project/mimi/mimi/Character/PetView.swift)
10. 已把手动验收清单文档补齐：
   - [mimi_acceptance_checklist.md](/Users/wuyue/github_project/mimi/mimi_acceptance_checklist.md)

### 3.2 已修过的关键坑

1. 修过工程文件路径错误。
   - 最初 `pbxproj` 指向了仓库根目录下不存在的 `App/...`、`Window/...`
   - 当前已经改成真实路径 `mimi/App/...`、`mimi/Window/...`
2. 修过 `NSRunningApplication` 的 API 使用。
   - 以本机实际编译器反馈为准，当前使用：
   - `NSRunningApplication(processIdentifier: pid)?.localizedName`
3. 当前工程至少已经被用户在本机成功跑起一次。
   - 这是重要事实，说明工程已不再停留在“仅静态生成”

## 4. 当前真实运行状态

后续模型必须以这里为准，不要重复误判。

### 4.1 当前已经能做的事

1. 工程可在用户本机打开并成功运行
2. 应用以菜单栏工具形态存在
3. 宠物窗口可显示
4. 菜单栏可触发：
   - 权限状态刷新
   - 请求辅助功能权限
   - 打开辅助功能设置
   - 读取当前文本光标
   - 读取当前跟随目标
   - 读取当前本地坐标
   - 读取当前状态
5. 角色已经接上“连续跟随”最小链路：
   - 有一个轻量定时器持续刷新目标点
   - 文本光标优先
   - 失败时回退到鼠标
   - 将全局坐标映射到本地视图
   - 根据本地目标点调整瞳孔方向

### 4.2 当前还不够好的地方

1. 用户虽然反馈“成功了”，但之前观察到“好像不会盯着输入框/鼠标”
2. 已经补上连续刷新链路，但尚未再次拿到用户确认说“现在跟随正常”
3. 因此，后续模型要优先验证的不是“能不能启动”，而是：
   - 跟随是否足够明显
   - 文本光标是否真的优先于鼠标
   - 某些应用中是否总是退回鼠标 fallback

## 5. 当前核心行为链路

后续模型应优先理解这条链路，而不是重新发明结构。

### 5.1 应用启动链路

入口：
- [main.swift](/Users/wuyue/github_project/mimi/mimi/App/main.swift)

主初始化：
- [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)

启动时会做这些事：

1. 初始化菜单栏控制器
2. 初始化宠物窗口控制器
3. 启动鼠标监听
4. 启动活动监控
5. 显示宠物窗口
6. 启动状态刷新 timer
7. 启动跟随刷新 timer
8. 刷新权限状态

### 5.2 连续跟随链路

核心位置：
- [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)

关键方法：

1. `startTrackingRefreshTimer()`
2. `resolveTrackingTarget()`
3. `refreshTrackingVisuals()`

当前逻辑是：

1. 定时器以轻量频率刷新
2. 每轮先尝试 `captureFocusedTextCursor()`
3. 成功则使用 `.cursor`
4. 失败则使用鼠标快照构造 `.mouse`
5. 将 `TrackingTarget.globalPoint` 映射为宠物视图本地点
6. 把本地点写入 `mappedTargetPoint`
7. `PetView` 根据 `mappedTargetPoint` 计算瞳孔偏移

### 5.3 状态机链路

核心位置：

- [ActivityMonitorService.swift](/Users/wuyue/github_project/mimi/mimi/Support/ActivityMonitorService.swift)
- [CompanionStateMachine.swift](/Users/wuyue/github_project/mimi/mimi/State/CompanionStateMachine.swift)

当前逻辑：

1. 全局监听键盘与鼠标活动
2. 记录最近输入、最近鼠标活动和鼠标位移
3. 每 0.5 秒刷新一次状态
4. 按阈值切到：
   - `Focus`
   - `Wait`
   - `Idle`

当前只把状态显示成文字 badge，还没有更完整动作包。

## 6. 当前文件地图

### 6.1 应用与生命周期

- [main.swift](/Users/wuyue/github_project/mimi/mimi/App/main.swift)
- [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)

### 6.2 菜单栏

- [MenuBarController.swift](/Users/wuyue/github_project/mimi/mimi/MenuBar/MenuBarController.swift)

### 6.3 窗口与视图

- [PetWindow.swift](/Users/wuyue/github_project/mimi/mimi/Window/PetWindow.swift)
- [PetWindowController.swift](/Users/wuyue/github_project/mimi/mimi/Window/PetWindowController.swift)
- [PetView.swift](/Users/wuyue/github_project/mimi/mimi/Character/PetView.swift)

### 6.4 跟随能力

- [AccessibilityCursorService.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/AccessibilityCursorService.swift)
- [MouseTrackingService.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/MouseTrackingService.swift)
- [TrackingTarget.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/TrackingTarget.swift)
- [WindowCoordinateMapper.swift](/Users/wuyue/github_project/mimi/mimi/Support/WindowCoordinateMapper.swift)

### 6.5 状态机

- [ActivityMonitorService.swift](/Users/wuyue/github_project/mimi/mimi/Support/ActivityMonitorService.swift)
- [CompanionStateMachine.swift](/Users/wuyue/github_project/mimi/mimi/State/CompanionStateMachine.swift)

### 6.6 权限与配置

- [AccessibilityPermissionService.swift](/Users/wuyue/github_project/mimi/mimi/Support/AccessibilityPermissionService.swift)
- [Info.plist](/Users/wuyue/github_project/mimi/mimi/Info.plist)

## 7. 后续模型最应该优先做的事

按价值排序，不要平均用力。

### 优先级 P0：确认连续跟随实际是否工作

这是当前最重要问题。

应优先确认：

1. 瞳孔是否会持续跟随鼠标
2. 在备忘录 / Xcode 中是否会优先跟随文本光标
3. 是否只是跟随太弱、不明显，而不是链路没生效
4. 是否因为坐标映射方向不对，导致“看起来没跟上”

如果用户继续反馈“看起来不跟”，优先检查：

1. `refreshTrackingVisuals()` 是否持续调用
2. `resolveTrackingTarget()` 是否总在返回 `.mouse`
3. `mappedTargetPoint` 是否频繁更新
4. 瞳孔偏移量是否过小，视觉上不明显

### 优先级 P1：提升跟随可见性

如果链路已经通，但用户仍然感觉“不跟”，下一步应优先做：

1. 增大瞳孔偏移幅度
2. 给当前目标点增加更明显的视觉反馈开关
3. 在 debug 模式下显示当前目标来源：
   - 文本光标
   - 鼠标 fallback
4. 让 `trackingStatusText` 更清楚反映当前来源

### 优先级 P2：让状态机更像宠物而不是 badge

当前状态机已有，但表现层较弱。后续可做：

1. `Focus` 时耳朵更立，眼睛更聚焦
2. `Wait` 时减少瞳孔偏移，增加轻微松弛姿态
3. `Idle` 时闭眼、呼吸、停止主动跟随

### 优先级 P3：收敛性能

当前连续跟随使用 timer，后续如果要打磨：

1. 观察 CPU 是否明显超出 PRD 目标
2. 降低不必要的刷新频率
3. 只在目标变化较大时刷新视图

## 8. 不要重复踩的坑

1. 不要再把 `pbxproj` 的源码路径写回仓库根目录。
   - 正确路径前缀是 `mimi/...`
2. 不要忽略用户本机编译器报错。
   - 某些 AppKit API 的 Swift overlay 形式要以用户机器实际编译器为准
3. 不要误以为“菜单栏手动验证功能存在”就等于“连续跟随已经用户确认正常”
4. 不要在没有必要的情况下，直接把项目扩展成复杂动画系统
5. 当前项目明确要求：
   - 小步修改
   - 最小改动集
   - 先收敛问题，再扩需求

## 9. 推荐的后续阅读顺序

后续大模型建议按这个顺序读文件：

1. [mimi_handover_spec.md](/Users/wuyue/github_project/mimi/docs/handover/mimi_handover_spec.md)
2. [mimi_mvp_spec.md](/Users/wuyue/github_project/mimi/mimi_mvp_spec.md)
3. [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)
4. [AccessibilityCursorService.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/AccessibilityCursorService.swift)
5. [TrackingTarget.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/TrackingTarget.swift)
6. [WindowCoordinateMapper.swift](/Users/wuyue/github_project/mimi/mimi/Support/WindowCoordinateMapper.swift)
7. [PetView.swift](/Users/wuyue/github_project/mimi/mimi/Character/PetView.swift)
8. [mimi_acceptance_checklist.md](/Users/wuyue/github_project/mimi/mimi_acceptance_checklist.md)

## 10. 当前一句话结论

`mimi` 现在已经不是“只有文档和骨架”的状态，而是一个已经能运行、具备菜单栏、权限、文本光标 PoC、鼠标 fallback、坐标映射、最小状态机和最小连续瞳孔跟随能力的 macOS AppKit MVP；当前最值得后续模型优先处理的问题，是确认并增强“连续跟随是否足够明显且文本光标优先是否真的生效”。 
