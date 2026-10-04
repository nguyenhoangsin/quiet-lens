import SwiftUI

struct LensSettingsView: View {
    @EnvironmentObject private var model: QuietLensViewModel
    @State private var draft = LensSettings()
    @State private var prompt = ""
    @State private var key = ""
    @State private var notice: String?
    @State private var noticeIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Gemini", detail: "Gemini 3.5 Flash-Lite") {
                    HStack(spacing: 8) {
                        Image(systemName: model.hasAPIKey ? "checkmark.shield.fill" : "key")
                            .foregroundStyle(model.hasAPIKey ? .teal : .secondary)
                        Text(model.hasAPIKey ? "API key saved locally" : "Add an API key to get started")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        if model.hasAPIKey {
                            Button("Remove", role: .destructive) { perform("API key removed") { try model.deleteKey() } }
                                .controlSize(.small)
                        }
                    }
                    HStack(spacing: 10) {
                        SecureField(model.hasAPIKey ? "Enter a new key to replace it" : "Gemini API key", text: $key)
                            .textFieldStyle(.roundedBorder)
                        Button("Save key") {
                            perform("API key saved") { try model.saveKey(key); key = "" }
                        }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Your saved key is never displayed. Screenshots are sent directly to Google.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                section("Prompt", detail: "Sent with every image") {
                    TextEditor(text: $prompt)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8).frame(height: 156)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
                        .accessibilityLabel("Custom image prompt")
                    HStack {
                        Text(prompt == model.prompt ? "Saved · applies to the next request" : "Unsaved changes")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                        Spacer()
                        Button("Use default") { prompt = model.defaultPrompt }.controlSize(.small)
                        Button("Save prompt") {
                            perform("Prompt saved") { try model.savePrompt(prompt) }
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .disabled(prompt == model.prompt || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                section("Capture", detail: "Local change detection") {
                    HStack {
                        Text(model.settings.region?.description ?? "No region selected").font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Choose region", action: model.chooseRegion).controlSize(.small).disabled(model.isSelecting)
                    }
                    if !model.hasScreenPermission {
                        HStack {
                            Text("Screen Recording permission is required.").font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            Button("Allow screen capture", action: model.requestScreenPermission).controlSize(.small)
                        }
                    }
                    slider("Change threshold", value: $draft.threshold, range: 0.002...0.08,
                           label: String(format: "%.1f%%", draft.threshold * 100))
                    slider("Capture interval", value: $draft.captureInterval, range: 0.3...30,
                           label: String(format: "%.1fs", draft.captureInterval))
                    slider("Wait for stability", value: $draft.debounce, range: 0.5...10,
                           label: String(format: "%.1fs", draft.debounce))
                    Text("Lower thresholds detect smaller edits. Higher values ignore minor changes.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                HStack {
                    if let notice {
                        Text(notice).font(.system(size: 11)).foregroundStyle(noticeIsError ? .orange : .secondary)
                    }
                    Spacer()
                    Button("Save settings") {
                        // Region and mode may have changed while the draft was open.
                        draft.region = model.settings.region
                        draft.mode = model.settings.mode
                        perform("Settings saved") { try model.update(settings: draft, prompt: prompt) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .onAppear { draft = model.settings; prompt = model.prompt }
    }

    private func section<Content: View>(_ title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(detail).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            content()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.quaternary, lineWidth: 1) }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 11)).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range).accessibilityLabel(title)
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
        }
    }
    private func perform(_ success: String, action: () throws -> Void) {
        do { try action(); notice = success; noticeIsError = false }
        catch { notice = error.localizedDescription; noticeIsError = true }
    }
}
