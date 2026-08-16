import SwiftUI

public struct PasswordPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let onSubmit: (String) -> Void

    @State private var password: String = ""
    @FocusState private var isFieldFocused: Bool

    public init(onSubmit: @escaping (String) -> Void) {
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                Text("Encrypted Archive")
                    .font(.headline)
                Text("This archive is protected with a password. Please enter the decryption key to continue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            SecureField("Enter Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .onSubmit {
                    submit()
                }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Unlock") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            isFieldFocused = true
        }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        dismiss()
        onSubmit(password)
    }
}
