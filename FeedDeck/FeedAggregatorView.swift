import SwiftUI
import ComposableArchitecture
import OpenClawCore

struct FeedAggregatorView: View {
    @Bindable var store: StoreOf<FeedAggregatorFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: "All",
                            isActive: store.activeCategories.isEmpty,
                            color: .indigo
                        ) {
                            store.send(.clearFilters)
                        }

                        ForEach(store.feedThreads, id: \.id) { thread in
                            FilterChip(
                                label: thread.category,
                                icon: ThreadCategory(rawValue: thread.category)?.icon,
                                isActive: store.activeCategories.contains(thread.category),
                                color: categoryColor(thread.category)
                            ) {
                                store.send(.toggleCategory(thread.category))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.bar)

                Divider()

                // Feed timeline
                if store.isLoading && store.feedMessages.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView("Loading feeds...")
                        Spacer()
                    }
                } else if store.filteredMessages.isEmpty {
                    ContentUnavailableView(
                        "No Feed Messages",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Feed messages from flows will appear here as they post.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.filteredMessages) { message in
                                FeedMessageRow(
                                    message: message,
                                    thread: store.feedThreads.first(where: { $0.id == message.threadId })
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Feeds")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(store.filteredMessages.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .refreshable { store.send(.loadFeedThreads) }
            .task { store.send(.onAppear) }
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "heartbeat": return .red
        case "service-health": return .orange
        case "node-health": return .yellow
        case "morning-brief": return .blue
        case "memory-log": return .teal
        case "chronicles": return .purple
        case "blooms": return .pink
        case "weekly-review": return .indigo
        case "serenity": return .mint
        case "dispatch": return .orange
        default: return .gray
        }
    }
}

// MARK: - Feed Message Row

struct FeedMessageRow: View {
    let message: HubMessage
    let thread: HubThread?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: categoryIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(categoryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(message.senderLabel ?? message.senderType.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(senderColor)

                        if let thread {
                            Text(thread.category)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Text(message.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if message.contentType == .embed, let embed = message.embedData {
                        FeedEmbedCard(embed: embed)
                    } else {
                        Text(message.content)
                            .font(.subheadline)
                            .lineLimit(4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 62)
        }
    }

    private var categoryColor: Color {
        guard let cat = thread?.category else { return .gray }
        switch cat {
        case "heartbeat": return .red
        case "service-health": return .orange
        case "node-health": return .yellow
        case "morning-brief": return .blue
        case "memory-log": return .teal
        case "chronicles": return .purple
        case "blooms": return .pink
        case "weekly-review": return .indigo
        case "serenity": return .mint
        default: return .gray
        }
    }

    private var categoryIcon: String {
        guard let cat = thread?.category,
              let tc = ThreadCategory(rawValue: cat) else { return "list.bullet" }
        return tc.icon
    }

    private var senderColor: Color {
        switch message.senderType {
        case .flow: return .green
        case .system: return .gray
        case .pulse: return .purple
        case .dispatch: return .orange
        case .agent: return .indigo
        case .human: return .blue
        }
    }
}

// MARK: - Feed Embed Card

struct FeedEmbedCard: View {
    let embed: EmbedData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = embed.title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            if let desc = embed.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let fields = embed.fields, !fields.isEmpty {
                let inlineFields = fields.filter { $0.inline == true }
                let blockFields = fields.filter { $0.inline != true }

                if !inlineFields.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 6) {
                        ForEach(inlineFields, id: \.name) { field in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(field.name)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text(field.value)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                ForEach(blockFields, id: \.name) { field in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(field.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(field.value)
                            .font(.system(size: 11))
                    }
                }
            }
            if let footer = embed.footer {
                Text(footer)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(alignment: .leading) {
                    if let color = embed.color {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: color))
                            .frame(width: 3)
                    }
                }
        }
    }
}
