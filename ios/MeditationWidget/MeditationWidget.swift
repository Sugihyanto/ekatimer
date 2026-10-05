//
//  MeditationWidget.swift
//  MeditationWidget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct QuickStartEntry: TimelineEntry {
    let date: Date
    let label: String
    let timerMode: String
    let durationMinutes: Int
}

// MARK: - Provider

struct QuickStartProvider: TimelineProvider {
    let label: String
    let timerMode: String
    let durationMinutes: Int

    func placeholder(in context: Context) -> QuickStartEntry {
        QuickStartEntry(date: Date(), label: label, timerMode: timerMode, durationMinutes: durationMinutes)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        completion(QuickStartEntry(date: Date(), label: label, timerMode: timerMode, durationMinutes: durationMinutes))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        let entry = QuickStartEntry(date: Date(), label: label, timerMode: timerMode, durationMinutes: durationMinutes)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Widget View

struct QuickStartWidgetView: View {
    let entry: QuickStartEntry

    private var widgetUrl: URL? {
        var components = URLComponents()
        components.scheme = "ekatimer"
        components.host = "start"
        components.queryItems = [
            URLQueryItem(name: "mode", value: entry.timerMode),
            URLQueryItem(name: "duration", value: "\(entry.durationMinutes)")
        ]
        return components.url
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.36, blue: 0.53),
                Color(red: 0.05, green: 0.22, blue: 0.33)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var durationText: String {
        entry.label == "∞" ? "∞" : entry.label
    }

    private var timerIcon: some View {
        Image("WidgetTimerIcon")
            .resizable()
            .scaledToFit()
    }

    private var playBadge: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(.white.opacity(0.20))
                    .overlay(Circle().stroke(.white.opacity(0.80), lineWidth: 1))
            )
    }

    private var mediumContent: some View {
        HStack(spacing: 12) {
            timerIcon
                .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 3) {
                Text("Meditation Timer")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("FOCUS • BREATHE • GROW")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("Meditation")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.10))
                                .overlay(Capsule().stroke(.white.opacity(0.38), lineWidth: 1))
                        )

                    Text(durationText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
            playBadge
        }
    }

    var body: some View {
        let content = mediumContent
        .padding(14)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
        .widgetURL(widgetUrl)

        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    Color.clear
                }
        } else {
            ZStack {
                cardGradient.ignoresSafeArea()
                content
            }
        }
    }
}

// MARK: - Individual Quick-Start Widgets

struct Meditation15mWidget: Widget {
    let kind: String = "Meditation15mWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "15m", timerMode: "timed", durationMinutes: 15)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("15m Meditation")
        .description("Start a 15-minute meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation30mWidget: Widget {
    let kind: String = "Meditation30mWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "30m", timerMode: "timed", durationMinutes: 30)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("30m Meditation")
        .description("Start a 30-minute meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation1HWidget: Widget {
    let kind: String = "Meditation1HWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "1H", timerMode: "timed", durationMinutes: 60)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("1H Meditation")
        .description("Start a 1-hour meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation1_5HWidget: Widget {
    let kind: String = "Meditation1_5HWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "1.5H", timerMode: "timed", durationMinutes: 90)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("1.5H Meditation")
        .description("Start a 1.5-hour meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation2HWidget: Widget {
    let kind: String = "Meditation2HWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "2H", timerMode: "timed", durationMinutes: 120)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("2H Meditation")
        .description("Start a 2-hour meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation2_5HWidget: Widget {
    let kind: String = "Meditation2_5HWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "2.5H", timerMode: "timed", durationMinutes: 150)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("2.5H Meditation")
        .description("Start a 2.5-hour meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation3HWidget: Widget {
    let kind: String = "Meditation3HWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "3H", timerMode: "timed", durationMinutes: 180)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("3H Meditation")
        .description("Start a 3-hour meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation3_5HWidget: Widget {
    let kind: String = "Meditation3_5HWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "3.5H", timerMode: "timed", durationMinutes: 210)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("3.5H Meditation")
        .description("Start a 3.5-hour meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct Meditation4HWidget: Widget {
    let kind: String = "Meditation4HWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "4H", timerMode: "timed", durationMinutes: 240)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("4H Meditation")
        .description("Start a 4-hour meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct MeditationEndAtWidget: Widget {
    let kind: String = "MeditationEndAtWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "End at", timerMode: "endAt", durationMinutes: 0)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("End At Meditation")
        .description("Set an end time for your meditation.")
        .supportedFamilies([.systemMedium])
    }
}

struct MeditationUnlimitedWidget: Widget {
    let kind: String = "MeditationUnlimitedWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider(label: "∞", timerMode: "unlimited", durationMinutes: 0)) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("Unlimited Meditation")
        .description("Meditate without a time limit.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    Meditation1HWidget()
} timeline: {
    QuickStartEntry(date: Date(), label: "1H", timerMode: "timed", durationMinutes: 60)
}
