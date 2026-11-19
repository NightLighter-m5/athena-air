// Flight Deck — setup app for the unofficial World of Warplanes for Mac port.
// Walks the player through: roll out (copy to Applications) → fuel up (get the
// Wargaming installer) → ready for takeoff (install Game Center) → get airborne.
import SwiftUI
import AppKit
import UniformTypeIdentifiers

let appName = "World of Warplanes.app"
let volumeName = "World of Warplanes for Mac"
let installedApp = URL(fileURLWithPath: "/Applications/\(appName)")
let gameCenterExe = installedApp.appendingPathComponent(
    "Contents/SharedSupport/prefix/drive_c/Program Files/Wargaming.net/GameCenter/wgc.exe")

// MARK: - Helpers

@discardableResult
func run(_ tool: String, _ args: [String], env: [String: String]? = nil) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    if let env { p.environment = ProcessInfo.processInfo.environment.merging(env) { $1 } }
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
    do { try p.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

/// The port inside the disk image, wherever Flight Deck was opened from.
func sourceApp() -> URL? {
    let candidates = [
        Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(appName),
        URL(fileURLWithPath: "/Volumes/\(volumeName)/\(appName)"),
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
}

func wrapperIsRunning() -> Bool {
    let (_, out) = run("/bin/ps", ["-axo", "command"])
    return out.split(separator: "\n").contains { $0.contains(installedApp.path + "/Contents/") }
}

/// Wineskin leaves this lock behind if the game crashes; it then refuses to run installers.
func clearStaleLock() {
    let lock = "/tmp/" + installedApp.path.replacingOccurrences(of: "/", with: "xWSx")
    try? FileManager.default.removeItem(atPath: lock)
}

func emergencyLanding() {
    let support = installedApp.appendingPathComponent("Contents/SharedSupport")
    let wineserver = support.appendingPathComponent("wine/bin/wineserver").path
    if FileManager.default.fileExists(atPath: wineserver) {
        run(wineserver, ["-k"], env: [
            "WINEPREFIX": support.appendingPathComponent("prefix").path,
            "DYLD_FALLBACK_LIBRARY_PATH": installedApp.appendingPathComponent("Contents/Frameworks").path
                + ":" + support.appendingPathComponent("wine/lib").path + ":/usr/lib",
        ])
    }
    run("/usr/bin/pkill", ["-f", installedApp.path + "/Contents/"])
    Thread.sleep(forTimeInterval: 1.5)
    clearStaleLock()
}

// MARK: - Model

enum Leg: Int { case rollOut, fuelUp, takeoff, airborne }

@MainActor
final class Mission: ObservableObject {
    @Published var inHangar = false
    @Published var gameCenterReady = false
    @Published var installer: URL?
    @Published var busy: String?          // non-nil while something is running
    @Published var radio: String?         // status / error line

    var currentLeg: Leg {
        if !inHangar { return .rollOut }
        if gameCenterReady { return .airborne }
        if installer == nil { return .fuelUp }
        return .takeoff
    }

    init() { refresh() }

    func refresh() {
        inHangar = FileManager.default.fileExists(atPath: installedApp.path)
        gameCenterReady = FileManager.default.fileExists(atPath: gameCenterExe.path)
    }

    func rollOut() {
        guard let src = sourceApp() else {
            radio = "Can't find the plane. Open Flight Deck from the World of Warplanes disk image."
            return
        }
        busy = "Taxiing to the hangar… (copying about 2 GB)"
        radio = nil
        Task.detached {
            var failure: String?
            do {
                if !FileManager.default.fileExists(atPath: installedApp.path) {
                    try FileManager.default.copyItem(at: src, to: installedApp)
                }
                run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", installedApp.path])
            } catch {
                failure = "Couldn't copy into Applications: \(error.localizedDescription). Drag the plane into Applications yourself, then come back."
            }
            let message = failure ?? "In the hangar. Next: fuel up."
            await MainActor.run {
                self.busy = nil
                self.radio = message
                self.refresh()
            }
        }
    }

    func openAirfield(_ url: String) { NSWorkspace.shared.open(URL(string: url)!) }

    func loadFuel() {
        let panel = NSOpenPanel()
        panel.title = "Choose the Wargaming installer you downloaded"
        panel.prompt = "Load fuel"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let exe = UTType(filenameExtension: "exe") { panel.allowedContentTypes = [exe] }
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let url = panel.url {
            installer = url
            radio = "Fuel loaded: \(url.lastPathComponent)"
        }
    }

    func takeOff() {
        guard let exe = installer else { return }
        if wrapperIsRunning() {
            radio = "The plane is already running. Quit World of Warplanes / Game Center first, or use Mayday."
            return
        }
        clearStaleLock()
        run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", installedApp.path])
        busy = "Engines running… follow the Wargaming installer window. Game Center opens when it's done."
        radio = nil
        let launcher = installedApp.appendingPathComponent("Contents/MacOS/wineskinlauncher").path
        Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: launcher)
            p.arguments = ["WSS-installer", exe.path]
            try? p.run()
            // The launcher keeps running while Game Center is open, so watch for Game Center instead.
            while p.isRunning {
                if FileManager.default.fileExists(atPath: gameCenterExe.path) { break }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
            await MainActor.run {
                self.busy = nil
                self.refresh()
                self.radio = self.gameCenterReady
                    ? "Wheels up! Game Center is installed. Log in there and install World of Warplanes."
                    : "Game Center didn't install. Try again, or use Mayday if it says something is already running."
            }
        }
    }

    func getAirborne() {
        clearStaleLock()
        NSWorkspace.shared.openApplication(at: installedApp, configuration: .init())
        radio = "Airborne. Have a good flight, pilot!"
    }

    func mayday() {
        busy = "Mayday! Shutting everything down…"
        Task.detached {
            emergencyLanding()
            await MainActor.run {
                self.busy = nil
                self.radio = "Emergency landing complete. Everything is stopped and reset; try again."
                self.refresh()
            }
        }
    }

    func openManual() {
        if let url = Bundle.main.url(forResource: "Pilot's Manual", withExtension: "html") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Style

extension Color {
    static let ink = Color(red: 0.08, green: 0.11, blue: 0.20)
    static let paper = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let flare = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let done = Color(red: 0.25, green: 0.65, blue: 0.40)
}

struct PilotButton: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .foregroundStyle(prominent ? Color.white : Color.ink)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(prominent ? Color.flare : Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            )
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.ink.opacity(prominent ? 0 : 0.15)))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

enum CardState { case done, active, waiting }

struct LegCard<Actions: View>: View {
    let number: Int
    let title: String
    let detail: String
    let state: CardState
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(state == .done ? Color.done : state == .active ? Color.flare : Color.ink.opacity(0.15))
                    .frame(width: 34, height: 34)
                if state == .done {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(state == .active ? .white : Color.ink.opacity(0.5))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 16, weight: .heavy)).foregroundStyle(Color.ink)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(Color.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                if state == .active { HStack(spacing: 8) { actions }.padding(.top, 4) }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(state == .active ? 1 : 0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(state == .active ? Color.flare.opacity(0.6) : Color.ink.opacity(0.08), lineWidth: state == .active ? 2 : 1))
        .opacity(state == .waiting ? 0.6 : 1)
    }
}

