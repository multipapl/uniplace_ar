//
//  AppChrome.swift
//  UP_AR (UniPlace)
//
//  Small SwiftUI primitives shared by the shell screens and HUD.
//

import SwiftUI

enum AppChrome {
    static let panelRadius: CGFloat = 8
    static let controlRadius: CGFloat = 8
    static let controlSize: CGFloat = 52
    static let compactControlSize: CGFloat = 44
    static let maxPanelWidth: CGFloat = 440
    static let panelFill = Color.white.opacity(0.52)
    static let controlFill = Color.black.opacity(0.055)
    static let controlFillPressed = Color.black.opacity(0.10)
    static let primaryControlFill = Color(white: 0.38).opacity(0.33)
    static let stroke = Color.black.opacity(0.12)
    static let accent = Color(red: 0.05, green: 0.22, blue: 0.34)
    static let warmAccent = Color(red: 1.0, green: 0.86, blue: 0.54)
}

struct ChromePanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(AppChrome.panelFill, in: RoundedRectangle(cornerRadius: AppChrome.panelRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.panelRadius)
                    .stroke(AppChrome.stroke, lineWidth: 1)
            }
            .foregroundStyle(.black)
    }
}

struct ChromeIconButton: View {
    let systemName: String
    let title: String
    var size: CGFloat = AppChrome.controlSize
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size == AppChrome.controlSize ? 21 : 17, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(width: size, height: size)
                .background(isSelected ? .white : .black.opacity(0.48), in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(isSelected ? 0.70 : 0.18), lineWidth: 1)
                }
        }
        .buttonStyle(ChromePressButtonStyle())
        .accessibilityLabel(title)
    }
}

struct ChromeCommandButton: View {
    let title: String
    let systemName: String
    var role: ButtonRole?
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isPrimary ? .black.opacity(0.78) : AppChrome.accent)
                    .frame(width: 28, height: 28)
                    .background(isPrimary ? .white.opacity(0.46) : .black.opacity(0.06), in: Circle())
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(isPrimary ? 0.34 : 0.34))
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 14)
            .background(isPrimary ? AppChrome.primaryControlFill : AppChrome.controlFill,
                        in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
            .foregroundStyle(.black)
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.controlRadius)
                    .stroke(.black.opacity(isPrimary ? 0.10 : 0.08), lineWidth: 1)
            }
        }
        .buttonStyle(ChromePressButtonStyle())
    }
}

struct ChromePlainButton: View {
    let title: String
    let systemName: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 14)
            .foregroundStyle(isSelected ? .white : .black)
            .background(isSelected ? .black : AppChrome.controlFill,
                        in: RoundedRectangle(cornerRadius: AppChrome.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.controlRadius)
                    .stroke(isSelected ? .black.opacity(0.70) : AppChrome.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(ChromePressButtonStyle())
    }
}

struct ChromeSheetHeader: View {
    let title: String
    var subtitle: String?
    var close: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.56))
                }
            }
            Spacer()
            if let close {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.07), in: Circle())
                }
                .buttonStyle(ChromePressButtonStyle())
                .accessibilityLabel("Close")
            }
        }
    }
}

struct ChromePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct ChromeSectionLabel: View {
    let title: String
    var value: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black.opacity(0.45))
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.black.opacity(0.45))
            }
        }
    }
}

struct ChromeEmptyState: View {
    let systemName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.black.opacity(0.56))
                .frame(width: 64, height: 64)
                .background(.black.opacity(0.07), in: Circle())
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.58))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}
