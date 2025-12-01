import SwiftUI

struct VolumetricDebugPanel: View {
    @ObservedObject var viewModel: DebugViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var previousDragValue: CGSize = .zero

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "hand.draw.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Debug Panel")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }

            VStack(spacing: 12) {
                HStack {
                    Button(action: {
                        viewModel.togglePause()
                    }) {
                        HStack {
                            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            Text(viewModel.isPaused ? "Play" : "Pause")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }

                StatRow(label: "FPS", value: String(format: "%.1f", viewModel.fps))
                StatRow(label: "Entities", value: "\(viewModel.entityCount)")
                StatRow(label: "Battery", value: String(format: "%.0f%%", viewModel.batteryLevel * 100))

                Toggle("Reduced Motion", isOn: Binding(
                    get: { viewModel.reducedMotion },
                    set: { _ in viewModel.toggleReducedMotion() }
                ))
                .toggleStyle(.switch)
            }
            .padding(.vertical, 8)

            Divider()

            VStack(spacing: 12) {
                Button(action: {
                    viewModel.showNiceList = true
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Nice List")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    viewModel.showNaughtyList = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Naughty List")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .offset(dragOffset)
        .highPriorityGesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = CGSize(
                        width: previousDragValue.width + value.translation.width,
                        height: previousDragValue.height + value.translation.height
                    )
                }
                .onEnded { value in
                    previousDragValue = dragOffset
                }
        )
        .zIndex(1000)
        .sheet(isPresented: $viewModel.showNiceList) {
            TweetListView(isNice: true, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showNaughtyList) {
            TweetListView(isNice: false, viewModel: viewModel)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }
}
