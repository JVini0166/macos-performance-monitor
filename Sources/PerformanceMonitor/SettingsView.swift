import SwiftUI

struct LanguageSettingsView: View {
    @AppStorage(L10n.preferenceKey) private var language = AppLanguage.initial.rawValue
    var body: some View {
        Form {
            Section {
                Picker(L("Idioma do aplicativo"), selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                }.pickerStyle(.menu)
                Text(L("A alteração é aplicada imediatamente e salva para as próximas execuções."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label(L("Idioma e região"), systemImage: "globe") }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 440, height: 200)
        .navigationTitle(L("Ajustes"))
        .environment(\.locale, Locale(identifier: language))
    }
}
