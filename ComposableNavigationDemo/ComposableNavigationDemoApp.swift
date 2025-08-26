//
//  ComposableNavigationDemoApp.swift
//  ComposableNavigationDemo
//
//  Created by Christopher Mazile on 8/24/25.
//

import SwiftUI

// MARK: - App Entry Point

@main
struct NavigationDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Pure State Definitions (SDA Pillar I: View as State Machine)

enum AppState: Equatable {
    case browsing(BrowsingState)
    case searching(SearchState)
    case loading(LoadingState)
    
    struct BrowsingState: Equatable {
        let activeTab: Tab
        let navigationPaths: [Tab: [NavigationDestination]]
        var modalPresentation: ModalPresentation?
        var errorMessage: String?
    }
    
    struct SearchState: Equatable {
        let activeTab: Tab
        let query: String
        let isKeyboardVisible: Bool
        let navigationPaths: [Tab: [NavigationDestination]]
        var errorMessage: String?
    }
    
    struct LoadingState: Equatable {
        let activeTab: Tab
        let navigationPaths: [Tab: [NavigationDestination]]
        let context: String
    }
    
    struct ModalPresentation: Equatable {
        let destination: NavigationDestination
        let style: PresentationStyle
    }
}

// State Transitions (Pure Functions)
extension AppState {
    static let initial = AppState.browsing(
        BrowsingState(
            activeTab: .words,
            navigationPaths: Tab.allCases.reduce(into: [:]) { $0[$1] = [] },
            modalPresentation: nil,
            errorMessage: nil
        )
    )
    
    func switchTab(to tab: Tab) -> AppState {
        switch self {
        case .browsing(let state):
            return .browsing(
                BrowsingState(
                    activeTab: tab,
                    navigationPaths: state.navigationPaths,
                    modalPresentation: state.modalPresentation,
                    errorMessage: state.errorMessage
                )
            )
        case .searching:
            // Cancel search when switching tabs
            return .browsing(
                BrowsingState(
                    activeTab: tab,
                    navigationPaths: currentNavigationPaths,
                    modalPresentation: nil,
                    errorMessage: nil
                )
            )
        case .loading(let state):
            return .loading(
                LoadingState(
                    activeTab: tab,
                    navigationPaths: state.navigationPaths,
                    context: state.context
                )
            )
        }
    }
    
    func activateSearch() -> AppState {
        switch self {
        case .browsing(let state):
            return .searching(
                SearchState(
                    activeTab: state.activeTab,
                    query: "",
                    isKeyboardVisible: true,
                    navigationPaths: state.navigationPaths,
                    errorMessage: nil
                )
            )
        case .searching:
            return self // Already searching
        case .loading(let state):
            // Cancel loading and start search
            return .searching(
                SearchState(
                    activeTab: state.activeTab,
                    query: "",
                    isKeyboardVisible: true,
                    navigationPaths: state.navigationPaths,
                    errorMessage: nil
                )
            )
        }
    }
    
    func updateSearchQuery(_ query: String) -> AppState {
        switch self {
        case .searching(let state):
            return .searching(
                SearchState(
                    activeTab: state.activeTab,
                    query: query,
                    isKeyboardVisible: state.isKeyboardVisible,
                    navigationPaths: state.navigationPaths,
                    errorMessage: state.errorMessage
                )
            )
        case .browsing, .loading:
            return self
        }
    }
    
    func dismissSearch() -> AppState {
        switch self {
        case .searching(let state):
            return .browsing(
                BrowsingState(
                    activeTab: state.activeTab,
                    navigationPaths: state.navigationPaths,
                    modalPresentation: nil,
                    errorMessage: state.errorMessage
                )
            )
        case .browsing, .loading:
            return self
        }
    }
    
