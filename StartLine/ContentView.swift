//
//  ContentView.swift
//  StartLine
//

import SwiftUI
import Foundation

private enum StartLineLayout {
    static let ringLineWidth: CGFloat = 20
    static let statusToRingSpacing: CGFloat = 18
    static let controlButtonMinWidth: CGFloat = 104
    static let controlButtonVerticalPadding: CGFloat = 8
    static let controlButtonHorizontalPadding: CGFloat = 16
    static let actionButtonBackground = Color(red: 0.055, green: 0.062, blue: 0.070)
    static let editModeRingColor = Color(red: 0.000, green: 0.390, blue: 0.660)
    static let focusButtonForeground = Color(red: 0.000, green: 0.620, blue: 0.640)
    static let editButtonForeground = Color(red: 0.000, green: 0.550, blue: 0.950)
    static let pomodoroColor = Color(red: 0.78, green: 0.48, blue: 0.16)
    static let pomodoroButtonBackground = Color(red: 0.24, green: 0.13, blue: 0.035)
    static let pomodoroButtonBorder = Color(red: 0.78, green: 0.48, blue: 0.16)
    static let pomodoroSelectedBorder = Color(red: 0.96, green: 0.68, blue: 0.30)
    static let breakColor = Color(red: 0.70, green: 0.43, blue: 0.22)
    static let actionButtonBorderWidth: CGFloat = 1.6
}

private enum EditMode {
    case scheduled
    case pomodoroSetup
}

enum CountdownType {
    case scheduled
    case pomodoro
    case breakTime
}

enum ScheduledRingPhase: String {
    case normal
    case warning
    case imminent

    init(remainingSeconds: Int) {
        if remainingSeconds < 10 {
            self = .imminent
        } else if remainingSeconds < 60 {
            self = .warning
        } else {
            self = .normal
        }
    }
}

private struct ActiveCountdown {
    let type: CountdownType
    let startedAt: Date
    let targetDate: Date
}

struct ContentView: View {
    private let countdownDurationOverrides = StartLineAutomation.countdownDurations

