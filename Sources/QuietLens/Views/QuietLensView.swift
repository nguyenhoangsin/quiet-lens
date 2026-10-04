import AppKit
import SwiftUI

struct QuietLensView: View {
    @EnvironmentObject private var model: QuietLensViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.section == .lens { lens } else { LensSettingsView() }
            Divider()
            controlBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.teal)
        .frame(minWidth: 640, minHeight: 610)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            model.installOverlay()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("QuietLens").font(.system(size: 18, weight: .semibold))
                Text("A little clarity, without the interruption.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Section", selection: $model.section) {
                ForEach(QuietLensViewModel.Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 164).labelsHidden()
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var lens: some View {
        VStack(alignment: .leading, spacing: 18) {
            regionCard
            if let error = model.errorMessage {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    Text(error).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if !model.hasScreenPermission {
                        Button("Allow", action: model.requestScreenPermission).controlSize(.small)
                    } else if !model.hasAPIKey {
                        Button("Settings") { model.section = .settings }.controlSize(.small)
                    }
                }
                .padding(12).background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            answerCard
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                Text("Only your selected region is sent to Gemini when you ask or start Auto.")
            }
            .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(24)
    }

    private var regionCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "viewfinder")
                .font(.system(size: 24, weight: .light)).foregroundStyle(.teal)
                .frame(width: 46, height: 46)
                .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(model.settings.region == nil ? "Choose your focus" : "Selected region")
                    .font(.system(size: 13, weight: .medium))
                Text(model.settings.region?.description ?? "Drag over the part of your screen you want to read.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 6)
            Button(model.settings.region == nil ? "Choose region" : "Reselect", action: model.chooseRegion)
                .controlSize(.small).disabled(model.isSelecting)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.quaternary, lineWidth: 1) }
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ANSWER").font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
                Spacer()
                if let date = model.answeredAt {
                    Text(date, style: .time).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    Button(action: model.copyAnswer) { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Copy answer")
                }
            }
            if model.answer.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "viewfinder.circle")
                        .font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.teal.opacity(0.65))
                    Text(model.isBusy ? "Reading your region…" : "Space for an answer")
                        .font(.system(size: 18, weight: .medium))
                    Text(model.hasAPIKey ? "Choose a region, then start Auto or ask once."
                         : "Add your Gemini API key in Settings to get started.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    if !model.hasAPIKey {
                        Button("Set up QuietLens") { model.section = .settings }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(model.answer).font(.system(size: 16)).lineSpacing(6)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.quaternary, lineWidth: 1) }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if model.isBusy { ProgressView().controlSize(.mini) }
                else { Circle().fill(model.isMonitoring ? Color.teal : Color.secondary.opacity(0.35)).frame(width: 6, height: 6) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.status).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Text("\(model.requestCount) requests this session")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Button(action: {
                model.showsOverlay.toggle()
                if model.showsOverlay { model.revealOverlay() } else { model.overlay?.hide() }
            }) {
                Image(systemName: model.showsOverlay ? "rectangle.on.rectangle" : "rectangle")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help(model.showsOverlay ? "Disable answer overlay" : "Enable answer overlay")
            Picker("Mode", selection: Binding(get: { model.settings.mode }, set: model.changeMode)) {
                ForEach(CaptureMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 126).labelsHidden()
            if model.settings.mode == .auto {
                Button(action: model.toggleMonitoring) {
                    Label(model.isMonitoring ? "Pause" : "Start", systemImage: model.isMonitoring ? "pause.fill" : "play.fill")
                        .frame(width: 66)
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(model.isSelecting || (model.isBusy && !model.isMonitoring))
            } else {
                Button("Ask now", systemImage: "sparkle", action: model.askNow)
                    .buttonStyle(.borderedProminent).controlSize(.small).disabled(!model.canAsk)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar, in: Capsule())
        .overlay { Capsule().stroke(.quaternary, lineWidth: 1) }
        .padding(14)
    }
}
