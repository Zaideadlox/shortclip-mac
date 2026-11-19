import AppKit
import SwiftUI

struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add TikTok Video URL...") {
                appState.isShowingAddURLSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command])

            Divider()

            Button("Search TikTok...") {
                appState.triggerSearch()
            }
            .keyboardShortcut("f", modifiers: [.command])
        }

        CommandMenu("Playback") {
            Button("Play / Pause    (Space)") {
                appState.togglePlayPause()
            }

            Button("Previous Video    (↑)") {
                appState.previousVideo()
            }

            Button("Next Video    (↓)") {
                appState.nextVideo()
            }

            Divider()

            Button("Mute / Unmute    (M)") {
                appState.toggleMute()
            }

            Button("Picture in Picture") {
                appState.container.videoPlayerManager.togglePictureInPicture()
            }
            .keyboardShortcut("p", modifiers: [.command])

            Button("Toggle Full Screen") {
                NSApplication.shared.keyWindow?.toggleFullScreen(nil)
            }
            .keyboardShortcut("f", modifiers: [.control, .command])
        }

        CommandMenu("Navigate") {
            Button("For You") { appState.navigate(to: .forYou) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Following") { appState.navigate(to: .following) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Friends") { appState.navigate(to: .friends) }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Explore") { appState.navigate(to: .explore) }
                .keyboardShortcut("4", modifiers: [.command])
            Button("LIVE") { appState.navigate(to: .live) }
                .keyboardShortcut("5", modifiers: [.command])
            Button("Messages") { appState.navigate(to: .messages) }
                .keyboardShortcut("6", modifiers: [.command])
            Button("Profile") { appState.navigate(to: .profile) }
                .keyboardShortcut("7", modifiers: [.command])

            Divider()

            Button("Switch Native Player / TikTok Web") {
                appState.toggleEngine()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Button("Sign In / Account...") {
                appState.isShowingAuthSheet = true
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                appState.navigate(to: .settings)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
