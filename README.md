# mimi

`mimi` 是一个原生 macOS AppKit 桌宠原型。

它的目标不是做一个泛化跟随器，而是让桌宠更像一只会“监督你输入、围观大模型生成”的猫：

1. 你输入时，`mimi` 更偏向盯住文本输入位置
2. 大模型生成时，`mimi` 会切到“好奇等待”并看向生成区域
3. 当前优先接入 `Codex`，通过本地会话文件变化识别生成状态

## 当前能力

当前版本已经具备这些最小能力：

1. 原生透明、置顶、事件穿透的宠物窗口
2. 菜单栏入口与基础状态探针
3. 基于辅助功能的文本光标读取
4. 鼠标跟随 fallback
5. `Focus / Wait / Idle` 最小状态机
6. 基于 `Codex` 本地 session 文件的生成状态识别
7. 针对 `typing / streaming / settling / idle` 的轻量表情差异

## 当前聚焦方向

目前项目重点不是复杂动画，而是把两种体验做对：

1. 输入时像猫一样监督你打字
2. 生成时像猫一样好奇地看大模型输出

当前 `Codex` 监听优先兼容以下本地目录：

1. `~/.codex_aicodewith/sessions/**/*.jsonl`
2. `~/.codex/sessions/**/*.jsonl`

## 项目结构

主要目录：

1. `mimi/App`
   应用入口与主调度
2. `mimi/Character`
   角色绘制与表现
3. `mimi/Tracking`
   文本光标、鼠标与跟随目标
4. `mimi/Support`
   权限、屏幕变化、`Codex` provider、会话协调器
5. `mimi/Window`
   宠物窗口与坐标映射
6. `docs/spec`
   行为与实现 spec

## 运行方式

当前工程是原生 macOS AppKit 工程，使用 Xcode 打开：

1. 打开 [mimi.xcodeproj](/Users/wuyue/github_project/mimi/mimi.xcodeproj)
2. 选择 `mimi` target / scheme
3. 直接运行

## 权限说明

为了获得更自然的跟随效果，建议授予：

1. 辅助功能权限
   用于读取文本光标位置
2. 屏幕录制权限
   用于等待态下的局部屏幕变化辅助检测

未授予权限时，应用仍可运行，但会退化到更弱的跟随链路。

## 文档

重要文档：

1. [mimi_prd.md](/Users/wuyue/github_project/mimi/mimi_prd.md)
2. [mimi_mvp_spec.md](/Users/wuyue/github_project/mimi/mimi_mvp_spec.md)
3. [mimi_attention_behavior_spec.md](/Users/wuyue/github_project/mimi/docs/spec/mimi_attention_behavior_spec.md)
4. [mimi_generation_signal_adapter_spec.md](/Users/wuyue/github_project/mimi/docs/spec/mimi_generation_signal_adapter_spec.md)
5. [mimi_acceptance_checklist.md](/Users/wuyue/github_project/mimi/mimi_acceptance_checklist.md)

## 当前状态

当前仓库还处于原型阶段：

1. 行为与 spec 已持续收敛
2. `Codex` 生成监听已打通
3. 角色表现仍在持续调整
4. 尚未做完整的工程级打包、发布与稳定性收敛
