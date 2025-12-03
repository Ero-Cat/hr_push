import ActivityKit
import SwiftUI
import WidgetKit

// Must match the name expected by the live_activities plugin.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    // Data coming directly from Flutter via the plugin. No app group needed.
    public struct ContentState: Codable, Hashable {
        var bpm: Int
        var status: String
        var updatedAt: Double // milliseconds since epoch
    }

    var id = UUID()
}

struct HeartRateLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let bpm = context.state.bpm
            let status = context.state.status
            let updatedAt = Date(timeIntervalSince1970: context.state.updatedAt / 1000)

            VStack(alignment: .leading, spacing: 6) {
                Text("心率")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(bpm)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.65), Color.pink.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } dynamicIsland: { context in
            let bpm = context.state.bpm
            let status = context.state.status

            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 12) {
                        Text("\(bpm)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BPM")
                                .font(.headline)
                            Text(status)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Text("\(bpm)")
                    .font(.headline)
            } compactTrailing: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            } minimal: {
                Text("\(bpm)")
                    .font(.footnote)
            }
        }
    }
}

@main
struct HeartRateLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 16.1, *) {
            HeartRateLiveActivity()
        }
    }
}
