import AppKit
import ApplicationServices

struct TextCursorSnapshot {
    let rect: CGRect
    let appName: String?
    let elementRole: String?
    let selectedRange: CFRange
    let caretRange: CFRange

    var debugSummary: String {
        let appLine = "应用：\(appName ?? "未知")"
        let roleLine = "元素角色：\(elementRole ?? "未知")"
        let rangeLine = "选区：location=\(selectedRange.location), length=\(selectedRange.length)"
        let caretLine = "插入点范围：location=\(caretRange.location), length=\(caretRange.length)"
        let rectLine = String(
            format: "全局坐标：x=%.1f, y=%.1f, width=%.1f, height=%.1f",
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height
        )
        return [appLine, roleLine, rangeLine, caretLine, rectLine].joined(separator: "\n")
    }
}

enum TextCursorProbeError: Error {
    case permissionDenied
    case focusedElementUnavailable(AXError)
    case focusedElementTypeMismatch
    case selectedTextRangeUnavailable(AXError)
    case selectedTextRangeTypeMismatch
    case boundsLookupUnsupported
    case boundsLookupFailed(AXError)
    case boundsValueTypeMismatch
}

extension TextCursorProbeError {
    var messageText: String {
        switch self {
        case .permissionDenied:
            return "未获得辅助功能权限"
        case .focusedElementUnavailable:
            return "无法读取当前焦点元素"
        case .focusedElementTypeMismatch:
            return "焦点元素类型异常"
        case .selectedTextRangeUnavailable:
            return "无法读取当前选区"
        case .selectedTextRangeTypeMismatch:
            return "选区数据类型异常"
        case .boundsLookupUnsupported:
            return "当前应用不支持按范围读取文本光标 bounds"
        case .boundsLookupFailed:
            return "读取文本光标 bounds 失败"
        case .boundsValueTypeMismatch:
            return "文本光标 bounds 数据类型异常"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .permissionDenied:
            return "请先在“系统设置 -> 隐私与安全性 -> 辅助功能”中授权 mimi。"
        case .focusedElementUnavailable(let error):
            return "系统返回的错误是 \(error.rawValue)。请先把光标放进可编辑文本区域，再重试。"
        case .focusedElementTypeMismatch:
            return "当前焦点可能不在标准文本输入控件中。"
        case .selectedTextRangeUnavailable(let error):
            return "系统返回的错误是 \(error.rawValue)。当前焦点可能不支持文本选区属性。"
        case .selectedTextRangeTypeMismatch:
            return "当前应用返回了非标准的选区值，后续需要单独兼容。"
        case .boundsLookupUnsupported:
            return "这通常发生在部分 Electron 或自定义输入控件应用中，后续应走鼠标 fallback。"
        case .boundsLookupFailed(let error):
            return "系统返回的错误是 \(error.rawValue)。请在原生应用中再验证一次。"
        case .boundsValueTypeMismatch:
            return "当前应用返回了非 CGRect 的 bounds 值，后续需要单独兼容。"
        }
    }
}

final class AccessibilityCursorService {
    func captureFocusedTextCursor() -> Result<TextCursorSnapshot, TextCursorProbeError> {
        guard AXIsProcessTrusted() else {
            return .failure(.permissionDenied)
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        let appName = focusedApplicationName(from: systemWideElement)

        var focusedElementRef: CFTypeRef?
        let focusedElementError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusedElementError == .success, let focusedElementRef else {
            return .failure(.focusedElementUnavailable(focusedElementError))
        }

        guard CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else {
            return .failure(.focusedElementTypeMismatch)
        }

        let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)
        let elementRole = attributeString(kAXRoleAttribute, on: focusedElement)

        var selectedTextRangeRef: CFTypeRef?
        let selectedTextRangeError = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedTextRangeRef
        )

        guard selectedTextRangeError == .success, let selectedTextRangeRef else {
            return .failure(.selectedTextRangeUnavailable(selectedTextRangeError))
        }

        guard CFGetTypeID(selectedTextRangeRef) == AXValueGetTypeID() else {
            return .failure(.selectedTextRangeTypeMismatch)
        }

        let selectedTextRangeValue = unsafeBitCast(selectedTextRangeRef, to: AXValue.self)
        guard AXValueGetType(selectedTextRangeValue) == .cfRange else {
            return .failure(.selectedTextRangeTypeMismatch)
        }

        var selectedRange = CFRange()
        AXValueGetValue(selectedTextRangeValue, .cfRange, &selectedRange)

        var caretRange = CFRange(location: selectedRange.location + selectedRange.length, length: 0)
        guard let caretRangeValue = AXValueCreate(.cfRange, &caretRange) else {
            return .failure(.selectedTextRangeTypeMismatch)
        }

        var boundsRef: CFTypeRef?
        let boundsError = AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            caretRangeValue,
            &boundsRef
        )

        if boundsError == .parameterizedAttributeUnsupported || boundsError == .attributeUnsupported {
            return .failure(.boundsLookupUnsupported)
        }

        guard boundsError == .success, let boundsRef else {
            return .failure(.boundsLookupFailed(boundsError))
        }

        guard CFGetTypeID(boundsRef) == AXValueGetTypeID() else {
            return .failure(.boundsValueTypeMismatch)
        }

        let boundsValue = unsafeBitCast(boundsRef, to: AXValue.self)
        guard AXValueGetType(boundsValue) == .cgRect else {
            return .failure(.boundsValueTypeMismatch)
        }

        var rect = CGRect.zero
        AXValueGetValue(boundsValue, .cgRect, &rect)

        return .success(
            TextCursorSnapshot(
                rect: rect,
                appName: appName,
                elementRole: elementRole,
                selectedRange: selectedRange,
                caretRange: caretRange
            )
        )
    }

    private func focusedApplicationName(from systemWideElement: AXUIElement) -> String? {
        var focusedAppRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppRef
        )

        guard error == .success, let focusedAppRef else {
            return nil
        }

        guard CFGetTypeID(focusedAppRef) == AXUIElementGetTypeID() else {
            return nil
        }

        let applicationElement = unsafeBitCast(focusedAppRef, to: AXUIElement.self)
        var pid: pid_t = 0
        guard AXUIElementGetPid(applicationElement, &pid) == .success else {
            return nil
        }

        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    private func attributeString(_ key: String, on element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, key as CFString, &valueRef)
        guard error == .success else {
            return nil
        }

        return valueRef as? String
    }
}
