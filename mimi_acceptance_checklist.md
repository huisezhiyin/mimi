# mimi MVP 验收清单

## 1. 文档定位

本文档用于执行 `mimi` MVP 的手动验收，覆盖以下目标：

- 对照 [mimi_prd.md](/Users/wuyue/github_project/mimi/mimi_prd.md) 的 MVP 验收标准逐项检查
- 对照 [mimi_mvp_spec.md](/Users/wuyue/github_project/mimi/mimi_mvp_spec.md) 的 `CP1` 到 `CP10` 当前实现口径做人工验证
- 区分“已实现但未验证”和“尚未实现 / 尚未收敛”的项目，避免误判完成度

## 2. 当前状态说明

截至 `2026-03-20`，仓库内已完成 `CP1` 到 `CP9` 的代码与文档落地，并已补齐 `CP10` 的验收文档，但以下事实仍然成立：

1. 当前环境未运行编译、未启动应用、未执行真机手动验收。
2. 当前环境仅完成了 `Info.plist` 和 `project.pbxproj` 的静态语法检查。
3. 性能验收、跨应用兼容性验收、多屏验收均尚未执行。

因此，下面清单中的状态默认分为三类：

- `待验证`：代码已落地，但尚未完成运行时确认
- `待实现`：spec 中有要求，但当前还没有做到完整产品化
- `不在 MVP`：明确不纳入本轮

## 3. 验收前准备

### 3.1 运行前条件

1. 本机安装完整 Xcode，而非仅 Command Line Tools。
2. 能在 Xcode 中打开 [project.pbxproj](/Users/wuyue/github_project/mimi/mimi.xcodeproj/project.pbxproj)。
3. 系统版本满足工程配置要求的 macOS 版本。
4. 准备至少以下验证应用：
   - 备忘录
   - Xcode
   - 一个 Electron 应用或非标准输入应用
5. 若要验证“等待生成时看屏幕变化”，需额外授予屏幕录制权限。

### 3.2 验收建议顺序

1. 启动工程并确认菜单栏应用能运行
2. 验证窗口展示与事件穿透
3. 验证权限引导
4. 验证文本光标读取
5. 验证鼠标 fallback
6. 验证本地坐标映射
7. 验证状态机
8. 验证最小视线表现
9. 最后做性能与兼容性观察

## 4. 功能验收清单

### 4.1 工程可运行

- 状态：`待验证`
- 验收步骤：
  1. 用 Xcode 打开工程。
  2. 选择 `mimi` target 运行。
  3. 确认应用以菜单栏形态启动。
- 通过标准：
  1. 应用可启动。
  2. 菜单栏出现 `mimi` 图标或标题。
  3. 无明显启动崩溃。

### 4.2 透明窗口与事件穿透

- 状态：`待验证`
- 对应实现：
  - [PetWindow.swift](/Users/wuyue/github_project/mimi/mimi/Window/PetWindow.swift)
  - [PetWindowController.swift](/Users/wuyue/github_project/mimi/mimi/Window/PetWindowController.swift)
- 验收步骤：
  1. 启动应用后确认桌面右下区域出现宠物窗口。
  2. 将宠物覆盖到编辑器或浏览器界面附近。
  3. 在宠物覆盖区域直接点击底层应用。
- 通过标准：
  1. 窗口无边框、透明、置顶。
  2. 不抢键盘焦点。
  3. 点击可透传到底层窗口。

### 4.3 权限引导

- 状态：`待验证`
- 对应实现：
  - [AccessibilityPermissionService.swift](/Users/wuyue/github_project/mimi/mimi/Support/AccessibilityPermissionService.swift)
  - [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)
- 验收步骤：
  1. 在未授权辅助功能权限时首次启动应用。
  2. 观察是否弹出引导提示。
  3. 在菜单栏中点击“请求辅助功能权限”与“打开辅助功能设置”。
- 通过标准：
  1. 用户明确知道未授权会影响文本光标追踪。
  2. 能通过菜单栏或弹窗跳转系统设置。
  3. 授权后可通过刷新状态看到已授权结果。

### 4.4 文本光标读取 PoC

- 状态：`待验证`
- 对应实现：
  - [AccessibilityCursorService.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/AccessibilityCursorService.swift)
- 验收步骤：
  1. 在备忘录中聚焦一个可编辑文本区域。
  2. 从菜单栏点击“读取当前文本光标”。
  3. 记录弹窗中的应用名、角色、选区与全局坐标。
  4. 在 Xcode 中重复一次。
- 通过标准：
  1. 至少两个原生应用可返回有效文本光标坐标。
  2. 失败场景能返回明确失败原因，而不是空白或崩溃。

### 4.5 鼠标 fallback

- 状态：`待验证`
- 对应实现：
  - [MouseTrackingService.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/MouseTrackingService.swift)
  - [TrackingTarget.swift](/Users/wuyue/github_project/mimi/mimi/Tracking/TrackingTarget.swift)
- 验收步骤：
  1. 进入一个不支持文本光标 bounds 的应用。
  2. 移动鼠标后点击菜单栏“读取当前跟随目标”。
  3. 查看弹窗是否显示 `鼠标 fallback`。
- 通过标准：
  1. 光标失败时自动退到鼠标。
  2. 弹窗能显示 fallback 原因和鼠标全局坐标。

### 4.6 本地坐标映射

- 状态：`待验证`
- 对应实现：
  - [WindowCoordinateMapper.swift](/Users/wuyue/github_project/mimi/mimi/Support/WindowCoordinateMapper.swift)
- 验收步骤：
  1. 将鼠标移动到宠物窗口不同位置附近。
  2. 点击菜单栏“读取当前本地坐标”。
  3. 观察弹窗中的全局坐标、窗口坐标、视图坐标。
  4. 观察宠物窗口内是否出现映射点标记。