    func navigate(to destination: NavigationDestination, presentation: PresentationStyle = .push) -> AppState {
        // Navigation cancels search and loading
        let baseState: BrowsingState
        switch self {
        case .browsing(let state):
            baseState = state
        case .searching(let state):
            baseState = BrowsingState(
                activeTab: state.activeTab,
                navigationPaths: state.navigationPaths,
                modalPresentation: nil,
                errorMessage: state.errorMessage
            )
        case .loading(let state):
            baseState = BrowsingState(
                activeTab: state.activeTab,
                navigationPaths: state.navigationPaths,
                modalPresentation: nil,
                errorMessage: nil
            )
        }
        
        switch presentation {
        case .push:
            var paths = baseState.navigationPaths
            var currentPath = paths[baseState.activeTab] ?? []
            currentPath.append(destination)
            paths[baseState.activeTab] = currentPath
            
            return .browsing(
                BrowsingState(
                    activeTab: baseState.activeTab,
                    navigationPaths: paths,
                    modalPresentation: baseState.modalPresentation,
                    errorMessage: baseState.errorMessage
                )
            )
            
        case .sheet, .fullscreen:
            return .browsing(
                BrowsingState(
                    activeTab: baseState.activeTab,
                    navigationPaths: baseState.navigationPaths,
                    modalPresentation: AppState.ModalPresentation(
                        destination: destination,
                        style: presentation
                    ),
                    errorMessage: baseState.errorMessage
                )
            )
        }
    }
    
    // SOLUTION 2: Data Flow Optimization - Pure function for navigation path updates
    func updateNavigationPath(_ newPath: [NavigationDestination], for tab: Tab) -> AppState {
        var paths = currentNavigationPaths
        paths[tab] = newPath
        
        switch self {
        case .browsing(let state):
            return .browsing(
                BrowsingState(
                    activeTab: state.activeTab,
                    navigationPaths: paths,
                    modalPresentation: state.modalPresentation,
                    errorMessage: state.errorMessage
                )
            )
        case .searching(let state):
            return .searching(
                SearchState(
                    activeTab: state.activeTab,
                    query: state.query,
                    isKeyboardVisible: state.isKeyboardVisible,
                    navigationPaths: paths,
                    errorMessage: state.errorMessage
                )
            )
        case .loading(let state):
            return .loading(
                LoadingState(
                    activeTab: state.activeTab,
                    navigationPaths: paths,
                    context: state.context
                )
            )
        }
    }
    
    func setError(_ message: String) -> AppState {
        switch self {
        case .browsing(let state):
            return .browsing(
                BrowsingState(
                    activeTab: state.activeTab,
                    navigationPaths: state.navigationPaths,
                    modalPresentation: state.modalPresentation,
                    errorMessage: message
                )
            )
        case .searching(let state):
            return .searching(
                SearchState(
                    activeTab: state.activeTab,
                    query: state.query,
                    isKeyboardVisible: state.isKeyboardVisible,
                    navigationPaths: state.navigationPaths,
                    errorMessage: message
                )
            )
        case .loading(let state):
            return .browsing(
                BrowsingState(
                    activeTab: state.activeTab,
                    navigationPaths: state.navigationPaths,
                    modalPresentation: nil,
                    errorMessage: message
                )
            )
        }
    }
    
    func clearError() -> AppState {
        switch self {
        case .browsing(let state):
            return .browsing(
                BrowsingState(
                    activeTab: state.activeTab,
                    navigationPaths: state.navigationPaths,
                    modalPresentation: state.modalPresentation,
                    errorMessage: nil
                )
            )
        case .searching(let state):
            return .searching(
                SearchState(
                    activeTab: state.activeTab,
                    query: state.query,
                    isKeyboardVisible: state.isKeyboardVisible,
                    navigationPaths: state.navigationPaths,
                    errorMessage: nil
                )
            )
        case .loading:
            return self
        }
    }
    
    func setLoading(context: String) -> AppState {
        return .loading(
            LoadingState(
                activeTab: currentTab,
                navigationPaths: currentNavigationPaths,
                context: context
            )
        )
    }
    
    // Computed properties for easy access
    var currentTab: Tab {
        switch self {
        case .browsing(let state): return state.activeTab
        case .searching(let state): return state.activeTab
        case .loading(let state): return state.activeTab
        }
    }
    
    var currentNavigationPaths: [Tab: [NavigationDestination]] {
        switch self {
        case .browsing(let state): return state.navigationPaths
        case .searching(let state): return state.navigationPaths
        case .loading(let state): return state.navigationPaths
        }
    }
    
    var searchQuery: String {
        switch self {
        case .searching(let state): return state.query
        case .browsing, .loading: return ""
        }
    }
    
    var isSearchActive: Bool {
        switch self {
        case .searching: return true
        case .browsing, .loading: return false
        }
    }
    
    var currentError: String? {
        switch self {
        case .browsing(let state): return state.errorMessage
        case .searching(let state): return state.errorMessage
        case .loading: return nil
        }
    }
    