// MARK: - Main view

struct FlightDeckView: View {
    @StateObject var m = Mission()

    func state(_ leg: Leg) -> CardState {
        if leg.rawValue < m.currentLeg.rawValue { return .done }
        return leg == m.currentLeg ? .active : .waiting
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: NSImage(named: "header") ?? NSImage())
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(height: 170).clipped()
                VStack(alignment: .leading, spacing: 2) {
                    Text("FLIGHT DECK").font(.system(size: 30, weight: .black)).tracking(3)
                    Text("World of Warplanes for Mac  ·  unofficial community port")
                        .font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                .padding(20)
            }

            ScrollView {
                VStack(spacing: 10) {
                    LegCard(number: 1, title: "Roll out of the hangar",
                            detail: "Moves the plane into your Applications folder so it's ready to fly.",
                            state: state(.rollOut)) {
                        Button("Roll out") { m.rollOut() }.buttonStyle(PilotButton())
                    }
                    LegCard(number: 2, title: "Fuel up",
                            detail: "Get Wargaming Game Center from the official site for your region (the Windows .exe), then load it here.",
                            state: state(.fuelUp)) {
                        Button("Asia") { m.openAirfield("https://worldofwarplanes.asia") }.buttonStyle(PilotButton(prominent: false))
                        Button("Europe") { m.openAirfield("https://worldofwarplanes.eu") }.buttonStyle(PilotButton(prominent: false))
                        Button("N. America") { m.openAirfield("https://worldofwarplanes.com") }.buttonStyle(PilotButton(prominent: false))
                        Button("Load fuel") { m.loadFuel() }.buttonStyle(PilotButton())
                    }
                    LegCard(number: 3, title: "Ready for takeoff",
                            detail: "Installs Game Center inside the plane. Click through Wargaming's installer like on Windows.",
                            state: state(.takeoff)) {
                        Button("Start engines") { m.takeOff() }.buttonStyle(PilotButton())
                        Button("Change fuel") { m.loadFuel() }.buttonStyle(PilotButton(prominent: false))
                    }
                    LegCard(number: 4, title: "Get airborne!",
                            detail: "Log in to Game Center, install World of Warplanes (about 25 GB) and hit Play. Next time just open World of Warplanes from Applications.",
                            state: m.currentLeg == .airborne ? .active : .waiting) {
                        Button("Get airborne") { m.getAirborne() }.buttonStyle(PilotButton())
                    }
                }
                .padding(16)
            }
            .disabled(m.busy != nil)

            HStack(spacing: 10) {
                if let busy = m.busy {
                    ProgressView().controlSize(.small)
                    Text(busy).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink)
                } else if let radio = m.radio {
                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Color.flare)
                    Text(radio).font(.system(size: 12)).foregroundStyle(Color.ink)
                } else {
                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Color.ink.opacity(0.4))
                    Text("Tower: cleared for setup, pilot.").font(.system(size: 12)).foregroundStyle(Color.ink.opacity(0.6))
                }
                Spacer()
                Button("Pilot's manual") { m.openManual() }.buttonStyle(PilotButton(prominent: false))
                Button("Mayday") { m.mayday() }.buttonStyle(PilotButton(prominent: false))
                    .help("Stuck or 'already running'? Shuts everything down and resets the plane.")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white.opacity(0.7))
        }
        .background(Color.paper)
        .frame(width: 640, height: 640)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in m.refresh() }
    }
}

@main
struct FlightDeckApp: App {
    var body: some Scene {
        WindowGroup("Flight Deck") { FlightDeckView() }
            .windowResizability(.contentSize)
    }
}
