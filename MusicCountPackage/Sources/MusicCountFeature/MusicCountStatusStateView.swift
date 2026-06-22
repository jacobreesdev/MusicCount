import SwiftUI

struct MusicCountLoadingStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct MusicCountUnavailableStateView<Action: View>: View {
    let title: String
    let message: String
    let systemImage: String
    let color: Color
    @ViewBuilder let action: Action

    init(
        title: String,
        message: String,
        systemImage: String,
        color: Color,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.color = color
        self.action = action()
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 80))
                .foregroundStyle(color)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            action
        }
        .padding()
    }
}

extension MusicCountUnavailableStateView where Action == EmptyView {
    init(
        title: String,
        message: String,
        systemImage: String,
        color: Color
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.color = color
        self.action = EmptyView()
    }
}