    var isLoading: Bool {
        switch self {
        case .loading: return true
        case .browsing, .searching: return false
        }
    }
}

// MARK: - Navigation Types

enum NavigationDestination: Hashable, Identifiable {
    case wordDetail(Word)
    case addWord
    case collectionDetail(Collection)
    case settings
    
    var id: String {
        switch self {
        case .wordDetail(let word): return "word-\(word.id)"
        case .addWord: return "add-word"
        case .collectionDetail(let collection): return "collection-\(collection.id)"
        case .settings: return "settings"
        }
    }
}

enum PresentationStyle {
    case push
    case sheet
    case fullscreen
}

// MARK: - Tab Configuration

enum Tab: Int, CaseIterable, Identifiable, Equatable {
    case words = 0
    case collections = 1
    
    var id: Int { rawValue }
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .words:
            WordsListView()
        case .collections:
            CollectionsView()
        }
    }
    
    var label: String {
        switch self {
        case .words: return "Words"
        case .collections: return "Collections"
        }
    }
}

// MARK: - Models

struct Word: Hashable, Identifiable {
    let id = UUID()
    let text: String
    let definition: String
    let example: String
    
    // Lazy load samples for memory optimization
    static var samples: [Word] {
        [
            Word(text: "Serendipity", definition: "The occurrence of events by chance in a happy way", example: "Finding that book was pure serendipity."),
            Word(text: "Ephemeral", definition: "Lasting for a very short time", example: "The beauty of cherry blossoms is ephemeral."),
            Word(text: "Luminous", definition: "Bright or shining, especially in the dark", example: "The moon cast a luminous glow over the lake."),
            Word(text: "Quixotic", definition: "Extremely idealistic and unrealistic", example: "His quixotic quest for perfection never ended."),
            Word(text: "Ineffable", definition: "Too great to be expressed in words", example: "The ineffable beauty of the sunset left us speechless."),
            Word(text: "Mellifluous", definition: "Sweet or musical; pleasant to hear", example: "Her mellifluous voice captivated the audience."),
            Word(text: "Petrichor", definition: "The pleasant smell of earth after rain", example: "The petrichor filled the air after the storm."),
            Word(text: "Sonder", definition: "The realization that each passerby has a life as vivid as your own", example: "A feeling of sonder overwhelmed him in the crowded station.")
        ]
    }
}

struct Collection: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let wordCount: Int
    let color: Color
    let books: [String]
    
    // Lazy load samples for memory optimization
    static var samples: [Collection] {
        [
            Collection(name: "Favorites", wordCount: 12, color: .red,
                      books: ["The Great Gatsby", "To Kill a Mockingbird"]),
            Collection(name: "Recent", wordCount: 5, color: .blue,
                      books: ["1984", "Brave New World"]),
            Collection(name: "Study List", wordCount: 23, color: .green,
                      books: ["Atomic Habits", "Deep Work"]),
            Collection(name: "Advanced", wordCount: 18, color: .purple,
                      books: ["Ulysses", "Infinite Jest"])
        ]
    }
}

struct TabBarAction: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let role: ActionRole
    
    enum ActionRole: Equatable {
        case search
        case add
    }
}

// MARK: - Main Content View

struct ContentView: View {
    var body: some View {
        RootNavigationContainer()
    }
}

// MARK: - Root Navigation Container (Optimized)

struct RootNavigationContainer: View {
    @State private var appState = AppState.initial
    @FocusState private var isSearchFieldFocused: Bool
    
