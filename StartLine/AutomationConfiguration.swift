//
//  AutomationConfiguration.swift
//  StartLine
//
//  Automationビルドでのみ、カウントダウン時間を起動引数から上書きする。
//  Releaseビルドでは引数の解析コード自体をコンパイルしない。
//

import Foundation

struct CountdownDurationOverrides {
    var scheduledSeconds: TimeInterval?
    var pomodoroSeconds: TimeInterval?
    var breakSeconds: TimeInterval?

    static let disabled = CountdownDurationOverrides()

    func duration(for type: CountdownType, productionMinutes: Int? = nil) -> TimeInterval? {
        switch type {
        case .scheduled:
            scheduledSeconds
        case .pomodoro:
            pomodoroSeconds ?? productionMinutes.map { TimeInterval($0 * 60) }
        case .breakTime:
            breakSeconds ?? productionMinutes.map { TimeInterval($0 * 60) }
        }
    }
}

enum StartLineAutomation {
    static var countdownDurations: CountdownDurationOverrides {
#if STARTLINE_AUTOMATION
        let arguments = ProcessInfo.processInfo.arguments

        return CountdownDurationOverrides(
            scheduledSeconds: seconds(after: "-startline-scheduled-seconds", in: arguments),
            pomodoroSeconds: seconds(after: "-startline-pomodoro-seconds", in: arguments),
            breakSeconds: seconds(after: "-startline-break-seconds", in: arguments)
        )
#else
        return .disabled
#endif
    }

#if STARTLINE_AUTOMATION
    private static func seconds(after option: String, in arguments: [String]) -> TimeInterval? {
        guard
            let optionIndex = arguments.firstIndex(of: option),
            arguments.indices.contains(optionIndex + 1),
            let seconds = TimeInterval(arguments[optionIndex + 1]),
            seconds >= 1,
            seconds <= 3_600
        else {
            return nil
        }

        return seconds
    }
#endif
}
