import SwiftUI

struct SuggestionRepairView: View {
    let suggestion: Suggestion
    let onDismiss: () -> Void

    @Environment(AppleMusicQueueService.self) private var queueService
    @Environment(SuggestionsService.self) private var suggestionsService
    @State private var model: SuggestionRepairModel
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    init(suggestion: Suggestion, onDismiss: @escaping () -> Void) {
        self.suggestion = suggestion
        self.onDismiss = onDismiss

        do {
            _model = State(initialValue: try SuggestionRepairModel(suggestion: suggestion))
        } catch {
            preconditionFailure("Suggestion must support a default repair decision: \(error)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summarySection
                canonicalSongSection
                retiredSongsSection
                repairQueueSection
            }
            .padding()
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.SuggestionRepair.scrollView)
        .navigationTitle("Repair Suggestion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onDismiss()
                }
            }
        }
        .alert("Repair Queue Built", isPresented: $showingSuccessAlert) {
            Button("OK") {
                onDismiss()
            }
        } message: {
            Text("\(model.repairAmount.formatted()) plays for \(model.canonicalSong.title) have been added to your Apple Music queue.")
        }
        .alert("Unable to Build Repair Queue", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.sharedTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(suggestion.sharedArtist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                SummaryPill(
                    title: suggestion.versionCount,
                    systemImage: "square.stack.3d.up.fill",
                    color: .blue
                )
                SummaryPill(
                    title: "\(model.repairAmount.formatted()) plays",
                    systemImage: "play.circle.fill",
                    color: .green
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var canonicalSongSection: some View {
        RepairSection(title: "Canonical Song", systemImage: "checkmark.seal.fill") {
            VStack(spacing: 10) {
                ForEach(model.songs) { song in
                    Button {
                        chooseCanonicalSong(song)
                    } label: {
                        RepairSongChoiceRow(
                            song: song,
                            role: model.role(for: song),
                            isCanonical: song.id == model.canonicalSong.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityIdentifiers.SuggestionRepair.canonicalSongButton(id: song.id))
                    .accessibilityLabel(accessibilityLabel(for: song))
                    .accessibilityHint("Choose as Canonical Song")
                    .accessibilityAddTraits(song.id == model.canonicalSong.id ? .isSelected : [])
                }
            }
        }
    }

    private var retiredSongsSection: some View {
        RepairSection(title: "Retired Songs", systemImage: "tray.and.arrow.down.fill") {
            VStack(spacing: 10) {
                ForEach(model.songs.filter { $0.id != model.canonicalSong.id }) { song in
                    Toggle(isOn: retiredBinding(for: song)) {
                        RepairSongToggleLabel(song: song, role: model.role(for: song))
                    }
                    .toggleStyle(.switch)
                    .disabled(isLastRetiredSong(song))
                    .padding(12)
                    .background(.regularMaterial, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier(AccessibilityIdentifiers.SuggestionRepair.retiredSongToggle(id: song.id))
                    .accessibilityLabel(accessibilityLabel(for: song))
                    .accessibilityValue(model.role(for: song).accessibilityLabel)
                }
            }
        }
    }

    private var repairQueueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            RepairSectionHeader(title: "Repair Amount", systemImage: "music.note.list")

            VStack(alignment: .leading, spacing: 12) {
                Label(model.canonicalSong.title, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.primary)

                Label("\(model.retiredSongs.count) Retired Songs", systemImage: "tray.fill")
                    .foregroundStyle(.secondary)

                Label("\(model.repairAmount.formatted()) plays", systemImage: "play.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Button {
                buildRepairQueue()
            } label: {
                Label("Build Repair Queue", systemImage: "music.note.list")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.canBuildRepairQueue == false)
            .accessibilityIdentifier(AccessibilityIdentifiers.SuggestionRepair.buildRepairQueueButton)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }

    private func retiredBinding(for song: SongInfo) -> Binding<Bool> {
        Binding {
            model.isIncludedAsRetired(songID: song.id)
        } set: { isIncluded in
            do {
                try model.setIncludedAsRetired(isIncluded, forSongID: song.id)
            } catch {
                errorMessage = errorMessage(for: error)
                showingErrorAlert = true
            }
        }
    }

    private func chooseCanonicalSong(_ song: SongInfo) {
        do {
            try model.chooseCanonicalSong(id: song.id)
        } catch {
            errorMessage = errorMessage(for: error)
            showingErrorAlert = true
        }
    }

    private func buildRepairQueue() {
        guard model.canBuildRepairQueue else {
            errorMessage = "A Repair Queue needs at least one play."
            showingErrorAlert = true
            return
        }

        do {
            try queueService.addToQueue(song: model.canonicalSong, count: model.repairAmount)
            _ = try suggestionsService.createActiveRepair(from: model.decision, for: suggestion)
            showingSuccessAlert = true
        } catch let error as AppleMusicQueueService.QueueError {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        } catch let error as ActiveRepairError {
            errorMessage = errorMessage(for: error)
            showingErrorAlert = true
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            showingErrorAlert = true
        }
    }

    private func isLastRetiredSong(_ song: SongInfo) -> Bool {
        model.isIncludedAsRetired(songID: song.id) && model.retiredSongs.count == 1
    }

    private func accessibilityLabel(for song: SongInfo) -> String {
        [
            "\(song.title) by \(song.artist)",
            "album \(song.album)",
            "\(song.playCount.formatted()) plays",
            model.role(for: song).accessibilityLabel,
        ].joined(separator: ", ")
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case RepairDecisionError.requiresAtLeastOneRetiredSong:
            return "At least one Retired Song is required."
        case RepairDecisionError.canonicalSongCannotBeExcluded:
            return "The Canonical Song cannot be retired or excluded."
        case ActiveRepairError.alreadyExists:
            return "This Suggestion already has an Active Repair."
        default:
            return "The repair decision could not be updated."
        }
    }
}

private struct RepairSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RepairSectionHeader(title: title, systemImage: systemImage)
            content
        }
    }
}