    // SOLUTION 2: Simplified navigation path binding using pure function
    private func navigationPath(for tab: Tab) -> Binding<[NavigationDestination]> {
        Binding(
            get: { appState.currentNavigationPaths[tab] ?? [] },
            set: { newPath in
                appState = appState.updateNavigationPath(newPath, for: tab)
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 0: Content with paging animation
                TabView(selection: .constant(appState.currentTab.rawValue)) {
                    ForEach(Tab.allCases) { tab in
                        NavigationStack(path: navigationPath(for: tab)) {
                            tab.view
                                .environment(\.appState, appState)
                                .environment(\.dispatch, dispatch)
                                .navigationDestination(for: NavigationDestination.self) { destination in
                                    DestinationView(destination: destination)
                                        .environment(\.appState, appState)
                                        .environment(\.dispatch, dispatch)
                                }
                        }
                        .tag(tab.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Layer 1: Fixed Navigation Bar
            FixedNavigationBar(
                selectedTab: appState.currentTab,
                onTabSelect: { dispatch(.switchTab($0)) },
                onSearch: {
                    dispatch(.activateSearch)
                    DispatchQueue.main.async {
                        isSearchFieldFocused = true
                    }
                }
            )
            
            // Layer 2: Search Overlay (Conditional rendering)
            if appState.isSearchActive {
                SearchOverlayView(
                    isSearchFieldFocused: $isSearchFieldFocused,
                    searchText: .constant(appState.searchQuery), // SOLUTION 3: Use single source of truth
                    placeholderText: getSearchPlaceholderText(),
                    isActive: appState.isSearchActive,
                    onSubmit: {
                        isSearchFieldFocused = false
                    },
                    onCancel: {
                        dispatch(.dismissSearch)
                        isSearchFieldFocused = false
                    },
                    onChange: { newValue in
                        dispatch(.updateSearchQuery(newValue))
                    }
                )
                .ignoresSafeArea(.container, edges: .bottom)
                .transition(.move(edge: .bottom))
                .zIndex(100)
            }
            
            // Layer 3: Loading Overlay
            if appState.isLoading {
                LoadingOverlayView()
                    .ignoresSafeArea()
                    .zIndex(200)
            }
            
            // Layer 4: Error Alert
            if let errorMessage = appState.currentError {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .zIndex(300)
                
                ErrorAlertView(message: errorMessage) {
                    dispatch(.clearError)
                }
                                    .zIndex(301)
            }
        }
        .navigationTitle(appState.currentTab.label)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add Word by Typing") {
                        dispatch(.navigate(.addWord, .fullscreen))
                    }
                    Button("Add Word by Camera") {
                        dispatch(.navigate(.addWord, .fullscreen))
                    }
                    Button("Add Book") {
                        dispatch(.navigate(.addWord, .fullscreen))
                    }
                    Button("Add Collection") {
                        dispatch(.navigate(.addWord, .fullscreen))
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Circle())
                }
            }
        }
        }
        .sheet(item: sheetBinding) { destination in
            NavigationStack {
                DestinationView(destination: destination)
                    .environment(\.appState, appState)
                    .environment(\.dispatch, dispatch)
            }
        }
        .fullScreenCover(item: fullscreenBinding) { destination in
            NavigationStack {
                DestinationView(destination: destination)
                    .environment(\.appState, appState)
                    .environment(\.dispatch, dispatch)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                dispatch(.dismissModal)
                            }
                        }
                    }
            }
        }
        .onChange(of: appState.isSearchActive) { _, isActive in
            if !isActive {
                isSearchFieldFocused = false
            }
        }
    }
    
    // Helper functions
    private func getSearchPlaceholderText() -> String {
        switch appState.currentTab.rawValue {
        case 0: return "Search words..."
        case 1: return "Search collections.."
        default: return "Search..."
        }
    }
    
    private var sheetBinding: Binding<NavigationDestination?> {
        Binding(
            get: {
                if case .browsing(let state) = appState,
                   let modal = state.modalPresentation,
                   modal.style == .sheet {
                    return modal.destination
                }
                return nil
            },
            set: { _ in
                dispatch(.dismissModal)
            }
        )
    }
    
    private var fullscreenBinding: Binding<NavigationDestination?> {
        Binding(
            get: {
                if case .browsing(let state) = appState,
                   let modal = state.modalPresentation,
                   modal.style == .fullscreen {
                    return modal.destination
                }
                return nil
            },
            set: { _ in
                dispatch(.dismissModal)
            }
        )
    }
    
    // Action dispatcher - single animation context
    private func dispatch(_ action: AppAction) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            switch action {
            case .switchTab(let tab):
                appState = appState.switchTab(to: tab)
            case .activateSearch:
                appState = appState.activateSearch()
            case .dismissSearch:
                appState = appState.dismissSearch()
            case .updateSearchQuery(let query):
                // No animation for typing
                withAnimation(nil) {
                    appState = appState.updateSearchQuery(query)
                }
            case .navigate(let destination, let style):
                appState = appState.navigate(to: destination, presentation: style)
            case .dismissModal:
                if case .browsing(var state) = appState {
                    state.modalPresentation = nil
                    appState = .browsing(state)
                }
            case .setError(let message):
                appState = appState.setError(message)
            case .clearError:
                appState = appState.clearError()
            case .setLoading(let context):
                appState = appState.setLoading(context: context)
            }
        }
    }
}

