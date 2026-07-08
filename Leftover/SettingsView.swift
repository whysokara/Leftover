//
//  SettingsView.swift
//  Leftover
//
//  Phase 6 (partial): daily reminder, streak freezes, privacy trust
//  panel, and About. Plus / sharing sections arrive with later phases.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var notifications: NotificationManager
    @ObservedObject var stats: Stats
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily reminder", isOn: Binding(
                        get: { notifications.reminderEnabled },
                        set: { notifications.setEnabled($0, burstDoneToday: stats.isBurstDoneToday) }
                    ))
                    .tint(Theme.safelight)

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
                        .foregroundColor(Theme.safelight)
                    }
                } header: {
                    Text("Daily reminder")
                } footer: {
                    Text("At most one gentle nudge a day, only if you haven’t played. Off anytime.")
                }

                Section {
                    HStack {
                        Image(systemName: "snowflake")
                            .foregroundColor(Theme.safelight)
                        Text("Freezes ready")
                        Spacer()
                        Text("\(stats.freezes)")
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundColor(Theme.pencil)
                    }
                } header: {
                    Text("Streak")
                } footer: {
                    Text("Earn a freeze every 7-day streak. If you miss a day, a freeze is used automatically to keep your streak alive.")
                }

                Section("Privacy") {
                    trustRow(icon: "iphone", text: "Everything stays on this iPhone")
                    trustRow(icon: "icloud.slash", text: "Your photos are never uploaded")
                    trustRow(icon: "checkmark.shield", text: "Deletions are always yours to confirm")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(Theme.pencil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundColor(Theme.safelight)
                }
            }
        }
    }

    private func trustRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.safelight)
                .frame(width: 24)
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
