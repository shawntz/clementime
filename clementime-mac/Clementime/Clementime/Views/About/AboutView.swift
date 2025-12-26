//
//  AboutView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    // Version information
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    private let commit = BuildInfo.gitCommitHash

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(28)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            } else {
                // Fallback icon
                Image(systemName: "calendar.badge.clock")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .foregroundColor(.accentColor)
            }

            // App Name
            Text("ClemenTime")
                .font(.system(size: 36, weight: .semibold, design: .default))
                .foregroundColor(.primary)

            // Tagline
            Text("Native macOS oral exam scheduler with\nCloudKit sync and offline support.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
                .frame(height: 8)

            // Version Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Version")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    Text(version)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Build")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    Text(build)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Commit")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    Text(commit)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                        .onTapGesture {
                            if let url = URL(string: "https://github.com/shawntz/clementime/commit/\(commit)") {
                                openURL(url)
                            }
                        }
                        .help("View commit on GitHub")
                }
            }
            .font(.system(size: 13, design: .monospaced))

            // Copyright
            Text("© Shawn Schwartz, 2025")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            // Action Buttons
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://github.com/shawntz/clementime/blob/main/clementime-mac/README.md") {
                        openURL(url)
                    }
                }) {
                    Text("Docs")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: {
                    if let url = URL(string: "https://github.com/shawntz/clementime") {
                        openURL(url)
                    }
                }) {
                    Text("GitHub")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 400, height: 500)
        .padding(32)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AboutView()
}