    @StateObject private var tipJarStore = TipJarStore()
    @State private var targetDate = StartSchedule.make(now: Date()).suggested.date
    @State private var countdownStartedAt = Date()
    @State private var editMode: EditMode = .scheduled
    @State private var activeCountdown: ActiveCountdown?
    @AppStorage("pomodoroDurationMinutes") private var pomodoroDurationMinutes = 25
    @State private var draftPomodoroMinutes = 25
    @State private var isShowingAppInfo = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let appInfoButtonY = appInfoButtonCenterY(
                    size: geometry.size,
                    isLandscape: isLandscape
                )
                let schedule = StartSchedule.make(now: timeline.date)
                let displayCandidate = schedule.candidate(matching: targetDate, calendar: .current)
                let isFocused = activeCountdown != nil
                let remainingSeconds = displayedRemainingSeconds(now: timeline.date)
                let remainingText = StartSchedule.remainingTimeText(remainingSeconds: remainingSeconds)
                let isTargetReached = timeline.date >= targetDate
                let selectedCandidateDate = editMode == .scheduled && !isTargetReached ? targetDate : nil
                let progress = displayedProgress(now: timeline.date)
                let ringColor = countdownRingColor(remainingSeconds: remainingSeconds)
                let ringSubtitle = displayedSubtitle(candidate: displayCandidate)
                let completedType = remainingSeconds == 0 ? activeCountdown?.type : nil
                Group {
                    if isLandscape {
                        LandscapeDisplayView(
                            schedule: schedule,
                            candidate: displayCandidate,
                            selectedDate: selectedCandidateDate,
                            availableSize: geometry.size,
                            remainingText: remainingText,
                            remainingSeconds: remainingSeconds,
                            countdownProgress: progress,
                            ringColor: ringColor,
                            isFocused: isFocused,
                            editMode: editMode,
                            pomodoroMinutes: draftPomodoroMinutes,
                            ringSubtitle: ringSubtitle,
                            completedType: completedType,
                            onSelect: { candidate in
                                editMode = .scheduled
                                targetDate = candidate.date
                                countdownStartedAt = timeline.date
                            },
                            onSelectPomodoro: selectPomodoroSetup,
                            onPomodoroMinutesChanged: { draftPomodoroMinutes = $0 },
                            onPomodoroMinutesCommitted: commitPomodoroMinutes,
                            onFocus: { startSelectedCountdown(now: timeline.date) },
                            onStartNext: { startNextCountdown(after: completedType, now: timeline.date) },
                            onEdit: {
                                enterEditMode(
                                    now: timeline.date,
                                    schedule: schedule,
                                    isTargetReached: isTargetReached
                                )
                            }
                        )
                    } else {
                        PortraitStartView(
                            schedule: schedule,
                            selectedCandidate: displayCandidate,
                            selectedDate: selectedCandidateDate,
                            availableSize: geometry.size,
                            remainingText: remainingText,
                            remainingSeconds: remainingSeconds,
                            countdownProgress: progress,
                            ringColor: ringColor,
                            isFocused: isFocused,
                            editMode: editMode,
                            pomodoroMinutes: draftPomodoroMinutes,
                            ringSubtitle: ringSubtitle,
                            completedType: completedType,
                            onSelect: { candidate in
                                editMode = .scheduled
                                targetDate = candidate.date
                                countdownStartedAt = timeline.date
                            },
                            onSelectPomodoro: selectPomodoroSetup,
                            onPomodoroMinutesChanged: { draftPomodoroMinutes = $0 },
                            onPomodoroMinutesCommitted: commitPomodoroMinutes,
                            onFocus: { startSelectedCountdown(now: timeline.date) },
                            onStartNext: { startNextCountdown(after: completedType, now: timeline.date) },
                            onEdit: {
                                enterEditMode(
                                    now: timeline.date,
                                    schedule: schedule,
                                    isTargetReached: isTargetReached
                                )
                            }
                        )
                    }
                }
                .onAppear {
                    draftPomodoroMinutes = boundedPomodoroMinutes(pomodoroDurationMinutes)
                    advanceTargetIfNeeded(
                        now: timeline.date,
                        schedule: schedule,
                        isTargetReached: isTargetReached
                    )
                }
                .onChange(of: isTargetReached) { _, didReachTarget in
                    advanceTargetIfNeeded(
                        now: timeline.date,
                        schedule: schedule,
                        isTargetReached: didReachTarget
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color("AppBackground"))
                .overlay {
                    AppInfoButton {
                        isShowingAppInfo = true
                    }
                    .position(
                        x: geometry.size.width - 34,
                        y: appInfoButtonY
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingAppInfo) {
            AppInfoView(tipJarStore: tipJarStore)
        }
    }

    private func advanceTargetIfNeeded(
        now: Date,
        schedule: StartSchedule,
        isTargetReached: Bool
    ) {
        guard activeCountdown == nil, editMode == .scheduled, isTargetReached else {
            return
        }

        targetDate = schedule.suggested.date
        countdownStartedAt = now
    }

    private func enterEditMode(
        now: Date,
        schedule: StartSchedule,
        isTargetReached: Bool
    ) {
        let endedCountdownType = activeCountdown?.type
        activeCountdown = nil
        draftPomodoroMinutes = boundedPomodoroMinutes(pomodoroDurationMinutes)

        if endedCountdownType == .pomodoro {
            editMode = .pomodoroSetup
            return
        }

        editMode = .scheduled

        guard endedCountdownType != .scheduled || isTargetReached else {
            return
        }

        targetDate = schedule.suggested.date
        countdownStartedAt = now
    }

    private func selectPomodoroSetup() {
        editMode = .pomodoroSetup
        draftPomodoroMinutes = boundedPomodoroMinutes(pomodoroDurationMinutes)
    }

    private func commitPomodoroMinutes(_ minutes: Int) {
        let boundedMinutes = boundedPomodoroMinutes(minutes)
        draftPomodoroMinutes = boundedMinutes
        pomodoroDurationMinutes = boundedMinutes
    }

    private func boundedPomodoroMinutes(_ minutes: Int) -> Int {
        min(60, max(5, Int(round(Double(minutes) / 5.0)) * 5))
    }

    private func startSelectedCountdown(now: Date) {
        switch editMode {
        case .scheduled:
            let countdownTargetDate = countdownDurationOverrides.scheduledSeconds.map {
                now.addingTimeInterval($0)
            } ?? targetDate
            activeCountdown = ActiveCountdown(
                type: .scheduled,
                startedAt: now,
                targetDate: countdownTargetDate
            )
        case .pomodoroSetup:
            commitPomodoroMinutes(draftPomodoroMinutes)
            activeCountdown = durationCountdown(type: .pomodoro, minutes: draftPomodoroMinutes, now: now)
        }
    }

    private func startNextCountdown(after completedType: CountdownType?, now: Date) {
        switch completedType {
        case .pomodoro:
            activeCountdown = durationCountdown(type: .breakTime, minutes: 5, now: now)
        case .breakTime:
            activeCountdown = durationCountdown(
                type: .pomodoro,
                minutes: boundedPomodoroMinutes(pomodoroDurationMinutes),
                now: now
            )
        case .scheduled, .none:
            break
        }
    }

    private func durationCountdown(type: CountdownType, minutes: Int, now: Date) -> ActiveCountdown {
        let duration = countdownDurationOverrides.duration(for: type, productionMinutes: minutes)
            ?? TimeInterval(minutes * 60)
        return ActiveCountdown(
            type: type,
            startedAt: now,
            targetDate: now.addingTimeInterval(duration)
        )
    }

    private func displayedRemainingSeconds(now: Date) -> Int {
        if let activeCountdown {
            return StartSchedule.remainingSeconds(from: now, to: activeCountdown.targetDate)
        }

        switch editMode {
        case .scheduled:
            return StartSchedule.remainingSeconds(from: now, to: targetDate)
        case .pomodoroSetup:
            return draftPomodoroMinutes * 60
        }
    }

    private func displayedProgress(now: Date) -> Double {
        if let activeCountdown {
            switch activeCountdown.type {
            case .scheduled:
                return countdownProgress(
                    now: now,
                    targetDate: activeCountdown.targetDate,
                    startedAt: activeCountdown.startedAt
                )
            case .pomodoro, .breakTime:
                let remainingSeconds = activeCountdown.targetDate.timeIntervalSince(now)
                return min(1, max(0, remainingSeconds / (60 * 60)))
            }
        }

        switch editMode {
        case .scheduled:
            return countdownProgress(now: now, targetDate: targetDate, startedAt: countdownStartedAt)
        case .pomodoroSetup:
            return Double(draftPomodoroMinutes) / 60.0
        }
    }

    private func countdownProgress(now: Date, targetDate: Date, startedAt: Date) -> Double {
        let totalSeconds = targetDate.timeIntervalSince(startedAt)
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, targetDate.timeIntervalSince(now) / totalSeconds))
    }

    private func displayedSubtitle(candidate: StartCandidate) -> String {
        if let type = activeCountdown?.type {
            switch type {
            case .scheduled: return "To \(candidate.displayText)"
            case .pomodoro: return "Pomodoro"
            case .breakTime: return "Break"
            }
        }

        return editMode == .scheduled ? "To \(candidate.displayText)" : "Pomodoro"
    }

    private func appInfoButtonCenterY(size: CGSize, isLandscape: Bool) -> CGFloat {
        if isLandscape {
            return size.height * 0.105
        }

        let titleFontSize = size.width * 0.080
        let statusCenterY = size.height * 0.150
        let titleToStatusCenterDistance = max(size.height * 0.066, titleFontSize * 1.55)
        return statusCenterY - titleToStatusCenterDistance
    }

    private func countdownRingColor(remainingSeconds: Int) -> Color {
        if let type = activeCountdown?.type {
            switch type {
            case .pomodoro: return StartLineLayout.pomodoroColor
            case .breakTime: return StartLineLayout.breakColor
            case .scheduled: break
            }
        } else {
            return editMode == .pomodoroSetup
                ? StartLineLayout.pomodoroColor
                : StartLineLayout.editModeRingColor
        }

        switch ScheduledRingPhase(remainingSeconds: remainingSeconds) {
        case .normal:
            return Color(red: 0.00, green: 0.62, blue: 0.64)
        case .warning:
            return Color(red: 0.63, green: 0.52, blue: 1.0)
        case .imminent:
            return Color(red: 0.78, green: 0.08, blue: 0.30)
        }
    }

}

