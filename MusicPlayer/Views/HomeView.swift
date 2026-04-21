import SwiftUI

struct HomeView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showArchive = false

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard  = Color(red: 0.110, green: 0.110, blue: 0.110)

    private var featured: Track? { playerVM.recentlyPlayed.first }
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if !playerVM.recentlyPlayed.isEmpty {
                        recentSection
                            .padding(.top, 32)
                    } else {
                        emptyHero
                            .padding(.top, 48)
                    }
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 6) {
                        Text("P")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(themeManager.current.primary)
                            .padding(6)
                            .background(themeManager.current.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        Text("POSTOR.")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                            .kerning(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
        }
        .sheet(isPresented: $showArchive) {
            RecentlyPlayedView().environmentObject(playerVM)
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Full artwork fill
            Group {
                if let url = URL(string: featured?.highResArtworkURL ?? "") {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        bgCard
                    }
                } else {
                    bgCard
                }
            }

            // Gradient for text legibility
            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("FEATURED RELEASE / " + String(Calendar.current.component(.year, from: Date())))
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(themeManager.current.primary.opacity(0.8))
                    .kerning(2)

                Text(featured != nil
                     ? featured!.title.uppercased()
                     : "YOUR\nMUSIC.")
                    .font(.system(size: featured != nil ? 22 : 30, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        if let t = playerVM.recentlyPlayed.first {
                            playerVM.addToQueue(t)
                            playerVM.play(t)
                            playerVM.showingNowPlaying = true
                        }
                    } label: {
                        Text("PLAY RECENT")
                            .font(.system(size: 11, weight: .black)).kerning(1)
                            .foregroundStyle(themeManager.current.onPrimary)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(themeManager.current.primary, in: Capsule())
                    }
                    .opacity(featured == nil ? 0.4 : 1)
                    .disabled(featured == nil)

                    Button { showArchive = true } label: {
                        Text("VIEW ARCHIVE")
                            .font(.system(size: 11, weight: .black)).kerning(1)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(Color.white.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Recently played grid

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECENTLY PLAYED")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                    Text("YOUR LATEST SESSIONS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(1.5)
                }
                Spacer()
                Button { showArchive = true } label: {
                    Text("VIEW ALL [\(playerVM.recentlyPlayed.count)]")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(themeManager.current.primary)
                        .kerning(0.5)
                }
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(playerVM.recentlyPlayed.prefix(6)) { track in
                    RecentTrackCard(track: track)
                        .onTapGesture {
                            playerVM.addToQueue(track)
                            playerVM.play(track)
                            playerVM.showingNowPlaying = true
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty state

    private var emptyHero: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(themeManager.current.primary.opacity(0.4))
            Text("NOTHING YET")
                .font(.system(size: 14, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.5))
            Text("Search for tracks to get started.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Recent track card

struct RecentTrackCard: View {
    let track: Track
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: track.highResArtworkURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.15))
                    )
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.username.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(themeManager.current.primary)
                    .kerning(1)
                    .lineLimit(1)
            }
        }
    }
}
