//
//  SettingsView.swift
//  Leftover
//
//  Phase 6 (partial): daily reminder, privacy trust
//  panel, and About. Plus / sharing sections arrive with later phases.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var notifications: NotificationManager
    @ObservedObject var stats: Stats
    var onReplayOnboarding: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var showPrivacyPolicy = false
    @State private var showTrophies = false
    @State private var showMailFallback = false

    static let feedbackAddress = "himanshukarak@gmail.com"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { notifications.reminderEnabled },
                        set: { notifications.setEnabled($0, burstDoneToday: stats.isBurstDoneToday) }
                    )) {
                        HStack(spacing: 12) {
                            IconBadge(icon: "bell", chip: Theme.chipOrange, size: 28)
                            Text("Daily reminder")
                        }
                    }
                    .tint(Theme.cream)

                    if notifications.reminderEnabled {
                        DatePicker("Time", selection: Binding(
                            get: { notifications.reminderTime },
                            set: {
                                notifications.reminderTime = $0
                                notifications.reschedule(burstDoneToday: stats.isBurstDoneToday)
                            }
                        ), displayedComponents: .hourAndMinute)
                    }

                    if notifications.authDenied {
                        Button("Allow notifications in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(Theme.cream)
                    }
                } header: {
                    Text("Daily reminder")
                } footer: {
                    Text("At most one gentle reminder a day, only if you haven’t cleaned up yet. Off anytime.")
                }

                Section {
                    trustRow(icon: "iphone", text: "Everything stays on this iPhone")
                    trustRow(icon: "icloud.slash", text: "Your photos are never uploaded")
                    trustRow(icon: "checkmark.shield", text: "Deletions are always yours to confirm")
                    Button {
                        if let url = URL(string: "photos-redirect://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        trustRow(icon: "clock.arrow.circlepath",
                                 text: "Tossed photos stay in Recently Deleted for 30 days")
                    }
                    .foregroundColor(Theme.ink)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Restore anything within 30 days from Photos → Albums → Recently Deleted. Tap the row to open Photos.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(Theme.dim)
                    }

                    Button {
                        showTrophies = true
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(icon: "trophy", chip: Theme.chipYellow, size: 28)
                            Text("Trophies")
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Text("\(stats.achievedMilestones.count) of \(TrophyShelfView.badges.count)")
                                .font(.footnote.monospacedDigit())
                                .foregroundColor(Theme.dim)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Theme.dim)
                        }
                    }

                    Button {
                        onReplayOnboarding()
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(icon: "hand.draw", chip: Theme.chipOrange, size: 28)
                            Text("How Leftover Works")
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Theme.dim)
                        }
                    }

                    Button {
                        sendFeedback()
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(icon: "envelope", chip: Theme.chipTeal, size: 28)
                            Text("Send Feedback")
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Theme.dim)
                        }
                    }
                    .accessibilityHint("Opens an email to the developer")

                    // The deliberate share path — the celebration pill
                    // covers the emotional one. Same link + pitch, so a
                    // friend gets the same story either way.
                    ShareLink(item: AppLink.site, message: Text(AppLink.invite)) {
                        HStack(spacing: 12) {
                            IconBadge(icon: "square.and.arrow.up", chip: Theme.chipPink, size: 28)
                            Text("Share Leftover")
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Theme.dim)
                        }
                    }
                    .accessibilityHint("Sends the app to a friend")

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack {
                            Text("Privacy Policy")
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Theme.dim)
                        }
                    }

                    HStack {
                        Text("Developer")
                        Spacer()
                        if let url = URL(string: "https://x.com/whysokara") {
                            Link("Kara (@whysokara)", destination: url)
                                .foregroundColor(Theme.cream)
                        } else {
                            Text("Kara")
                                .foregroundColor(Theme.dim)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.stage)
            .alert("Email copied", isPresented: $showMailFallback) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No mail app is set up on this iPhone, so \(Self.feedbackAddress) was copied to your clipboard instead.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundColor(Theme.cream)
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTrophies) {
                TrophyShelfView(achieved: stats.achievedMilestones)
            }
        }
    }

    private func trustRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(icon: icon, chip: Theme.chipTeal, size: 28)
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Opens Mail with the version and iOS build already in the footer —
    /// the two things every useful bug report needs and nobody thinks to
    /// include. Falls back to copying the address, since `mailto:` does
    /// nothing on a device with no mail account set up.
    private func sendFeedback() {
        let body = """


        —
        Leftover \(versionString) · iOS \(UIDevice.current.systemVersion)
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.feedbackAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Leftover feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIPasteboard.general.string = Self.feedbackAddress
            showMailFallback = true
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Last updated July 2026")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)

                    policySection(
                        title: "Local by design",
                        body: "Leftover runs entirely on your iPhone. There is no account, no login, and no server — the app doesn't have one. Nothing you do inside Leftover ever leaves your device."
                    )
                    policySection(
                        title: "What Leftover accesses",
                        body: "Leftover uses Apple's Photos framework to show you your photos and videos and, only when you confirm, to delete the ones you choose. It never uploads, copies, or transmits your photos anywhere."
                    )
                    policySection(
                        title: "Permissions",
                        body: "Photo Library: Leftover asks for full access so it can find duplicates, screenshots, blurry shots, and large videos across your library — all analysis happens on this device. iOS Limited Access is fully supported; grant only selected photos and Leftover works with just those.\n\nNotifications (optional): one daily reminder, only if you switch it on in Settings, and only on days you haven't cleaned up yet. Nothing else, ever."
                    )
                    policySection(
                        title: "What Leftover collects",
                        body: "Nothing. No analytics, no tracking, no third-party SDKs, no advertising identifiers. Reminder settings are stored only in this app's local storage on your phone."
                    )
                    policySection(
                        title: "Deletions",
                        body: "Photos you delete go to your iPhone's own Recently Deleted album for 30 days, exactly as if you'd deleted them from the Photos app. Leftover cannot recover or access them after that."
                    )
                    policySection(
                        title: "Contact",
                        body: "Questions about this policy can be sent to Kara (@whysokara) on X."
                    )
                }
                .padding(20)
            }
            .background(Theme.stage)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundColor(Theme.cream)
                }
            }
        }
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundColor(Theme.ink)
            Text(body)
                .font(.subheadline)
                .foregroundColor(Theme.dim)
        }
    }
}