private struct AppInfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About StartLine")
    }
}

private struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tipJarStore: TipJarStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .firstTextBaseline) {
                    Text("StartLine")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("A quiet way to begin.")
                        .font(.title3.weight(.semibold))

                    Text("Choose a nearby start time or set a Pomodoro duration, then enter Focus when you want the ring to take the lead.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    AppInfoRow(title: "Edit Mode", detail: "Suggestions stay visible and the blue ring keeps counting. When it reaches 0s, StartLine moves to the next nearby start time.")
                    AppInfoRow(title: "To", detail: "Pick a start time in 5-minute order. Quarter and 10-Minute colors mark common starting rhythms.")
                    AppInfoRow(title: "Pomodoro", detail: "Select Pomodoro, drag around the ring to set a duration, then tap Focus. Completed focus and break intervals wait for you to start the next one.")
                    AppInfoRow(title: "Focus Mode", detail: "Tap Focus to hide setup controls and start the selected countdown. Every countdown stops at 0s.")
                    AppInfoRow(title: "Edit", detail: "Tap Edit to end the current countdown and return to scheduled suggestions. Your Pomodoro duration stays saved.")
                    AppInfoRow(title: "Silent by Design", detail: "No alarms, no noise. Just a visual cue for a calm, deliberate start.")
                }

                TipJarSection(store: tipJarStore)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .padding(.bottom, 36)
        }
        .background(Color(.systemBackground))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await tipJarStore.loadProduct()
        }
    }
}

private struct TipJarSection: View {
    @ObservedObject var store: TipJarStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support StartLine")
                .font(.headline)

            Text("If StartLine has been useful, you can leave a small, optional tip. It doesn’t unlock features.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            purchaseControl

            if let statusMessage = store.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(store.purchaseState == .failed ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tip.status")
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var purchaseControl: some View {
        if store.isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading Small Coffee…")
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("tip.loading")
        } else if let title = store.purchaseButtonTitle {
            Button {
                Task {
                    await store.purchase()
                }
            } label: {
                HStack(spacing: 10) {
                    if store.purchaseState == .purchasing {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(store.purchaseState == .purchasing ? "Processing…" : title)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 18)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(store.purchaseState == .purchasing)
            .accessibilityIdentifier("tip.purchase")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Small Coffee is temporarily unavailable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Try Again") {
                    Task {
                        await store.loadProduct(forceReload: true)
                    }
                }
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("tip.retry")
            }
        }
    }
}

private struct AppInfoRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PortraitStartView: View {
    let schedule: StartSchedule
    let selectedCandidate: StartCandidate
    let selectedDate: Date?
    let availableSize: CGSize
    let remainingText: String
    let remainingSeconds: Int
    let countdownProgress: Double
    let ringColor: Color
    let isFocused: Bool
    let editMode: EditMode
    let pomodoroMinutes: Int
    let ringSubtitle: String
    let completedType: CountdownType?
    let onSelect: (StartCandidate) -> Void
    let onSelectPomodoro: () -> Void
    let onPomodoroMinutesChanged: (Int) -> Void
    let onPomodoroMinutesCommitted: (Int) -> Void
    let onFocus: () -> Void
    let onStartNext: () -> Void
    let onEdit: () -> Void