// MARK: - App Actions

enum AppAction {
    case switchTab(Tab)
    case activateSearch
    case dismissSearch
    case updateSearchQuery(String)
    case navigate(NavigationDestination, PresentationStyle)
    case dismissModal
    case setError(String)
    case clearError
    case setLoading(String)
}

// MARK: - Loading Overlay View

struct LoadingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Loading...")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(24)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Error Alert View

struct ErrorAlertView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Error")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("OK") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 8)
        .padding(.horizontal, 40)
    }
}

// MARK: - Fixed Navigation Bar (Optimized)

struct FixedNavigationBar: View {
    let selectedTab: Tab
    let onTabSelect: (Tab) -> Void
    let onSearch: () -> Void
    
    @Namespace private var pillAnimation
    
    // MARK: - Main Body
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                tabPillsView
                actionButtonsView
                Spacer()
            }
            .padding(.bottom)
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Subviews

    /// The pill-style tab selector.
    private var tabPillsView: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { tab in
                TabPill(
                    title: tab.label,
                    isSelected: tab == selectedTab,
                    namespace: pillAnimation,
                    action: { onTabSelect(tab) }
                )
            }
        }
        .padding(4)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .frame(maxWidth: 250)
    }

    /// The search action button.
    private var actionButtonsView: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
    }
}

// MARK: - Tab Pill (Memoized)

struct TabPill: View, Equatable {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    static func == (lhs: TabPill, rhs: TabPill) -> Bool {
        lhs.title == rhs.title && lhs.isSelected == rhs.isSelected
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.primary.opacity(0.1))
                                .matchedGeometryEffect(id: "selectedPill", in: namespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Overlay View (Optimized)

struct SearchOverlayView: View {
    @FocusState.Binding var isSearchFieldFocused: Bool
    @Binding var searchText: String
    let placeholderText: String
    let isActive: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onChange: (String) -> Void
        
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                SearchFieldView(
                    isSearchFieldFocused: $isSearchFieldFocused,
                    searchText: $searchText,
                    placeholderText: placeholderText,
                    onSubmit: onSubmit,
                    onCancel: onCancel,
                    onChange: onChange
                )
                .padding(.vertical, 12)
            }
            .offset(y: isActive ? 0 : UIScreen.main.bounds.height)
        }
    }
}

// MARK: - Search Field View (Optimized)

struct SearchFieldView: View {
    @FocusState.Binding var isSearchFieldFocused: Bool
    @Binding var searchText: String
    let placeholderText: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onChange: (String) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Search Field Container
            HStack(spacing: 12) {
                TextField(placeholderText, text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)
                    .onChange(of: searchText) { _, newValue in
                        onChange(newValue)
                    }
                    .padding(.leading, 16)
                
                // Cancel/Clear Button (X)
                Button(action: {
                    if !searchText.isEmpty {
                        // Clear text only
                        onChange("")
                    } else {
                        // Cancel search entirely
                        onCancel()
                    }
                }) {
                    Image(systemName: searchText.isEmpty ? "xmark" : "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .contentShape(Circle())
                        .frame(width: 30, height: 30)
                }
                .padding(.trailing, 8)
            }
            .frame(height: 44)
            .background(searchFieldBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        searchFieldBorder,
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var searchFieldBackground: some View {
        StandardSearchBackground()
    }
    
    private var searchFieldBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(0.1),
                Color.primary.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Standard Search Background

struct StandardSearchBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Adaptive material based on color scheme
            if colorScheme == .dark {
                // Dark mode - lighter material
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(
                        Color.white.opacity(0.02)
                    )
            } else {
                // Light mode - clean white with subtle tint
                Rectangle()
                    .fill(.thinMaterial)
                    .overlay(
                        Color.blue.opacity(0.01)
                    )
            }
        }
    }
}

// MARK: - Content Views (Optimized with memoized filtering)