- 通过标准：
  1. 映射点位置与预期方向一致。
  2. 坐标不会明显镜像、反向或大偏移。

### 4.7 状态机

- 状态：`待验证`
- 对应实现：
  - [ActivityMonitorService.swift](/Users/wuyue/github_project/mimi/mimi/Support/ActivityMonitorService.swift)
  - [CompanionStateMachine.swift](/Users/wuyue/github_project/mimi/mimi/State/CompanionStateMachine.swift)
- 验收步骤：
  1. 连续输入键盘或快速移动鼠标，观察状态 badge。
  2. 停止操作约 3 到 10 秒，观察是否进入 `Wait`。
  3. 停止操作超过 10 秒，观察是否进入 `Idle`。
  4. 通过菜单栏“读取当前状态”查看判定原因。
- 通过标准：
  1. 三态可观察。
  2. 阈值切换基本符合 spec。
  3. 不出现明显抖动。

### 4.8 最小视线表现

- 状态：`待验证`
- 对应实现：
  - [PetView.swift](/Users/wuyue/github_project/mimi/mimi/Character/PetView.swift)
- 验收步骤：
  1. 先执行“读取当前本地坐标”。
  2. 观察猫眼瞳孔是否向映射点方向偏移。
  3. 在窗口不同区域重复。
- 通过标准：
  1. 瞳孔朝向变化可见。
  2. 左右眼方向一致，不出现明显错位。

### 4.9 等待生成关注行为

- 状态：`待验证`
- 对应实现：
  - [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)
  - [ScreenCapturePermissionService.swift](/Users/wuyue/github_project/mimi/mimi/Support/ScreenCapturePermissionService.swift)
  - [ScreenChangeMonitorService.swift](/Users/wuyue/github_project/mimi/mimi/Support/ScreenChangeMonitorService.swift)
- 验收步骤：
  1. 在菜单栏中确认屏幕录制权限已授权。
  2. 在 ChatGPT、Claude 或 Cursor 中输入一段文本后停止输入。
  3. 观察 3 到 10 秒内，角色是否继续盯住最近输入区域附近。
  4. 若页面回复区域持续出现文本变化，观察角色是否转而看向变化热点。
- 通过标准：
  1. 停止输入后不会立刻跳回鼠标。
  2. 有局部变化时，视线会出现“好奇看生成”的转移。
  3. 未授权屏幕录制权限时，仍会保留“盯最近输入区域”的降级行为。

### 4.10 Codex 生成信号与多会话仲裁

- 状态：`待验证`
- 对应实现：
  - [TraceCodexProvider.swift](/Users/wuyue/github_project/mimi/mimi/Support/TraceCodexProvider.swift)
  - [GenerationSessionCoordinator.swift](/Users/wuyue/github_project/mimi/mimi/Support/GenerationSessionCoordinator.swift)
  - [AppDelegate.swift](/Users/wuyue/github_project/mimi/mimi/App/AppDelegate.swift)
- 验收步骤：
  1. 确认本机存在正在追加的 `~/.codex_aicodewith/sessions/**/*.jsonl` 或 `~/.codex/sessions/**/*.jsonl` 会话文件。
  2. 启动一个 Codex 会话并让其持续输出。
  3. 观察角色是否进入“Codex 正在生成”或“Codex 主会话生成”。
  4. 再启动第二个 Codex 会话，观察角色是否仍只盯一个主会话。
  5. 切换前台终端 / Codex Desktop，再观察主会话是否随之切换。
- 通过标准：
  1. 单个 Codex 会话生成时，角色能稳定进入等待关注态。
  2. 多个 Codex 会话并存时，角色不会来回抖动到多个目标。
  3. 前台 app 变化后，主会话选择基本符合用户直觉。

## 5. 体验验收清单

### 5.1 无打扰体验

- 状态：`待验证`
- 检查点：
  1. 不拦截底层点击
  2. 不抢焦点
  3. 菜单栏入口足够完成基本管理

### 5.2 行为可理解性

- 状态：`待验证`
- 检查点：
  1. 用户能理解 `Focus / Wait / Idle` 的变化
  2. 用户能理解“文本光标优先，鼠标兜底”的行为
  3. 视线变化不过度突兀

## 6. 性能验收清单

### 6.1 当前状态

- 状态：`待验证`
- 原因：
  1. 当前尚未运行应用
  2. 尚未接入任何性能采样数据

### 6.2 建议验证方式

1. 运行应用后使用 Activity Monitor 观察 CPU 与内存。
2. 分别在静置、频繁移动鼠标、频繁输入三种场景下观察资源占用。
3. 长时间放置 10 分钟以上，观察是否出现异常发热或 CPU 抖动。

### 6.3 目标口径

1. 常驻 CPU 接近 PRD 要求的 `1-2%`。
2. 不出现明显风扇噪音与发热异常。
3. 长时间驻留不出现持续增长的资源占用。

## 7. 残留风险

1. 当前未实测完整 Xcode 工程能否直接编译通过。
2. 文本光标获取在 Electron / 自定义输入控件中的失败率仍需真实验证。
3. 多显示器坐标转换尚未经过真机多屏布局验证。
4. 当前状态机是最小规则版本，阈值后续大概率需要根据真实体验再调整。
5. 角色表现当前只做到瞳孔偏移，头部跟随和更自然的动作尚未接入。

## 8. 建议的验收输出

建议验收完成后，至少补充以下记录：

1. 哪些应用成功返回文本光标坐标
2. 哪些应用触发了鼠标 fallback
3. 多屏场景是否存在方向或偏移问题
4. `Focus / Wait / Idle` 的阈值是否需要调参
5. 常驻 CPU 与内存的大致范围