    var body: some View {
        let metrics = PortraitLayoutMetrics(size: availableSize, isFocused: isFocused)

        ZStack {
            titleView(metrics: metrics)
                .frame(width: metrics.contentWidth)
                .position(x: metrics.centerX, y: metrics.titleCenterY)

            ringView(metrics: metrics)
                .position(x: metrics.centerX, y: metrics.ringCenterY)

            if !isFocused {
                StartCandidateListView(
                    schedule: schedule,
                    selectedDate: selectedDate,
                    metrics: metrics.candidateMetrics,
                    isPomodoroSelected: editMode == .pomodoroSetup,
                    onSelectPomodoro: onSelectPomodoro,
                    onSelect: onSelect
                )
                .frame(width: metrics.contentWidth)
                .position(x: metrics.centerX, y: metrics.candidateListCenterY)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if !isFocused {
                focusButton(metrics: metrics)
                    .position(x: metrics.centerX, y: metrics.focusButtonCenterY)
            } else {
                if completedType == .pomodoro || completedType == .breakTime {
                    nextCountdownButton(metrics: metrics)
                        .position(x: metrics.centerX, y: metrics.completionButtonCenterY)
                }

                editButton(metrics: metrics)
                    .position(x: metrics.centerX, y: metrics.controlButtonCenterY)
            }
        }
        .frame(width: availableSize.width, height: availableSize.height)
        .animation(.easeInOut(duration: 0.24), value: isFocused)
    }

    private func titleView(metrics: PortraitLayoutMetrics) -> some View {
        Text("StartLine")
            .font(.system(size: metrics.titleFontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
    }

    private func ringView(metrics: PortraitLayoutMetrics) -> some View {
        CountdownRingView(
            remainingText: remainingText,
            remainingSeconds: remainingSeconds,
            untilText: ringSubtitle,
            progress: countdownProgress,
            ringColor: ringColor,
            size: metrics.ringSize,
            lineWidth: metrics.ringLineWidth,
            timeFontSize: metrics.timeFontSize,
            subtitleFont: .system(size: metrics.subtitleFontSize, weight: .semibold),
            isDurationAdjustable: !isFocused && editMode == .pomodoroSetup,
            durationMinutes: pomodoroMinutes,
            onDurationChanged: onPomodoroMinutesChanged,
            onDurationCommitted: onPomodoroMinutesCommitted
        )
        .frame(width: metrics.ringSize, height: metrics.ringSize)
    }

    private func focusButton(metrics: PortraitLayoutMetrics) -> some View {
        actionButton(
            title: "Focus",
            identifier: "action.focus",
            foreground: StartLineLayout.focusButtonForeground,
            metrics: metrics,
            action: onFocus
        )
    }

    private func editButton(metrics: PortraitLayoutMetrics) -> some View {
        actionButton(
            title: "Edit",
            identifier: "action.edit",
            foreground: StartLineLayout.editButtonForeground,
            metrics: metrics,
            action: onEdit
        )
    }

    private func nextCountdownButton(metrics: PortraitLayoutMetrics) -> some View {
        actionButton(
            title: nextCountdownTitle,
            identifier: "action.next",
            foreground: StartLineLayout.pomodoroColor,
            metrics: metrics,
            action: onStartNext
        )
    }

    private func actionButton(
        title: String,
        identifier: String,
        foreground: Color,
        metrics: PortraitLayoutMetrics,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(minWidth: metrics.controlButtonMinWidth)
                .padding(.horizontal, metrics.controlButtonHorizontalPadding)
                .padding(.vertical, metrics.controlButtonVerticalPadding)
                .background(StartLineLayout.actionButtonBackground, in: Capsule())
                .overlay {
                    Capsule().stroke(foreground.opacity(0.26), lineWidth: StartLineLayout.actionButtonBorderWidth)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var nextCountdownTitle: String {
        completedType == .pomodoro
            ? "Start 5m Break"
            : "Start \(pomodoroMinutes)m Pomodoro"
    }
}

private struct PortraitLayoutMetrics {
    let centerX: CGFloat
    let contentWidth: CGFloat
    let titleCenterY: CGFloat
    let titleFontSize: CGFloat
    let ringSize: CGFloat
    let ringLineWidth: CGFloat
    let ringCenterY: CGFloat
    let timeFontSize: CGFloat
    let subtitleFontSize: CGFloat
    let controlButtonMinWidth: CGFloat
    let controlButtonHorizontalPadding: CGFloat
    let controlButtonVerticalPadding: CGFloat
    let controlButtonCenterY: CGFloat
    let focusButtonCenterY: CGFloat
    let completionButtonCenterY: CGFloat
    let candidateListCenterY: CGFloat
    let candidateMetrics: CandidateLayoutMetrics

    init(size: CGSize, isFocused: Bool) {
        let width = size.width
        let height = size.height
        let topAreaHeight = height * 0.50
        let bottomAreaTop = topAreaHeight
        let titleFontSize = width * 0.080
        let statusCenterY = height * 0.150
        let titleToStatusCenterDistance = max(height * 0.066, titleFontSize * 1.55)
        let controlButtonCenterY = height * 0.910
        let controlButtonVerticalPadding = height * 0.012
        let estimatedControlButtonHeight = width * 0.045 + controlButtonVerticalPadding * 2
        let buttonTop = controlButtonCenterY - estimatedControlButtonHeight * 0.5
        let runningRingTopLimit = statusCenterY + height * 0.095
        let runningRingBottomLimit = buttonTop - height * 0.070
        let runningRingCenterY = height * 0.500
        let runningRingVerticalLimit = max(
            0,
            min(
                runningRingCenterY - runningRingTopLimit,
                runningRingBottomLimit - runningRingCenterY
            ) * 2
        )
        let preStartRingSize = min(width * 0.66, height * 0.340)
        let runningRingSize = min(width * 0.74, runningRingVerticalLimit)
        let ringSize = isFocused ? runningRingSize : preStartRingSize
        let candidateSectionSpacing = height * 0.012
        let candidateLabelSpacing = height * 0.008
        let candidateButtonFontSize = width * 0.045
        let candidateButtonVerticalPadding = width * 0.030
        let candidateButtonHeight = candidateButtonFontSize * 1.22 + candidateButtonVerticalPadding * 2
        let candidateGridHeight = candidateButtonHeight * 3 + candidateSectionSpacing * 2
        let candidatePageTitleFontSize = width * 0.048
        let candidateLegendFontSize = width * 0.027
        let candidateLegendHeight = max(max(8, width * 0.029), candidateLegendFontSize * 1.18)
        let candidateHeaderHeight = max(candidatePageTitleFontSize, candidateLegendHeight)
        let estimatedCandidateListHeight = candidateHeaderHeight
            + candidateGridHeight
            + candidateLabelSpacing
        let candidateMetrics = CandidateLayoutMetrics(
            sectionSpacing: candidateSectionSpacing,
            labelSpacing: candidateLabelSpacing,
            horizontalInset: width * 0.006,
            pageTitleFontSize: candidatePageTitleFontSize,
            legendFontSize: candidateLegendFontSize,
            legendSwatchSize: max(8, width * 0.029),
            listHeight: estimatedCandidateListHeight,
            rowSpacing: width * 0.027,
            buttonFontSize: candidateButtonFontSize,
            buttonHeight: candidateButtonHeight
        )
        let preStartRingCenterY = min(topAreaHeight - preStartRingSize * 0.50, height * 0.365)
        let candidateTopLimit = bottomAreaTop + height * 0.030
        let candidateBottomLimit = buttonTop - height * 0.040
        let balancedCandidateCenterY = bottomAreaTop + (buttonTop - bottomAreaTop) * 0.48
        let minimumCandidateCenterY = candidateTopLimit + estimatedCandidateListHeight * 0.5
        let maximumCandidateCenterY = candidateBottomLimit - estimatedCandidateListHeight * 0.5
        let candidateListCenterY = min(
            max(balancedCandidateCenterY, minimumCandidateCenterY),
            max(minimumCandidateCenterY, maximumCandidateCenterY)
        )

        self.centerX = width * 0.5
        self.contentWidth = width * 0.88
        self.titleCenterY = statusCenterY - titleToStatusCenterDistance
        self.titleFontSize = titleFontSize
        self.ringSize = ringSize
        self.ringLineWidth = ringSize * 0.079
        self.ringCenterY = isFocused ? runningRingCenterY : preStartRingCenterY
        self.timeFontSize = ringSize * 0.28
        self.subtitleFontSize = ringSize * 0.095
        self.controlButtonMinWidth = width * 0.32
        self.controlButtonHorizontalPadding = width * 0.048
        self.controlButtonVerticalPadding = controlButtonVerticalPadding
        self.controlButtonCenterY = controlButtonCenterY
        self.focusButtonCenterY = height * 0.930
        self.completionButtonCenterY = height * 0.820
        self.candidateListCenterY = candidateListCenterY
        self.candidateMetrics = candidateMetrics
    }
}

private struct CandidateLayoutMetrics {
    let sectionSpacing: CGFloat
    let labelSpacing: CGFloat
    let horizontalInset: CGFloat
    let pageTitleFontSize: CGFloat
    let legendFontSize: CGFloat
    let legendSwatchSize: CGFloat
    let listHeight: CGFloat
    let rowSpacing: CGFloat
    let buttonFontSize: CGFloat
    let buttonHeight: CGFloat
}

private struct StartCandidateListView: View {
    let schedule: StartSchedule
    let selectedDate: Date?
    let metrics: CandidateLayoutMetrics
    let isPomodoroSelected: Bool
    let onSelectPomodoro: () -> Void
    let onSelect: (StartCandidate) -> Void

    var body: some View {
        let candidates = Array(schedule.timelineCandidates.prefix(8))
        let rows = stride(from: 0, to: candidates.count, by: 3).map { startIndex in
            Array(candidates[startIndex..<min(startIndex + 3, candidates.count)])
        }

        StartCandidatePageView(
            rows: rows,
            selectedDate: selectedDate,
            metrics: metrics,
            isPomodoroSelected: isPomodoroSelected,
            onSelectPomodoro: onSelectPomodoro,
            onSelect: onSelect
        )
        .frame(height: metrics.listHeight)
    }
}

private struct StartCandidatePageView: View {
    let rows: [[StartCandidate]]
    let selectedDate: Date?
    let metrics: CandidateLayoutMetrics
    let isPomodoroSelected: Bool
    let onSelectPomodoro: () -> Void
    let onSelect: (StartCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.labelSpacing) {
            HStack(alignment: .center, spacing: metrics.rowSpacing) {
                Spacer(minLength: 0)

                StartCandidateLegendView(metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(spacing: metrics.sectionSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: metrics.rowSpacing) {
                        ForEach(row) { candidate in
                            StartCandidateButton(
                                candidate: candidate,
                                isSelected: selectedDate.map { candidate.matches($0) } ?? false,
                                metrics: metrics,
                                action: {
                                    onSelect(candidate)
                                }
                            )
                        }

                        if rowIndex == rows.count - 1, row.count == 2 {
                            PomodoroCandidateButton(
                                isSelected: isPomodoroSelected,
                                metrics: metrics,
                                action: onSelectPomodoro
                            )
                        }

                        if row.count < 3, !(rowIndex == rows.count - 1 && row.count == 2) {
                            ForEach(row.count..<3, id: \.self) { _ in
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, metrics.horizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PomodoroCandidateButton: View {
    let isSelected: Bool
    let metrics: CandidateLayoutMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Pomodoro")
                .font(.system(size: metrics.buttonFontSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .padding(.horizontal, max(4, metrics.buttonFontSize * 0.28))
                .frame(maxWidth: .infinity)
                .frame(height: metrics.buttonHeight)
                .foregroundStyle(.white)
                .background(
                    StartLineLayout.pomodoroButtonBackground,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected
                                ? StartLineLayout.pomodoroSelectedBorder
                                : StartLineLayout.pomodoroButtonBorder,
                            lineWidth: isSelected ? 1.6 : 0.9
                        )
                }
                .shadow(
                    color: isSelected ? StartLineLayout.pomodoroSelectedBorder.opacity(0.20) : .clear,
                    radius: isSelected ? 6 : 0
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StartCandidateLegendView: View {
    let metrics: CandidateLayoutMetrics

    var body: some View {
        HStack(spacing: metrics.rowSpacing * 0.9) {
            ForEach(StartCandidateReason.legendCases) { reason in
                HStack(spacing: metrics.legendSwatchSize * 0.38) {
                    RoundedRectangle(cornerRadius: metrics.legendSwatchSize * 0.35)
                        .fill(reason.buttonBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: metrics.legendSwatchSize * 0.35)
                                .stroke(reason.buttonBorder, lineWidth: 1)
                        }
                        .frame(width: metrics.legendSwatchSize, height: metrics.legendSwatchSize)

                    Text(reason.rawValue)
                        .font(.system(size: metrics.legendFontSize, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct StartCandidateButton: View {
    let candidate: StartCandidate
    let isSelected: Bool
    let metrics: CandidateLayoutMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("To \(candidate.displayText)")
                .font(.system(size: metrics.buttonFontSize, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.buttonHeight)
                .foregroundStyle(candidate.reason.buttonForeground)
                .background(
                    candidate.reason.buttonBackground,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? candidate.reason.selectedBorder : candidate.reason.buttonBorder,
                            lineWidth: isSelected ? 3.0 : 0.9
                        )
                }
                .shadow(
                    color: isSelected ? candidate.reason.selectedBorder.opacity(0.35) : .clear,
                    radius: isSelected ? 5 : 0
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LandscapeDisplayView: View {
    let schedule: StartSchedule
    let candidate: StartCandidate
    let selectedDate: Date?
    let availableSize: CGSize
    let remainingText: String
    let remainingSeconds: Int
    let countdownProgress: Double
    let ringColor: Color
    let isFocused: Bool
    let editMode: EditMode
    let pomodoroMinutes: Int
    let ringSubtitle: String
    let completedType: CountdownType?
    let onSelect: (StartCandidate) -> Void
    let onSelectPomodoro: () -> Void
    let onPomodoroMinutesChanged: (Int) -> Void
    let onPomodoroMinutesCommitted: (Int) -> Void
    let onFocus: () -> Void
    let onStartNext: () -> Void
    let onEdit: () -> Void

    var body: some View {
        let metrics = LandscapeLayoutMetrics(size: availableSize, isFocused: isFocused)

        ZStack {
            Text("StartLine")
                .font(.system(size: metrics.titleFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: metrics.headerWidth, alignment: .leading)
                .position(x: metrics.titleX, y: metrics.titleY)

            ringContent(metrics: metrics)
                .position(x: metrics.ringCenterX, y: metrics.ringCenterY)

            if !isFocused {
                StartCandidateListView(
                    schedule: schedule,
                    selectedDate: selectedDate,
                    metrics: metrics.candidateMetrics,
                    isPomodoroSelected: editMode == .pomodoroSetup,
                    onSelectPomodoro: onSelectPomodoro,
                    onSelect: onSelect
                )
                .frame(width: metrics.candidateListWidth)
                .position(x: metrics.candidateListCenterX, y: metrics.candidateListCenterY)
                .transition(.opacity)
            }

            if !isFocused {
                focusButton(metrics: metrics)
                    .position(x: metrics.controlButtonCenterX, y: metrics.focusButtonCenterY)
            } else {
                if completedType == .pomodoro || completedType == .breakTime {
                    nextCountdownButton(metrics: metrics)
                        .position(x: metrics.controlButtonCenterX, y: metrics.completionButtonCenterY)
                }

                editButton(metrics: metrics)
                    .position(x: metrics.controlButtonCenterX, y: metrics.controlButtonCenterY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.24), value: isFocused)
    }

    private func ringContent(metrics: LandscapeLayoutMetrics) -> some View {
        CountdownRingView(
            remainingText: remainingText,
            remainingSeconds: remainingSeconds,
            untilText: ringSubtitle,
            progress: countdownProgress,
            ringColor: ringColor,
            size: metrics.ringSize,
            lineWidth: metrics.ringLineWidth,
            timeFontSize: metrics.timeFontSize,
            subtitleFont: .system(size: metrics.subtitleFontSize, weight: .semibold),
            isDurationAdjustable: !isFocused && editMode == .pomodoroSetup,
            durationMinutes: pomodoroMinutes,
            onDurationChanged: onPomodoroMinutesChanged,
            onDurationCommitted: onPomodoroMinutesCommitted
        )
    }

    private func focusButton(metrics: LandscapeLayoutMetrics) -> some View {
        actionButton(
            title: "Focus",
            identifier: "action.focus",
            foreground: StartLineLayout.focusButtonForeground,
            width: metrics.controlButtonWidth,
            metrics: metrics,
            action: onFocus
        )
    }

    private func editButton(metrics: LandscapeLayoutMetrics) -> some View {
        actionButton(
            title: "Edit",
            identifier: "action.edit",
            foreground: StartLineLayout.editButtonForeground,
            width: metrics.controlButtonWidth,
            metrics: metrics,
            action: onEdit
        )
    }

    private func nextCountdownButton(metrics: LandscapeLayoutMetrics) -> some View {
        actionButton(
            title: nextCountdownTitle,
            identifier: "action.next",
            foreground: StartLineLayout.pomodoroColor,
            width: metrics.completionButtonWidth,
            metrics: metrics,
            action: onStartNext
        )
    }

    private func actionButton(
        title: String,
        identifier: String,
        foreground: Color,
        width: CGFloat,
        metrics: LandscapeLayoutMetrics,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: metrics.controlButtonFontSize, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: width)
                .padding(.vertical, metrics.controlButtonVerticalPadding)
                .background(StartLineLayout.actionButtonBackground, in: Capsule())
                .overlay {
                    Capsule().stroke(foreground.opacity(0.26), lineWidth: StartLineLayout.actionButtonBorderWidth)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var nextCountdownTitle: String {
        completedType == .pomodoro
            ? "Start 5m Break"
            : "Start \(pomodoroMinutes)m Pomodoro"
    }
}

private struct LandscapeLayoutMetrics {
    let headerWidth: CGFloat
    let titleFontSize: CGFloat
    let titleX: CGFloat
    let titleY: CGFloat
    let ringSize: CGFloat
    let ringLineWidth: CGFloat
    let ringCenterX: CGFloat
    let ringCenterY: CGFloat
    let timeFontSize: CGFloat
    let subtitleFontSize: CGFloat
    let controlButtonWidth: CGFloat
    let completionButtonWidth: CGFloat
    let controlButtonFontSize: CGFloat
    let controlButtonVerticalPadding: CGFloat
    let controlButtonCenterX: CGFloat
    let controlButtonCenterY: CGFloat
    let focusButtonCenterY: CGFloat
    let completionButtonCenterY: CGFloat
    let candidateListWidth: CGFloat
    let candidateListCenterX: CGFloat
    let candidateListCenterY: CGFloat
    let candidateMetrics: CandidateLayoutMetrics

    init(size: CGSize, isFocused: Bool) {
        let width = size.width
        let height = size.height
        let leftAreaWidth = width * 0.50
        let rightAreaMinX = leftAreaWidth
        let horizontalMargin = width * 0.055
        let rightMargin = width * 0.055
        let preStartRingSize = min(width * 0.35, height * 0.66)
        let runningRingSize = min(width * 0.39, height * 0.74)
        let ringSize = isFocused ? runningRingSize : preStartRingSize
        let controlButtonWidth = width * 0.16
        let controlButtonVerticalPadding = height * 0.018
        let controlButtonFontSize = height * 0.045
        let headerWidth = leftAreaWidth - horizontalMargin * 1.5
        let titleX = horizontalMargin + headerWidth * 0.5
        let candidateListWidth = width * 0.50 - rightMargin - width * 0.035
        let candidateSectionSpacing = height * 0.030
        let candidateLabelSpacing = height * 0.014
        let candidateButtonFontSize = min(height * 0.050, width * 0.026)
        let candidateButtonVerticalPadding = height * 0.026
        let candidateButtonHeight = candidateButtonFontSize * 1.22 + candidateButtonVerticalPadding * 2
        let candidateGridHeight = candidateButtonHeight * 3 + candidateSectionSpacing * 2
        let candidatePageTitleFontSize = height * 0.054
        let candidateLegendFontSize = height * 0.030
        let candidateLegendHeight = max(max(8, height * 0.033), candidateLegendFontSize * 1.18)
        let candidateHeaderHeight = max(candidatePageTitleFontSize, candidateLegendHeight)
        let estimatedCandidateListHeight = candidateHeaderHeight
            + candidateGridHeight
            + candidateLabelSpacing
        let candidateMetrics = CandidateLayoutMetrics(
            sectionSpacing: candidateSectionSpacing,
            labelSpacing: candidateLabelSpacing,
            horizontalInset: width * 0.004,
            pageTitleFontSize: candidatePageTitleFontSize,
            legendFontSize: candidateLegendFontSize,
            legendSwatchSize: max(8, height * 0.033),
            listHeight: estimatedCandidateListHeight,
            rowSpacing: width * 0.012,
            buttonFontSize: candidateButtonFontSize,
            buttonHeight: candidateButtonHeight
        )
        let estimatedControlButtonHeight = controlButtonFontSize + controlButtonVerticalPadding * 2
        let candidateToControlSpacing = height * 0.105
        let rightGroupHeight = estimatedCandidateListHeight + candidateToControlSpacing + estimatedControlButtonHeight
        let rightGroupTop = (height - rightGroupHeight) * 0.5
        let candidateListCenterY = rightGroupTop + estimatedCandidateListHeight * 0.5
        let controlButtonCenterY = height - height * 0.105 - estimatedControlButtonHeight * 0.5

        self.headerWidth = headerWidth
        self.titleFontSize = height * 0.086
        self.titleX = titleX
        self.titleY = height * 0.105
        self.ringSize = ringSize
        self.ringLineWidth = ringSize * 0.086
        self.ringCenterX = isFocused ? width * 0.50 : leftAreaWidth * 0.50
        self.ringCenterY = isFocused ? height * 0.500 : height * 0.565
        self.timeFontSize = ringSize * 0.30
        self.subtitleFontSize = ringSize * 0.100
        self.controlButtonWidth = controlButtonWidth
        self.completionButtonWidth = width * 0.25
        self.controlButtonFontSize = controlButtonFontSize
        self.controlButtonVerticalPadding = controlButtonVerticalPadding
        self.controlButtonCenterX = width - rightMargin - controlButtonWidth * 0.5
        self.controlButtonCenterY = controlButtonCenterY
        self.focusButtonCenterY = height * 0.900
        self.completionButtonCenterY = height * 0.735
        self.candidateListWidth = candidateListWidth
        self.candidateListCenterX = rightAreaMinX + candidateListWidth * 0.5 + width * 0.035
        self.candidateListCenterY = candidateListCenterY
        self.candidateMetrics = candidateMetrics
    }
}

private struct CountdownRingView: View {
    private let showsSecondMarker = false

    @State private var previousDragAngle: Double?
    @State private var accumulatedDragDegrees: Double = 0
    @State private var gestureMinutes: Int?

    let remainingText: String
    let remainingSeconds: Int
    let untilText: String
    let progress: Double
    let ringColor: Color
    let size: CGFloat
    let lineWidth: CGFloat
    let timeFontSize: CGFloat
    let subtitleFont: Font
    let isDurationAdjustable: Bool
    let durationMinutes: Int
    let onDurationChanged: (Int) -> Void
    let onDurationCommitted: (Int) -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.14), lineWidth: lineWidth)
                .frame(width: size, height: size)

            decorativeRingMarks

            if showsSecondMarker {
                secondMarker
            }

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.opacity(0.54),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            VStack(spacing: 8) {
                Text(remainingText)
                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .allowsTightening(true)
                    .frame(width: size * 0.78)
                    .accessibilityIdentifier("countdown.remaining")

                Text(untilText)
                    .font(subtitleFont)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .monospacedDigit()
                    .lineLimit(1)
                    .accessibilityIdentifier(ringAccessibilityIdentifier)
            }
            .padding(.horizontal, lineWidth + 14)

            if isDurationAdjustable {
                Circle()
                    .fill(Color.clear)
                    .contentShape(Circle())
                    .gesture(durationGesture)
                    .simultaneousGesture(durationTapGesture)
                    .accessibilityElement()
                    .accessibilityLabel("Pomodoro duration")
                    .accessibilityValue("\(durationMinutes) minutes")
                    .accessibilityHint("Swipe up or down to adjust by 5 minutes")
                    .accessibilityAdjustableAction { direction in
                        let step = direction == .increment ? 5 : -5
                        let newMinutes = boundedMinutes(durationMinutes + step)
                        onDurationChanged(newMinutes)
                        onDurationCommitted(newMinutes)
                    }
            }
        }
        .frame(width: size, height: size)
    }

    private var ringAccessibilityIdentifier: String {
        guard untilText.hasPrefix("To ") else {
            return "countdown.ring"
        }

        return "countdown.ring.\(ScheduledRingPhase(remainingSeconds: remainingSeconds).rawValue)"
    }

    private var durationGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .local)
            .onChanged { value in
                let center = CGPoint(x: size / 2, y: size / 2)
                let angle = atan2(
                    value.location.y - center.y,
                    value.location.x - center.x
                ) * 180 / .pi

                if gestureMinutes == nil {
                    gestureMinutes = durationMinutes
                }

                guard let previousDragAngle else {
                    self.previousDragAngle = angle
                    return
                }

                var delta = angle - previousDragAngle
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }

                accumulatedDragDegrees += delta
                self.previousDragAngle = angle

                while accumulatedDragDegrees >= 30 {
                    adjustGestureMinutes(by: 5)
                    accumulatedDragDegrees -= 30
                }

                while accumulatedDragDegrees <= -30 {
                    adjustGestureMinutes(by: -5)
                    accumulatedDragDegrees += 30
                }
            }
            .onEnded { _ in
                let committedMinutes = gestureMinutes ?? durationMinutes
                onDurationCommitted(committedMinutes)
                previousDragAngle = nil
                accumulatedDragDegrees = 0
                gestureMinutes = nil
            }
    }

    private var durationTapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let center = CGPoint(x: size / 2, y: size / 2)
                let offsetX = value.location.x - center.x
                let offsetY = value.location.y - center.y
                let distanceFromCenter = hypot(offsetX, offsetY)
                let minimumTapRadius = size / 2 - lineWidth * 2.2

                guard distanceFromCenter >= minimumTapRadius else {
                    return
                }

                let rawAngle = atan2(offsetY, offsetX) * 180 / .pi + 90
                let clockwiseAngle = rawAngle >= 0 ? rawAngle : rawAngle + 360
                let step = Int(round(clockwiseAngle / 30))
                let newMinutes = step == 0 ? 60 : min(60, step * 5)

                onDurationChanged(newMinutes)
                onDurationCommitted(newMinutes)
            }
    }

    private func adjustGestureMinutes(by step: Int) {
        let newMinutes = boundedMinutes((gestureMinutes ?? durationMinutes) + step)
        gestureMinutes = newMinutes
        onDurationChanged(newMinutes)
    }

    private func boundedMinutes(_ minutes: Int) -> Int {
        min(60, max(5, minutes))
    }

    private var secondMarker: some View {
        let markHeight = max(14, size * 0.040)
        let markerSize = max(10, size * 0.040)
        let markerRadius = size / 2 - lineWidth - markHeight * 0.18
        let second = remainingSeconds % 60

        return Image(systemName: "triangle.fill")
            .font(.system(size: markerSize, weight: .bold))
            .foregroundStyle(ringColor.opacity(0.54))
            .rotationEffect(.degrees(180))
            .offset(y: -markerRadius)
            .rotationEffect(.degrees(Double(second) * 6))
    }

    private var decorativeRingMarks: some View {
        let markWidth = max(2.8, size * 0.007)
        let markHeight = max(14, size * 0.040)

        return ZStack {
            ForEach(0..<30, id: \.self) { index in
                Capsule()
                    .fill(ringColor.opacity(0.24))
                    .frame(width: markWidth, height: markHeight)
                    .offset(y: -(size / 2 - lineWidth - markHeight))
                    .rotationEffect(.degrees(Double(index) * 360 / 30))
            }
        }
        .frame(width: size, height: size)
    }
}

struct StartSchedule {
    let suggested: StartCandidate
    let timelineCandidates: [StartCandidate]

    var timelineRows: [[StartCandidate]] {
        Self.rows(from: timelineCandidates)
    }

    static func make(now: Date, calendar: Calendar = .current) -> StartSchedule {
        let timelineCandidates = nextTimelineCandidates(after: now, calendar: calendar, count: 9)
        let fallbackDate = nextFiveMinuteStart(after: now, calendar: calendar)
        let fallbackCandidate = StartCandidate(
            date: fallbackDate,
            calendar: calendar,
            reason: reason(for: fallbackDate, calendar: calendar)
        )

        return StartSchedule(
            suggested: timelineCandidates.first ?? fallbackCandidate,
            timelineCandidates: timelineCandidates
        )
    }

    func candidate(matching date: Date, calendar: Calendar) -> StartCandidate {
        if suggested.matches(date) {
            return suggested
        }

        if let candidate = timelineCandidates.first(where: { $0.matches(date) }) {
            return candidate
        }

        return StartCandidate(
            date: date,
            calendar: calendar,
            reason: Self.reason(for: date, calendar: calendar)
        )
    }

    private static func nextTimelineCandidates(
        after date: Date,
        calendar: Calendar,
        count: Int
    ) -> [StartCandidate] {
        var candidates: [StartCandidate] = []
        var candidateDate = nextFiveMinuteStart(after: date, calendar: calendar)

        while candidates.count < count {
            candidates.append(
                StartCandidate(
                    date: candidateDate,
                    calendar: calendar,
                    reason: reason(for: candidateDate, calendar: calendar)
                )
            )

            guard let nextDate = calendar.date(byAdding: .minute, value: 5, to: candidateDate) else {
                break
            }

            candidateDate = nextDate
        }

        return candidates
    }

    private static func rows(from candidates: [StartCandidate]) -> [[StartCandidate]] {
        stride(from: 0, to: candidates.count, by: 3).map { startIndex in
            Array(candidates[startIndex..<min(startIndex + 3, candidates.count)])
        }
    }

    private static func reason(for date: Date, calendar: Calendar) -> StartCandidateReason {
        let minute = calendar.component(.minute, from: date)

        if minute.isMultiple(of: 15) {
            return .nextQuarter
        }

        if minute.isMultiple(of: 10) {
            return .nearest10
        }

        return .quickStart
    }

    private static func nextFiveMinuteStart(after date: Date, calendar: Calendar) -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        let minute = calendar.component(.minute, from: date)
        let nextSlot = ((minute / 5) + 1) * 5

        if nextSlot < 60 {
            return calendar.date(byAdding: .minute, value: nextSlot, to: hourStart) ?? date
        }

        return calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? date
    }

    static func remainingSeconds(from now: Date, to start: Date) -> Int {
        max(0, Int(ceil(start.timeIntervalSince(now))))
    }

    static func remainingTimeText(from now: Date, to start: Date) -> String {
        remainingTimeText(remainingSeconds: remainingSeconds(from: now, to: start))
    }

    static func remainingTimeText(remainingSeconds: Int) -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }
}

enum StartCandidateReason: String, CaseIterable, Identifiable {
    case nextQuarter = "Quarter"
    case nearest10 = "10-Minute"
    case quickStart = "5-Minute"

    static let legendCases: [StartCandidateReason] = [.nextQuarter, .nearest10]

    var id: String {
        rawValue
    }

    var buttonBackground: Color {
        switch self {
        case .nextQuarter:
            Color(red: 0.035, green: 0.390, blue: 0.395)
        case .nearest10:
            Color(red: 0.165, green: 0.105, blue: 0.315)
        case .quickStart:
            Color(red: 0.075, green: 0.090, blue: 0.110)
        }
    }

    var buttonBorder: Color {
        switch self {
        case .nextQuarter:
            Color(red: 0.100, green: 0.780, blue: 0.760)
        case .nearest10:
            Color(red: 0.530, green: 0.415, blue: 0.950)
        case .quickStart:
            Color(red: 0.255, green: 0.315, blue: 0.385)
        }
    }

    var selectedBorder: Color {
        switch self {
        case .nextQuarter:
            Color(red: 0.210, green: 0.940, blue: 0.900)
        case .nearest10:
            Color(red: 0.700, green: 0.590, blue: 1.000)
        case .quickStart:
            Color(red: 0.560, green: 0.625, blue: 0.700)
        }
    }

    var buttonForeground: Color {
        switch self {
        case .quickStart:
            Color(red: 0.820, green: 0.860, blue: 0.900)
        case .nextQuarter, .nearest10:
            .white
        }
    }
}

struct StartCandidate: Identifiable {
    let date: Date
    let displayText: String
    let reason: StartCandidateReason

    var id: TimeInterval {
        date.timeIntervalSinceReferenceDate
    }

    init(date: Date, calendar: Calendar, reason: StartCandidateReason) {
        self.date = date
        self.reason = reason

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        self.displayText = "\(hour):\(String(format: "%02d", minute))"
    }

    func matches(_ other: StartCandidate) -> Bool {
        matches(other.date)
    }

    func matches(_ otherDate: Date) -> Bool {
        abs(date.timeIntervalSince(otherDate)) < 0.5
    }
}

#Preview("Portrait") {
    ContentView()
}

#Preview("Landscape") {
    ContentView()
        .frame(width: 844, height: 390)
}