struct WordsListView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dispatch) private var dispatch
    
    // Memoized filter result - only recomputes when query changes
    @State private var cachedQuery: String = ""
    @State private var cachedWords: [Word] = Word.samples
    
    private var filteredWords: [Word] {
        let query = appState.searchQuery
        
        // Return cached result if query hasn't changed
        if query == cachedQuery {
            return cachedWords
        }
        
        // Update cache
        let filtered = query.isEmpty ? Word.samples : Word.samples.filter {
            $0.text.localizedCaseInsensitiveContains(query) ||
            $0.definition.localizedCaseInsensitiveContains(query)
        }
        
        // Update cache on next run loop to avoid modifying state during view update
        DispatchQueue.main.async {
            cachedQuery = query
            cachedWords = filtered
        }
        
        return filtered
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredWords) { word in
                    WordRow(word: word) {
                        dispatch(.navigate(.wordDetail(word), .push))
                    }
                    
                    if word.id != filteredWords.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
    }
}

struct WordRow: View, Equatable {
    let word: Word
    let action: () -> Void
    
    static func == (lhs: WordRow, rhs: WordRow) -> Bool {
        lhs.word == rhs.word
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.text)
                        .font(.system(size: 17, weight: .semibold))
                    Text(word.definition)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

struct CollectionsView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dispatch) private var dispatch
    
    // Memoized filter result
    @State private var cachedQuery: String = ""
    @State private var cachedCollections: [Collection] = Collection.samples
    
    private var filteredCollections: [Collection] {
        let query = appState.searchQuery
        
        // Return cached result if query hasn't changed
        if query == cachedQuery {
            return cachedCollections
        }
        
        // Update cache
        let filtered = query.isEmpty ? Collection.samples : Collection.samples.filter { collection in
            collection.name.localizedCaseInsensitiveContains(query) ||
            collection.books.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        
        // Update cache on next run loop
        DispatchQueue.main.async {
            cachedQuery = query
            cachedCollections = filtered
        }
        
        return filtered
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredCollections) { collection in
                    CollectionCard(collection: collection) {
                        dispatch(.navigate(.collectionDetail(collection), .push))
                    }
                }
            }
            .padding()
        }
    }
}

struct CollectionCard: View, Equatable {
    let collection: Collection
    let action: () -> Void
    
    static func == (lhs: CollectionCard, rhs: CollectionCard) -> Bool {
        lhs.collection == rhs.collection
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Circle()
                    .fill(collection.color.gradient)
                    .frame(width: 40, height: 40)
                
                Text(collection.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("\(collection.wordCount) words")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Destination Views

struct DestinationView: View {
    let destination: NavigationDestination
    
    var body: some View {
        switch destination {
        case .wordDetail(let word):
            WordDetailView(word: word)
        case .addWord:
            AddWordView()
        case .collectionDetail(let collection):
            CollectionDetailView(collection: collection)
        case .settings:
            SettingsView()
        }
    }
}

struct WordDetailView: View {
    let word: Word
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Definition")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(word.definition)
                        .font(.body)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(word.example)
                        .font(.body)
                        .italic()
                }
            }
            .padding()
        }
        .navigationTitle(word.text)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct CollectionDetailView: View {
    let collection: Collection
    @Environment(\.dispatch) private var dispatch
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Circle()
                    .fill(collection.color.gradient)
                    .frame(width: 80, height: 80)
                
                Text("\(collection.wordCount) words")
                    .font(.headline)
                
                ForEach(collection.books, id: \.self) { book in
                    HStack {
                        Image(systemName: "book")
                            .foregroundStyle(collection.color)
                        Text(book)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
        .navigationTitle(collection.name)
    }
}

struct AddWordView: View {
    @State private var wordText = ""
    @State private var definition = ""
    @State private var example = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Word") {
                TextField("Enter word", text: $wordText)
            }
            
            Section("Definition") {
                TextField("Enter definition", text: $definition, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section("Example") {
                TextField("Enter example", text: $example, axis: .vertical)
                    .lineLimit(2...4)
            }
            
            Section {
                Button("Save Word") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(wordText.isEmpty || definition.isEmpty)
            }
        }
        .navigationTitle("Add Word")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Section("General") {
                Label("Account", systemImage: "person.circle")
                Label("Notifications", systemImage: "bell")
                Label("Privacy", systemImage: "lock")
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Environment Extensions

private struct AppStateKey: EnvironmentKey {
    static let defaultValue = AppState.initial
}

private struct DispatchKey: EnvironmentKey {
    static let defaultValue: (AppAction) -> Void = { _ in }
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
    
    var dispatch: (AppAction) -> Void {
        get { self[DispatchKey.self] }
        set { self[DispatchKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