private struct RepairSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

private struct SummaryPill: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.12), in: .capsule)
    }
}

private struct RepairSongChoiceRow: View {
    let song: SongInfo
    let role: SuggestionRepairSongRole
    let isCanonical: Bool

    var body: some View {
        RepairSongRowContent(song: song, role: role) {
            Image(systemName: isCanonical ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isCanonical ? .blue : .secondary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(isCanonical ? Color.blue.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCanonical ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
        }
    }
}

private struct RepairSongToggleLabel: View {
    let song: SongInfo
    let role: SuggestionRepairSongRole

    var body: some View {
        RepairSongRowContent(song: song, role: role) {
            EmptyView()
        }
    }
}

private struct RepairSongRowContent<TrailingContent: View>: View {
    let song: SongInfo
    let role: SuggestionRepairSongRole
    @ViewBuilder let trailingContent: TrailingContent

    var body: some View {
        HStack(spacing: 12) {
            RepairArtworkView(image: song.artworkImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(song.album)
                        .foregroundStyle(.secondary)
                    Text("\(song.playCount) plays")
                        .foregroundStyle(.secondary)
                    Text(role.label)
                        .foregroundStyle(role.color)
                }
                .font(.caption)
            }

            Spacer()
            trailingContent
        }
    }
}

private struct RepairArtworkView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityHidden(true)
    }
}

private extension SuggestionRepairSongRole {
    var label: String {
        switch self {
        case .canonical:
            return "Canonical Song"
        case .retired:
            return "Retired Song"
        case .excluded:
            return "Excluded"
        }
    }

    var accessibilityLabel: String {
        label
    }

    var color: Color {
        switch self {
        case .canonical:
            return .blue
        case .retired:
            return .green
        case .excluded:
            return .secondary
        }
    }
}
