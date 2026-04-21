import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var showLiked = false

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard  = Color(red: 0.110, green: 0.110, blue: 0.110)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)
    private let onPrimary = Color(red: 0.063, green: 0, blue: 0.663)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    likedTracksCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if playerVM.likedTracks.isEmpty {
                        voidDetected
                            .padding(.horizontal, 16)
                    }

                    playlistsSection
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showLiked) {
            LikedTracksView().environmentObject(playerVM)
        }
    }

    // MARK: - Liked tracks card

    private var likedTracksCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Artwork background: mosaic for 4+ tracks, single fill otherwise
            Group {
                if playerVM.likedTracks.count >= 4 {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                        ForEach(playerVM.likedTracks.prefix(4)) { t in
                            AsyncImage(url: URL(string: t.highResArtworkURL ?? "")) { img in
                                img.resizable().aspectRatio(1, contentMode: .fill)
                            } placeholder: { bgCard }
                        }
                    }
                } else if let url = URL(string: playerVM.likedTracks.first?.highResArtworkURL ?? "") {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { bgCard }
                } else {
                    bgCard
                }
            }

            // Gradient overlay
            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIKED\nTRACKS")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                    Text(String(playerVM.likedTracks.count) + " CURATED MASTERPIECES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(primary.opacity(0.8))
                        .kerning(1.5)
                }
                Spacer()
                Button {
                    guard !playerVM.likedTracks.isEmpty else { return }
                    let shuffled = playerVM.likedTracks.shuffled()
                    playerVM.playFromList(shuffled, startingWith: shuffled[0])
                    playerVM.showingNowPlaying = true
                } label: {
                    ZStack {
                        Circle().fill(primary).frame(width: 44, height: 44)
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(onPrimary)
                    }
                }
                .opacity(playerVM.likedTracks.isEmpty ? 0.4 : 1)
                .disabled(playerVM.likedTracks.isEmpty)
            }
            .padding(20)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { if !playerVM.likedTracks.isEmpty { showLiked = true } }
    }

    // MARK: - Void detected empty state

    private var voidDetected: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .strokeBorder(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [6]))
                .frame(height: 160)

            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06)).frame(width: 56, height: 56)
                    Image(systemName: "heart")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.25))
                }
                Text("VOID DETECTED")
                    .font(.system(size: 13, weight: .black)).kerning(2)
                    .foregroundStyle(.white.opacity(0.5))
                Text("YOUR COLLECTION IS CURRENTLY EMPTY.\nINITIALIZE BY LIKING TRACKS.")
                    .font(.system(size: 9, weight: .bold)).kerning(1)
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Playlists section (stub)

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PLAYLISTS")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button {} label: {
                    Text("CREATE NEW +")
                        .font(.system(size: 10, weight: .black)).kerning(1)
                        .foregroundStyle(primary)
                }
            }

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                .frame(height: 80)
                .overlay(
                    Text("NO PLAYLISTS YET")
                        .font(.system(size: 10, weight: .black)).kerning(2)
                        .foregroundStyle(.white.opacity(0.2))
                )
        }
    }
}

// MARK: - Liked tracks full list

struct LikedTracksView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) var dismiss

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        NavigationStack {
            List(playerVM.likedTracks) { track in
                TrackRowView(track: track)
                    .environmentObject(playerVM)
                    .onTapGesture {
                        playerVM.playFromList(playerVM.likedTracks, startingWith: track)
                        playerVM.showingNowPlaying = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            playerVM.toggleLike(track)
                        } label: {
                            Label("Unlike", systemImage: "heart.slash")
                        }
                    }
                    .listRowBackground(bg)
                    .listRowSeparatorTint(Color.white.opacity(0.06))
            }
            .listStyle(.plain)
            .background(bg.ignoresSafeArea())
            .navigationTitle("LIKED TRACKS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationBackground(bg)
    }
}
