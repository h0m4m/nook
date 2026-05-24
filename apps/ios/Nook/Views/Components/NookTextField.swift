import SwiftUI

struct NookTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.nook.mutedForeground.opacity(0.7))
                    .frame(width: 20, height: 20)
            }

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(NookFont.bodyMedium)
                        .foregroundStyle(Color.nook.mutedForeground)
                }

                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color.nook.foreground)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.nook.border, lineWidth: 1)
        )
        .shadow(
            color: isFocused ? Color.nook.primary.opacity(0.12) : .clear,
            radius: 8,
            x: 0,
            y: 2
        )
        .focused($isFocused)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

#Preview {
    VStack(spacing: 12) {
        NookTextField(placeholder: "name@example.com", text: .constant(""), icon: "envelope")
        NookTextField(placeholder: "Password", text: .constant(""), isSecure: true, icon: "lock")
    }
    .padding(24)
    .background(Color.nook.background)
}
