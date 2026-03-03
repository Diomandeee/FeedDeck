import ComposableArchitecture
import Foundation
import OpenClawCore
import OpenClawTCA

@Reducer
struct FeedAggregatorFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        var feedMessages: [HubMessage] = []
        var feedThreads: [HubThread] = []
        var activeCategories: Set<String> = []
        var isLoading = false
        var error: String? = nil

        var filteredMessages: [HubMessage] {
            if activeCategories.isEmpty {
                return feedMessages
            }
            let activeCategoryThreadIds = Set(
                feedThreads
                    .filter { activeCategories.contains($0.category) }
                    .map(\.id)
            )
            return feedMessages.filter { activeCategoryThreadIds.contains($0.threadId) }
        }
    }

    enum Action: Sendable, Equatable {
        case onAppear
        case loadFeedThreads
        case feedThreadsLoaded([HubThread])
        case loadFeedMessages
        case feedMessagesLoaded([HubMessage])
        case loadFailed(String)
        case toggleCategory(String)
        case clearFilters
        case newFeedMessage(HubMessage)
        case startListening
    }

    @Dependency(\.hubClient) var hubClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.loadFeedThreads),
                    .send(.startListening)
                )

            case .loadFeedThreads:
                state.isLoading = true
                return .run { send in
                    do {
                        let threads = try await hubClient.fetchThreads(nil, .feed, 50)
                        await send(.feedThreadsLoaded(threads))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .feedThreadsLoaded(threads):
                state.feedThreads = threads
                return .send(.loadFeedMessages)

            case .loadFeedMessages:
                let threadIds = state.feedThreads.map(\.id)
                return .run { send in
                    do {
                        var allMessages: [HubMessage] = []
                        for threadId in threadIds {
                            let messages = try await hubClient.fetchMessages(threadId, 20, nil)
                            allMessages.append(contentsOf: messages)
                        }
                        allMessages.sort { $0.createdAt > $1.createdAt }
                        await send(.feedMessagesLoaded(Array(allMessages.prefix(100))))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .feedMessagesLoaded(messages):
                state.isLoading = false
                state.feedMessages = messages
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                state.error = error
                return .none

            case let .toggleCategory(category):
                if state.activeCategories.contains(category) {
                    state.activeCategories.remove(category)
                } else {
                    state.activeCategories.insert(category)
                }
                return .none

            case .clearFilters:
                state.activeCategories.removeAll()
                return .none

            case let .newFeedMessage(message):
                guard !state.feedMessages.contains(where: { $0.id == message.id }) else {
                    return .none
                }
                state.feedMessages.insert(message, at: 0)
                if state.feedMessages.count > 100 {
                    state.feedMessages = Array(state.feedMessages.prefix(100))
                }
                return .none

            case .startListening:
                return .run { send in
                    for await thread in hubClient.subscribeToThreadUpdates() {
                        if thread.type == .feed {
                            let messages = try await hubClient.fetchMessages(thread.id, 1, nil)
                            if let latest = messages.first {
                                await send(.newFeedMessage(latest))
                            }
                        }
                    }
                }
            }
        }
    }
}
