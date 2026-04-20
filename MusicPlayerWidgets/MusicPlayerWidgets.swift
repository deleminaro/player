import WidgetKit
import SwiftUI
import ActivityKit

private let wPrimary   = Color(red: 0.753, green: 0.757, blue: 1.0)
private let wBg        = Color(red: 0.075, green: 0.075, blue: 0.075)
private let wOnPrimary = Color(red: 0.063, green: 0.000, blue: 0.663)
private let wSuite     = "group.com.ivansolomakha.musicplayer"

// MARK: - Home Screen Widget

struct MusicEntry: TimelineEntry {
    let date:       Date
    let title:      String
    let artist:     String
    let artworkURL: String?
}

struct MusicProvider: TimelineProvider {
    private var def: UserDefaults? { UserDefaults(suiteName: wSuite) }

    func placeholder(in context: Context) -> MusicEntry {
        MusicEntry(date: .now, title: "TRACK TITLE", artist: "ARTIST", artworkURL: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        completion(entry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .atEnd))
    }
    private func entry() -> MusicEntry {
        MusicEntry(date: .now,
                   title:      def?.string(forKey: "widget_title")   ?? "Nothing Playing",
                   artist:     def?.string(forKey: "widget_artist")  ?? "",
                   artworkURL: def?.string(forKey: "widget_artwork"))
    }
}

struct MusicWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: MusicEntry

    var body: some View {
        ZStack {
            wBg
            if let u = entry.artworkURL, let url = URL(string: u) {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                        .blur(radius: 20).opacity(0.22).scaleEffect(1.4)
                } placeholder: { Color.clear }
            }
            Color.black.opacity(0.5)
            if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .widgetURL(URL(string: "musicplayer://open"))
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer()
            artwork(size: 44, radius: 8)
            Text(entry.title.uppercased())
                .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                .lineLimit(2).kerning(-0.3)
            Text(entry.artist.uppercased())
                .font(.system(size: 8, weight: .bold)).foregroundStyle(wPrimary)
                .kerning(1).lineLimit(1)
        }
        .padding(12)
    }

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            artwork(size: 80, radius: 12)
                .shadow(color: .black.opacity(0.5), radius: 12)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title.uppercased())
                    .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    .lineLimit(2).kerning(-0.3)
                Text(entry.artist.uppercased())
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(wPrimary)
                    .kerning(1.5).lineLimit(1)
                Image(systemName: "waveform")
                    .font(.system(size: 14)).foregroundStyle(wPrimary.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private func artwork(size: CGFloat, radius: CGFloat) -> some View {
        if let u = entry.artworkURL, let url = URL(string: u) {
            AsyncImage(url: url) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: radius).fill(Color.white.opacity(0.1))
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius))
        }
    }
}

struct MusicHomeWidget: Widget {
    let kind = "MusicWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicProvider()) { entry in
            MusicWidgetView(entry: entry)
                .containerBackground(wBg, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the currently playing track.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Dynamic Island / Live Activity

struct MusicLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicActivityAttributes.self) { ctx in
            HStack(spacing: 14) {
                if let url = URL(string: ctx.state.artworkURL) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(ctx.state.title.uppercased())
                        .font(.system(size: 13, weight: .black)).foregroundStyle(.white).lineLimit(1)
                    Text(ctx.state.artist.uppercased())
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(wPrimary)
                        .kerning(1).lineLimit(1)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
                            Capsule().fill(wPrimary)
                                .frame(width: g.size.width * ctx.state.progress, height: 3)
                        }
                    }.frame(height: 3)
                }
                Spacer()
                Image(systemName: ctx.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22)).foregroundStyle(.white)
            }
            .padding(16)
            .activityBackgroundTint(wBg)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let url = URL(string: ctx.state.artworkURL) {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.leading, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ctx.state.title.uppercased())
                            .font(.system(size: 11, weight: .black)).foregroundStyle(.white).lineLimit(1)
                        Text(ctx.state.artist.uppercased())
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(wPrimary)
                            .kerning(1).lineLimit(1)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12)).frame(height: 2)
                                Capsule().fill(wPrimary)
                                    .frame(width: g.size.width * ctx.state.progress, height: 2)
                            }
                        }.frame(height: 2).padding(.top, 2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: ctx.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                        .padding(.trailing, 4)
                }
            } compactLeading: {
                if let url = URL(string: ctx.state.artworkURL) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { Circle().fill(Color.white.opacity(0.1)) }
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } compactTrailing: {
                Image(systemName: ctx.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12)).foregroundStyle(wPrimary)
            } minimal: {
                if let url = URL(string: ctx.state.artworkURL) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { Circle().fill(Color.white.opacity(0.1)) }
                    .frame(width: 20, height: 20).clipShape(Circle())
                }
            }
            .widgetURL(URL(string: "musicplayer://open"))
        }
    }
}

// MARK: - Bundle

@main
struct MusicPlayerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MusicHomeWidget()
        MusicLiveActivityWidget()
    }
}
