import SwiftUI

// MARK: – Overlay -------------------------------------------------------------

struct VoiceRecorderOverlay: View {
    @Binding var amplitude: CGFloat          // 0…1
    @Binding var dragOffset: CGSize          // смещение пальца
    var transcript: String = ""
    var fadeProgress: CGFloat                // 0…1

    // минимальные размеры
    private let minScaleOuter:  CGFloat = 0.60
    private let minScaleMiddle: CGFloat = 0.70
    private let minScaleInner:  CGFloat = 0.80

    // MARK: – Предвычисленные scale-ы ----------------------------------------

    private var outerScale:  CGFloat {
        (minScaleOuter  + (1 - minScaleOuter)  * fadeProgress) * (1 + amplitude * 0.80)
    }
    private var middleScale: CGFloat {
        (minScaleMiddle + (1 - minScaleMiddle) * fadeProgress) * (1 + amplitude * 0.50)
    }
    private var innerScale:  CGFloat {
        minScaleInner + (1 - minScaleInner) * fadeProgress
    }

    // MARK: – Тело ------------------------------------------------------------

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            caption
            cancelHint

            circles
                .opacity(fadeProgress)
                .animation(.easeInOut(duration: 0.25), value: fadeProgress)
        }
    }

    // MARK: – Под-view-ы ------------------------------------------------------

    private var caption: some View {
        VStack {
            if !transcript.isEmpty {
                Text(transcript)
                    .foregroundStyle(.primary)
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.9),
                               value: transcript)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 180)
    }

    private var cancelHint: some View {
        let verticalOffset: CGFloat = 60  // 🔽 смещение ниже
        let extraLeftPadding: CGFloat = 12 // ⬅️ доп. отступ слева

        return Text(LocalizedStringKey("voiceRecorder.swipeLeftCancel"))
            .font(.footnote)
            .foregroundColor(Color.gray.opacity(0.6))
            .offset(x: dragOffset.width * 0.1, y: -verticalOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20 + extraLeftPadding)
    }

    private var circles: some View {
        ZStack {
            // внешнее
            Circle()
                .fill(
                    LinearGradient(colors: [.blue.opacity(0.30),
                                            .white.opacity(0.08)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .frame(width: 130, height: 130)
                .scaleEffect(outerScale)
                .animation(.interpolatingSpring(stiffness: 80, damping: 3), value: fadeProgress)
                .animation(.linear(duration: 0.05), value: amplitude)

            // среднее
            Circle()
                .fill(
                    LinearGradient(colors: [.cyan.opacity(0.20),
                                            .white.opacity(0.05)],
                                   startPoint: .bottomLeading,
                                   endPoint: .topTrailing)
                )
                .frame(width: 110, height: 110)
                .scaleEffect(middleScale)
                .animation(.interpolatingSpring(stiffness: 100, damping: 5), value: fadeProgress)
                .animation(.linear(duration: 0.05), value: amplitude)

            // внутреннее + иконка
            Circle()
                .fill(
                    LinearGradient(colors: [.blue,
                                            .white.opacity(0.30)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .overlay(
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                )
                .frame(width: 80, height: 80)
                .scaleEffect(innerScale)
                .animation(.interpolatingSpring(stiffness: 160, damping: 10), value: fadeProgress)
        }
    }
}

// MARK: – Preview -------------------------------------------------------------

#Preview {
    VoiceRecorderPreviewWrapper()
}

// MARK: – Preview wrapper -----------------------------------------------------

struct VoiceRecorderPreviewWrapper: View {
    @State private var amplitude: CGFloat = 0
    @State private var fadeProgress: CGFloat = 0
    @State private var dragOffset: CGSize = .zero
    @State private var timer: Timer?

    var body: some View {
        VoiceRecorderOverlay(
            amplitude: $amplitude,
            dragOffset: $dragOffset,
            transcript: "Пример живой транскрипции – Светлая тема",
            fadeProgress: fadeProgress
        )
        .preferredColorScheme(.light)
        .onAppear {
            fadeProgress = 1

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                withAnimation(.linear(duration: 0.05)) {
                    amplitude = .random(in: 0...1)
                    dragOffset.width = CGFloat.random(in: -100...0)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
}
