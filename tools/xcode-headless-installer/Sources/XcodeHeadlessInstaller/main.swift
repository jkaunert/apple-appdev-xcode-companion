import Foundation
import Darwin
import AppKit

struct InstallerError: Error, CustomStringConvertible {
    let description: String
}

struct Options {
    var installAgent = false
    var activateAgent = false
    var installPluginProfile = false
    var restorePluginBackup: URL?
    var dryRun = false
    var force = false
    var agentVersion: String?
    var xcodeBuild: String?
    var agentsRoot: URL?
    var payloadRoot: URL?
    var pluginVersion: String?
    var pluginSource = "apple-developer-tools"
    var pluginName = "apple-appdev-workflow"
    var xcodeCodexHome: URL?
    var pluginPayloadRoot: URL?
}

struct PluginIdentity {
    let name: String
    let version: String
}

struct PluginInstallState: Codable {
    let schemaVersion: Int
    let source: String
    let pluginName: String
    let version: String
    let previousProfilePresent: Bool
    let previousConfigPresent: Bool
}

let pluginInstallStateFilename = "install-state.json"
let pluginInstallProfileDirectory = "previous-profile"
let pluginInstallConfigFilename = "config.toml.before-install"

func usage() -> String {
    """
    Usage:
      xcode-headless-installer --install-agent [options]
      xcode-headless-installer --install-plugin-profile [options]
      xcode-headless-installer --restore-plugin-profile BACKUP_PATH [options]

    Agent options:
      --install-agent          Copy the embedded Xcode Codex agent payload.
      --activate-agent         Point the active Xcode build symlink at the installed payload.
      --agent-version VALUE    Payload directory under Contents/Resources/XcodeAgent.
      --xcode-build VALUE      Xcode build directory under Agents/XcodeVersions. Defaults to xcodebuild -version.
      --agents-root PATH       Defaults to ~/Library/Developer/Xcode/CodingAssistant/Agents.
      --payload-root PATH      Defaults to Contents/Resources/XcodeAgent.
      --force                  Replace an existing destination agent payload directory.

    Plugin-profile options:
      --install-plugin-profile Copy and enable the embedded xcode-headless plugin profile.
      --restore-plugin-profile PATH
                               Restore a backup created by a prior profile install.
      --plugin-version VALUE   Payload version under XcodePluginProfile/<plugin>.
      --plugin-source VALUE    Cache namespace. Defaults to apple-developer-tools.
      --plugin-name VALUE      Plugin name. Defaults to apple-appdev-workflow.
      --xcode-codex-home PATH  Defaults to ~/Library/Developer/Xcode/CodingAssistant/codex.
      --plugin-payload-root PATH
                               Defaults to Contents/Resources/XcodePluginProfile.

    Shared options:
      --dry-run                Print actions without mutating files.
      -h, --help               Show this help.

    Plugin-profile installation never changes Xcode's active Codex agent.
    Install and restore transactionally preserve the prior profile and config.
    """
}

func expandedDirectoryURL(_ value: String) -> URL {
    URL(
        fileURLWithPath: NSString(string: value).expandingTildeInPath,
        isDirectory: true
    )
}

func parseArguments(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0
    while index < arguments.count {
        let arg = arguments[index]
        switch arg {
        case "--install-agent":
            options.installAgent = true
            index += 1
        case "--activate-agent":
            options.activateAgent = true
            index += 1
        case "--install-plugin-profile":
            options.installPluginProfile = true
            index += 1
        case "--restore-plugin-profile":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--restore-plugin-profile requires a value")
            }
            options.restorePluginBackup = expandedDirectoryURL(arguments[index + 1])
            index += 2
        case "--dry-run":
            options.dryRun = true
            index += 1
        case "--force":
            options.force = true
            index += 1
        case "--agent-version":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--agent-version requires a value")
            }
            options.agentVersion = arguments[index + 1]
            index += 2
        case "--xcode-build":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--xcode-build requires a value")
            }
            options.xcodeBuild = arguments[index + 1]
            index += 2
        case "--agents-root":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--agents-root requires a value")
            }
            options.agentsRoot = expandedDirectoryURL(arguments[index + 1])
            index += 2
        case "--payload-root":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--payload-root requires a value")
            }
            options.payloadRoot = expandedDirectoryURL(arguments[index + 1])
            index += 2
        case "--plugin-version":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--plugin-version requires a value")
            }
            options.pluginVersion = arguments[index + 1]
            index += 2
        case "--plugin-source":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--plugin-source requires a value")
            }
            options.pluginSource = arguments[index + 1]
            index += 2
        case "--plugin-name":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--plugin-name requires a value")
            }
            options.pluginName = arguments[index + 1]
            index += 2
        case "--xcode-codex-home":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--xcode-codex-home requires a value")
            }
            options.xcodeCodexHome = expandedDirectoryURL(arguments[index + 1])
            index += 2
        case "--plugin-payload-root":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--plugin-payload-root requires a value")
            }
            options.pluginPayloadRoot = expandedDirectoryURL(arguments[index + 1])
            index += 2
        case "-h", "--help":
            print(usage())
            Darwin.exit(0)
        default:
            throw InstallerError(description: "unknown argument: \(arg)")
        }
    }
    return options
}

func run(_ executable: String, _ arguments: [String]) throws -> (Int32, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func validatePathComponent(_ value: String, label: String) throws -> String {
    let allowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-"
    )
    guard !value.isEmpty,
          value != ".",
          value != "..",
          value.unicodeScalars.allSatisfy({ allowed.contains($0) })
    else {
        throw InstallerError(description: "\(label) must be one safe path component")
    }
    return value
}

func detectXcodeBuild() throws -> String {
    let (status, output) = try run("/usr/bin/xcodebuild", ["-version"])
    guard status == 0 else {
        throw InstallerError(
            description: "xcodebuild -version failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
    for line in output.split(separator: "\n") where line.hasPrefix("Build version ") {
        return try validatePathComponent(
            String(line.dropFirst("Build version ".count)),
            label: "Xcode build"
        )
    }
    throw InstallerError(description: "could not parse Xcode build from xcodebuild -version output")
}

func defaultAgentsRoot() -> URL {
    URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("Library/Developer/Xcode/CodingAssistant/Agents", isDirectory: true)
}

func defaultXcodeCodexHome() -> URL {
    URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("Library/Developer/Xcode/CodingAssistant/codex", isDirectory: true)
}

func requireXcodeClosedForDefaultHome(_ xcodeCodexHome: URL, dryRun: Bool) throws {
    guard !dryRun,
          xcodeCodexHome.standardizedFileURL == defaultXcodeCodexHome().standardizedFileURL
    else {
        return
    }
    let (status, output) = try run("/usr/bin/pgrep", ["-x", "Xcode"])
    if status == 0 {
        throw InstallerError(
            description: "quit Xcode before changing its CodingAssistant plugin profile"
        )
    }
    guard status == 1 else {
        throw InstallerError(
            description: "could not determine whether Xcode is running: "
                + output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

func defaultResourceDirectory(_ name: String) throws -> URL {
    if let resourceURL = Bundle.main.resourceURL {
        return resourceURL.appendingPathComponent(name, isDirectory: true)
    }
    throw InstallerError(description: "could not resolve app resource directory")
}

func resolveOnlyDirectory(root: URL, requested: String?, label: String) throws -> String {
    if let requested {
        return try validatePathComponent(requested, label: label)
    }
    let children = try FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )
    let directories = try children.filter { url in
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        return values.isDirectory == true
    }
    if directories.count == 1, let only = directories.first {
        return try validatePathComponent(only.lastPathComponent, label: label)
    }
    throw InstallerError(
        description: "specify \(label); expected exactly one payload directory in \(root.path)"
    )
}

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter.string(from: Date())
}

func describe(_ message: String) {
    print(message)
}

func copyComponentFile(from source: URL, to destination: URL) throws {
    let (status, output) = try run("/bin/cp", ["-X", source.path, destination.path])
    guard status == 0 else {
        throw InstallerError(
            description: "copy failed: \(source.path) -> \(destination.path): \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
    let (xattrStatus, xattrOutput) = try run("/usr/bin/xattr", ["-c", destination.path])
    guard xattrStatus == 0 else {
        throw InstallerError(
            description: "strip extended attributes failed: \(destination.path): \(xattrOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
}

func copyDirectory(from source: URL, to destination: URL) throws {
    let (status, output) = try run(
        "/bin/cp",
        ["-R", "-X", source.path, destination.path]
    )
    guard status == 0 else {
        throw InstallerError(
            description: "copy failed: \(source.path) -> \(destination.path): \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
    let (xattrStatus, xattrOutput) = try run("/usr/bin/xattr", ["-c", "-r", destination.path])
    guard xattrStatus == 0 else {
        throw InstallerError(
            description: "strip extended attributes failed: \(destination.path): \(xattrOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
}

func copyAgentPayload(from source: URL, to destination: URL, force: Bool, dryRun: Bool) throws {
    let fileManager = FileManager.default
    let sourceCodex = source.appendingPathComponent("codex")
    let sourceInfo = source.appendingPathComponent("Info.plist")
    guard fileManager.fileExists(atPath: sourceCodex.path) else {
        throw InstallerError(description: "payload codex binary is missing: \(sourceCodex.path)")
    }
    guard fileManager.fileExists(atPath: sourceInfo.path) else {
        throw InstallerError(description: "payload Info.plist is missing: \(sourceInfo.path)")
    }
    if fileManager.fileExists(atPath: destination.path) {
        guard force else {
            throw InstallerError(
                description: "destination payload already exists; pass --force to replace: \(destination.path)"
            )
        }
        describe("remove existing payload: \(destination.path)")
        if !dryRun {
            try fileManager.removeItem(at: destination)
        }
    }
    describe("copy agent payload: \(source.path) -> \(destination.path)")
    if !dryRun {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try copyComponentFile(from: sourceCodex, to: destination.appendingPathComponent("codex"))
        try copyComponentFile(from: sourceInfo, to: destination.appendingPathComponent("Info.plist"))
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: destination.appendingPathComponent("codex").path
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: destination.appendingPathComponent("Info.plist").path
        )
    }
}

func verifyAgent(at destination: URL, dryRun: Bool) throws {
    let codex = destination.appendingPathComponent("codex")
    if dryRun {
        describe("dry-run: would run \(codex.path) --version")
        return
    }
    let (status, output) = try run(codex.path, ["--version"])
    guard status == 0 else {
        throw InstallerError(
            description: "installed codex --version failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
    describe("installed agent version: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
}

func activateAgent(destination: URL, agentsRoot: URL, xcodeBuild: String, dryRun: Bool) throws {
    let fileManager = FileManager.default
    let safeBuild = try validatePathComponent(xcodeBuild, label: "Xcode build")
    let xcodeVersionDir = agentsRoot.appendingPathComponent("XcodeVersions", isDirectory: true)
        .appendingPathComponent(safeBuild, isDirectory: true)
    let activeLink = xcodeVersionDir.appendingPathComponent("codex")
    let backupLink = xcodeVersionDir.appendingPathComponent(
        "codex.before-apple-appdev-installer-\(timestamp())"
    )

    describe("activate agent for Xcode build \(safeBuild): \(activeLink.path) -> \(destination.path)")
    if dryRun {
        describe("dry-run: would create rollback symlink if \(activeLink.path) exists")
        describe("dry-run: would replace active symlink with \(destination.path)")
        return
    }

    try fileManager.createDirectory(at: xcodeVersionDir, withIntermediateDirectories: true)
    if let existingTarget = try? fileManager.destinationOfSymbolicLink(atPath: activeLink.path) {
        try fileManager.createSymbolicLink(
            at: backupLink,
            withDestinationURL: URL(fileURLWithPath: existingTarget)
        )
        try fileManager.removeItem(at: activeLink)
        describe("rollback symlink: \(backupLink.path) -> \(existingTarget)")
    } else if fileManager.fileExists(atPath: activeLink.path) {
        throw InstallerError(
            description: "active codex path is not a symlink; refusing to replace: \(activeLink.path)"
        )
    }
    try fileManager.createSymbolicLink(at: activeLink, withDestinationURL: destination)
}

func readPluginManifest(at profile: URL) throws -> [String: Any] {
    let manifestURL = profile.appendingPathComponent(".codex-plugin/plugin.json")
    guard (try? manifestURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
        throw InstallerError(description: "plugin manifest is missing: \(manifestURL.path)")
    }
    let data: Data
    do {
        data = try Data(contentsOf: manifestURL)
    } catch {
        throw InstallerError(description: "plugin manifest is missing: \(manifestURL.path)")
    }
    let object = try JSONSerialization.jsonObject(with: data)
    guard let manifest = object as? [String: Any] else {
        throw InstallerError(description: "plugin manifest must be a JSON object: \(manifestURL.path)")
    }
    return manifest
}

func rejectSymbolicLinks(in profile: URL) throws {
    let rootValues = try profile.resourceValues(forKeys: [.isSymbolicLinkKey])
    if rootValues.isSymbolicLink == true {
        throw InstallerError(description: "plugin profile root must not be a symbolic link")
    }
    guard let enumerator = FileManager.default.enumerator(
        at: profile,
        includingPropertiesForKeys: [.isSymbolicLinkKey],
        options: [],
        errorHandler: nil
    ) else {
        throw InstallerError(description: "could not enumerate plugin profile: \(profile.path)")
    }
    for case let entry as URL in enumerator {
        let values = try entry.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            throw InstallerError(
                description: "plugin profile must not contain symbolic links: \(entry.path)"
            )
        }
    }
}

func validatePluginProfile(
    at profile: URL,
    expectedName: String? = nil,
    expectedVersion: String? = nil
) throws -> PluginIdentity {
    let fileManager = FileManager.default
    try rejectSymbolicLinks(in: profile)
    let manifest = try readPluginManifest(at: profile)
    guard let name = manifest["name"] as? String, !name.isEmpty,
          let version = manifest["version"] as? String, !version.isEmpty
    else {
        throw InstallerError(description: "plugin manifest lacks name or version")
    }
    _ = try validatePathComponent(name, label: "plugin name")
    _ = try validatePathComponent(version, label: "plugin version")
    if let expectedName, name != expectedName {
        throw InstallerError(
            description: "plugin payload name mismatch: expected \(expectedName); found \(name)"
        )
    }
    if let expectedVersion, version != expectedVersion {
        throw InstallerError(
            description: "plugin payload version mismatch: expected \(expectedVersion); found \(version)"
        )
    }
    if manifest["mcpServers"] != nil {
        throw InstallerError(description: "xcode-headless plugin payload must omit mcpServers")
    }
    if manifest["routerSelection"] != nil {
        throw InstallerError(description: "xcode-headless plugin payload contains retired routerSelection")
    }
    for relativePath in [
        "hooks/hooks.json",
        "hooks/apple_router.mjs",
        "routing/router-policy.json",
        "routing/top-level-owner-kernel.md",
    ] {
        let requiredFile = profile.appendingPathComponent(relativePath)
        let values = try? requiredFile.resourceValues(forKeys: [.isRegularFileKey])
        guard fileManager.fileExists(atPath: requiredFile.path), values?.isRegularFile == true else {
            throw InstallerError(
                description: "xcode-headless plugin payload lacks required regular file: \(relativePath)"
            )
        }
    }
    return PluginIdentity(name: name, version: version)
}

func uniquePath(_ path: URL) throws -> URL {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path.path) {
        return path
    }
    for index in 2..<1000 {
        let candidate = path.deletingLastPathComponent()
            .appendingPathComponent("\(path.lastPathComponent)-\(index)", isDirectory: true)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
    }
    throw InstallerError(description: "could not allocate unique backup path for \(path.path)")
}

func pluginQuarantineRoot(xcodeCodexHome: URL, pluginName: String) -> URL {
    xcodeCodexHome.appendingPathComponent(".tmp/plugins/quarantine", isDirectory: true)
        .appendingPathComponent(pluginName, isDirectory: true)
}

func pluginCacheTarget(
    xcodeCodexHome: URL,
    source: String,
    pluginName: String,
    version: String
) -> URL {
    xcodeCodexHome.appendingPathComponent("plugins/cache", isDirectory: true)
        .appendingPathComponent(source, isDirectory: true)
        .appendingPathComponent(pluginName, isDirectory: true)
        .appendingPathComponent(version, isDirectory: true)
}

func pluginIdentifier(source: String, pluginName: String) -> String {
    "\(pluginName)@\(source)"
}

func pluginTableIdentifier(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let prefix = "[plugins.\""
    let suffix = "\"]"
    guard trimmed.hasPrefix(prefix), trimmed.hasSuffix(suffix) else {
        return nil
    }
    return String(trimmed.dropFirst(prefix.count).dropLast(suffix.count))
}

func setPluginEnabled(
    lines: inout [String],
    pluginID: String,
    enabled: Bool
) -> Bool {
    guard let headerIndex = lines.firstIndex(where: {
        pluginTableIdentifier($0) == pluginID
    }) else {
        return false
    }
    var nextHeader = headerIndex + 1
    while nextHeader < lines.count {
        let trimmed = lines[nextHeader].trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            break
        }
        let assignment = trimmed.split(separator: "=", maxSplits: 1)
        if assignment.count == 2,
           assignment[0].trimmingCharacters(in: .whitespaces) == "enabled" {
            lines[nextHeader] = "enabled = \(enabled ? "true" : "false")"
            return true
        }
        nextHeader += 1
    }
    lines.insert("enabled = \(enabled ? "true" : "false")", at: nextHeader)
    return true
}

func configActivatingPlugin(
    _ existing: String,
    source: String,
    pluginName: String
) -> String {
    var lines = existing.components(separatedBy: "\n")
    if lines.last == "" {
        lines.removeLast()
    }
    let targetID = pluginIdentifier(source: source, pluginName: pluginName)
    let conflictingIDs = lines.compactMap(pluginTableIdentifier).filter {
        $0.hasPrefix("\(pluginName)@") && $0 != targetID
    }
    for conflictingID in conflictingIDs {
        _ = setPluginEnabled(lines: &lines, pluginID: conflictingID, enabled: false)
    }
    if !setPluginEnabled(lines: &lines, pluginID: targetID, enabled: true) {
        if let last = lines.last, !last.isEmpty {
            lines.append("")
        }
        lines.append("[plugins.\"\(targetID)\"]")
        lines.append("enabled = true")
    }
    return lines.joined(separator: "\n") + "\n"
}

func writeConfig(_ contents: String, to configURL: URL) throws {
    try FileManager.default.createDirectory(
        at: configURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let data = contents.data(using: .utf8) else {
        throw InstallerError(description: "could not encode Xcode Codex config")
    }
    try data.write(to: configURL, options: .atomic)
}

func writeInstallState(_ state: PluginInstallState, to backup: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var data = try encoder.encode(state)
    data.append(0x0A)
    try data.write(
        to: backup.appendingPathComponent(pluginInstallStateFilename),
        options: .atomic
    )
}

func readInstallState(from backup: URL) throws -> PluginInstallState {
    let stateURL = backup.appendingPathComponent(pluginInstallStateFilename)
    do {
        let data = try Data(contentsOf: stateURL)
        let state = try JSONDecoder().decode(PluginInstallState.self, from: data)
        guard state.schemaVersion == 1 else {
            throw InstallerError(
                description: "unsupported plugin install backup schema: \(state.schemaVersion)"
            )
        }
        return state
    } catch let error as InstallerError {
        throw error
    } catch {
        throw InstallerError(description: "invalid plugin install backup: \(stateURL.path)")
    }
}

func restoreConfigSnapshot(
    from backup: URL,
    previousConfigPresent: Bool,
    configURL: URL
) throws {
    let fileManager = FileManager.default
    if previousConfigPresent {
        let snapshot = backup.appendingPathComponent(pluginInstallConfigFilename)
        guard fileManager.fileExists(atPath: snapshot.path) else {
            throw InstallerError(description: "config backup is missing: \(snapshot.path)")
        }
        let data = try Data(contentsOf: snapshot)
        try fileManager.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: configURL, options: .atomic)
    } else if fileManager.fileExists(atPath: configURL.path) {
        try fileManager.removeItem(at: configURL)
    }
}

func createInstallBackup(
    at backup: URL,
    state: PluginInstallState,
    configURL: URL
) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: backup, withIntermediateDirectories: true)
    if state.previousConfigPresent {
        try fileManager.copyItem(
            at: configURL,
            to: backup.appendingPathComponent(pluginInstallConfigFilename)
        )
    }
    try writeInstallState(state, to: backup)
}

func isContained(_ candidate: URL, in root: URL) -> Bool {
    let candidatePath = candidate.resolvingSymlinksInPath().standardizedFileURL.path
    let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
    return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
}

@discardableResult
func installPluginProfile(
    from payload: URL,
    to destination: URL,
    quarantineRoot: URL,
    xcodeCodexHome: URL,
    source: String,
    pluginName: String,
    dryRun: Bool
) throws -> URL? {
    let fileManager = FileManager.default
    let identity = try validatePluginProfile(at: payload)
    let configURL = xcodeCodexHome.appendingPathComponent("config.toml")
    let previousProfilePresent = fileManager.fileExists(atPath: destination.path)
    let previousConfigPresent = fileManager.fileExists(atPath: configURL.path)
    let backup = try uniquePath(
        quarantineRoot.appendingPathComponent(
            "\(identity.version)-plugin-install-\(timestamp())",
            isDirectory: true
        )
    )
    let state = PluginInstallState(
        schemaVersion: 1,
        source: source,
        pluginName: pluginName,
        version: identity.version,
        previousProfilePresent: previousProfilePresent,
        previousConfigPresent: previousConfigPresent
    )
    if previousProfilePresent {
        describe(
            "backup existing plugin profile: \(destination.path) -> "
                + "\(backup.path)/\(pluginInstallProfileDirectory)"
        )
    }
    describe("backup Xcode Codex plugin state: \(backup.path)")
    describe("install xcode-headless plugin profile: \(payload.path) -> \(destination.path)")
    describe("enable plugin: \(pluginIdentifier(source: source, pluginName: pluginName))")
    describe("disable conflicting \(pluginName) identities without removing their caches")
    if dryRun {
        describe("dry-run: Xcode active Codex agent remains unchanged")
        return backup
    }

    try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try createInstallBackup(at: backup, state: state, configURL: configURL)
    if previousProfilePresent {
        try fileManager.moveItem(
            at: destination,
            to: backup.appendingPathComponent(pluginInstallProfileDirectory, isDirectory: true)
        )
    }
    do {
        try copyDirectory(from: payload, to: destination)
        _ = try validatePluginProfile(
            at: destination,
            expectedName: identity.name,
            expectedVersion: identity.version
        )
        let existingConfig = previousConfigPresent
            ? try String(contentsOf: configURL, encoding: .utf8)
            : ""
        try writeConfig(
            configActivatingPlugin(
                existingConfig,
                source: source,
                pluginName: pluginName
            ),
            to: configURL
        )
    } catch {
        let installError = error
        var rollbackErrors: [String] = []
        if fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.removeItem(at: destination)
            } catch {
                rollbackErrors.append("remove partial destination failed: \(error)")
            }
        }
        let previousProfile = backup.appendingPathComponent(
            pluginInstallProfileDirectory,
            isDirectory: true
        )
        if previousProfilePresent,
           fileManager.fileExists(atPath: previousProfile.path),
           !fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.moveItem(at: previousProfile, to: destination)
            } catch {
                rollbackErrors.append("restore prior profile failed: \(error)")
            }
        }
        do {
            try restoreConfigSnapshot(
                from: backup,
                previousConfigPresent: previousConfigPresent,
                configURL: configURL
            )
        } catch {
            rollbackErrors.append("restore prior config failed: \(error)")
        }
        if rollbackErrors.isEmpty {
            throw installError
        }
        throw InstallerError(
            description: "plugin install failed: \(installError); automatic rollback incomplete: "
                + rollbackErrors.joined(separator: "; ")
                + "; install-state backup: \(backup.path)"
        )
    }
    describe("rollback backup: \(backup.path)")
    describe("Xcode active Codex agent unchanged")
    return backup
}

func restorePluginProfile(
    from backup: URL,
    xcodeCodexHome: URL,
    source: String,
    pluginName: String,
    dryRun: Bool
) throws {
    let fileManager = FileManager.default
    let quarantineRoot = pluginQuarantineRoot(
        xcodeCodexHome: xcodeCodexHome,
        pluginName: pluginName
    )
    guard isContained(backup, in: quarantineRoot) else {
        throw InstallerError(
            description: "restore path must be inside \(quarantineRoot.path)"
        )
    }
    guard fileManager.fileExists(atPath: backup.path) else {
        throw InstallerError(description: "plugin backup is missing: \(backup.path)")
    }
    let state = try readInstallState(from: backup)
    guard state.source == source, state.pluginName == pluginName else {
        throw InstallerError(description: "plugin backup identity does not match requested restore")
    }
    let version = try validatePathComponent(state.version, label: "plugin backup version")
    let previousProfile = backup.appendingPathComponent(
        pluginInstallProfileDirectory,
        isDirectory: true
    )
    if state.previousProfilePresent {
        _ = try validatePluginProfile(
            at: previousProfile,
            expectedName: pluginName,
            expectedVersion: version
        )
    }
    let configURL = xcodeCodexHome.appendingPathComponent("config.toml")
    if state.previousConfigPresent {
        let configBackup = backup.appendingPathComponent(pluginInstallConfigFilename)
        guard fileManager.fileExists(atPath: configBackup.path) else {
            throw InstallerError(description: "config backup is missing: \(configBackup.path)")
        }
    }
    let destination = pluginCacheTarget(
        xcodeCodexHome: xcodeCodexHome,
        source: source,
        pluginName: pluginName,
        version: version
    )
    let replacedBackup = try uniquePath(
        quarantineRoot.appendingPathComponent(
            "\(version)-before-restore-\(timestamp())",
            isDirectory: true
        )
    )
    describe("restore Xcode Codex plugin state: \(backup.path)")
    if fileManager.fileExists(atPath: destination.path) {
        describe("preserve replaced profile: \(destination.path) -> \(replacedBackup.path)/\(pluginInstallProfileDirectory)")
    }
    if dryRun {
        describe("dry-run: Xcode active Codex agent remains unchanged")
        return
    }

    try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    let currentProfilePresent = fileManager.fileExists(atPath: destination.path)
    let currentConfigPresent = fileManager.fileExists(atPath: configURL.path)
    let replacedState = PluginInstallState(
        schemaVersion: 1,
        source: source,
        pluginName: pluginName,
        version: version,
        previousProfilePresent: currentProfilePresent,
        previousConfigPresent: currentConfigPresent
    )
    try createInstallBackup(at: replacedBackup, state: replacedState, configURL: configURL)
    let replacedProfile = replacedBackup.appendingPathComponent(
        pluginInstallProfileDirectory,
        isDirectory: true
    )
    if currentProfilePresent {
        try fileManager.moveItem(at: destination, to: replacedProfile)
    }
    do {
        if state.previousProfilePresent {
            try copyDirectory(from: previousProfile, to: destination)
            _ = try validatePluginProfile(
                at: destination,
                expectedName: pluginName,
                expectedVersion: version
            )
        }
        try restoreConfigSnapshot(
            from: backup,
            previousConfigPresent: state.previousConfigPresent,
            configURL: configURL
        )
    } catch {
        let restoreError = error
        var recoveryErrors: [String] = []
        if fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.removeItem(at: destination)
            } catch {
                recoveryErrors.append("remove partial restored profile failed: \(error)")
            }
        }
        if currentProfilePresent,
           fileManager.fileExists(atPath: replacedProfile.path),
           !fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.moveItem(at: replacedProfile, to: destination)
            } catch {
                recoveryErrors.append("restore replaced profile failed: \(error)")
            }
        }
        do {
            try restoreConfigSnapshot(
                from: replacedBackup,
                previousConfigPresent: currentConfigPresent,
                configURL: configURL
            )
        } catch {
            recoveryErrors.append("restore replaced config failed: \(error)")
        }
        if recoveryErrors.isEmpty {
            throw restoreError
        }
        throw InstallerError(
            description: "plugin restore failed: \(restoreError); recovery incomplete: "
                + recoveryErrors.joined(separator: "; ")
                + "; requested backup: \(backup.path); preserved profile: \(replacedBackup.path)"
        )
    }
    describe("rollback backup for replaced state: \(replacedBackup.path)")
    describe("Xcode active Codex agent unchanged")
}

func installAgent(options: Options) throws {
    let payloadRoot = try options.payloadRoot ?? defaultResourceDirectory("XcodeAgent")
    let agentsRoot = options.agentsRoot ?? defaultAgentsRoot()
    let version = try resolveOnlyDirectory(
        root: payloadRoot,
        requested: options.agentVersion,
        label: "--agent-version"
    )
    let payload = payloadRoot.appendingPathComponent(version, isDirectory: true)
    let destination = agentsRoot.appendingPathComponent("codex", isDirectory: true)
        .appendingPathComponent(version, isDirectory: true)

    describe("payload_root=\(payloadRoot.path)")
    describe("agents_root=\(agentsRoot.path)")
    describe("agent_version=\(version)")
    describe("destination=\(destination.path)")
    describe("dry_run=\(options.dryRun)")

    try copyAgentPayload(
        from: payload,
        to: destination,
        force: options.force,
        dryRun: options.dryRun
    )
    try verifyAgent(at: destination, dryRun: options.dryRun)

    if options.activateAgent {
        let xcodeBuild = try options.xcodeBuild ?? detectXcodeBuild()
        try activateAgent(
            destination: destination,
            agentsRoot: agentsRoot,
            xcodeBuild: xcodeBuild,
            dryRun: options.dryRun
        )
    } else {
        describe("activation skipped; pass --activate-agent to update the active Xcode build symlink")
    }
}

@discardableResult
func installPackagedPluginProfile(options: Options) throws -> URL? {
    let source = try validatePathComponent(options.pluginSource, label: "plugin source")
    let pluginName = try validatePathComponent(options.pluginName, label: "plugin name")
    let xcodeCodexHome = options.xcodeCodexHome ?? defaultXcodeCodexHome()
    let payloadRoot = try options.pluginPayloadRoot ?? defaultResourceDirectory("XcodePluginProfile")
    try requireXcodeClosedForDefaultHome(xcodeCodexHome, dryRun: options.dryRun)
    let pluginPayloadRoot = payloadRoot.appendingPathComponent(pluginName, isDirectory: true)
    let version = try resolveOnlyDirectory(
        root: pluginPayloadRoot,
        requested: options.pluginVersion,
        label: "--plugin-version"
    )
    let payload = pluginPayloadRoot.appendingPathComponent(version, isDirectory: true)
    _ = try validatePluginProfile(
        at: payload,
        expectedName: pluginName,
        expectedVersion: version
    )
    let destination = pluginCacheTarget(
        xcodeCodexHome: xcodeCodexHome,
        source: source,
        pluginName: pluginName,
        version: version
    )
    let quarantineRoot = pluginQuarantineRoot(
        xcodeCodexHome: xcodeCodexHome,
        pluginName: pluginName
    )

    describe("plugin_payload_root=\(payloadRoot.path)")
    describe("xcode_codex_home=\(xcodeCodexHome.path)")
    describe("plugin_source=\(source)")
    describe("plugin_name=\(pluginName)")
    describe("plugin_version=\(version)")
    describe("destination=\(destination.path)")
    describe("dry_run=\(options.dryRun)")
    return try installPluginProfile(
        from: payload,
        to: destination,
        quarantineRoot: quarantineRoot,
        xcodeCodexHome: xcodeCodexHome,
        source: source,
        pluginName: pluginName,
        dryRun: options.dryRun
    )
}

func copyToPasteboard(_ value: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
}

func presentAlert(
    message: String,
    information: String,
    style: NSAlert.Style,
    primaryButton: String,
    secondaryButton: String? = nil
) -> NSApplication.ModalResponse {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = information
    alert.alertStyle = style
    alert.addButton(withTitle: primaryButton)
    if let secondaryButton {
        alert.addButton(withTitle: secondaryButton)
        if secondaryButton == "Cancel" {
            alert.buttons[1].keyEquivalent = "\u{1b}"
        }
    }
    alert.buttons[0].keyEquivalent = "\r"
    return alert.runModal()
}

func runInteractiveInstaller() -> Int32 {
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    application.finishLaunching()
    application.activate(ignoringOtherApps: true)

    let confirmation = presentAlert(
        message: "Install Apple AppDev Workflow for Xcode?",
        information: """
        Quit Xcode before continuing.

        This installs and enables the xcode-headless plugin profile in Xcode's separate Codex home. It does not replace Xcode's Codex agent or pre-trust the UserPromptSubmit hook.
        """,
        style: .informational,
        primaryButton: "Install",
        secondaryButton: "Cancel"
    )
    guard confirmation == .alertFirstButtonReturn else {
        return 0
    }

    do {
        var options = Options()
        options.installPluginProfile = true
        let backup = try installPackagedPluginProfile(options: options)
        let backupPath = backup?.path ?? "No prior state required a rollback backup."
        let completion = presentAlert(
            message: "Installation complete",
            information: """
            Apple AppDev Workflow is enabled for Xcode. Xcode's active Codex agent was not changed.

            Before opening Xcode, review and trust the UserPromptSubmit hook with stock Codex.

            Rollback backup:
            \(backupPath)
            """,
            style: .informational,
            primaryButton: "Done",
            secondaryButton: backup == nil ? nil : "Copy Rollback Path"
        )
        if completion == .alertSecondButtonReturn, let backup {
            copyToPasteboard(backup.path)
            _ = presentAlert(
                message: "Rollback path copied",
                information: "Keep the installer DMG if you may need to restore this backup later.",
                style: .informational,
                primaryButton: "Done"
            )
        }
        return 0
    } catch {
        let errorMessage = String(describing: error)
        let failure = presentAlert(
            message: "Installation failed",
            information: errorMessage,
            style: .critical,
            primaryButton: "OK",
            secondaryButton: "Copy Error"
        )
        if failure == .alertSecondButtonReturn {
            copyToPasteboard(errorMessage)
        }
        return 1
    }
}

func main() -> Int32 {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.isEmpty {
        return runInteractiveInstaller()
    }

    do {
        let options = try parseArguments(arguments)
        let modeCount = [
            options.installAgent,
            options.installPluginProfile,
            options.restorePluginBackup != nil,
        ].filter { $0 }.count
        guard modeCount == 1 else {
            print(usage())
            return 2
        }
        if options.activateAgent && !options.installAgent {
            throw InstallerError(description: "--activate-agent requires --install-agent")
        }

        if options.installAgent {
            try installAgent(options: options)
        } else if options.installPluginProfile {
            _ = try installPackagedPluginProfile(options: options)
        } else if let backup = options.restorePluginBackup {
            let source = try validatePathComponent(options.pluginSource, label: "plugin source")
            let pluginName = try validatePathComponent(options.pluginName, label: "plugin name")
            let xcodeCodexHome = options.xcodeCodexHome ?? defaultXcodeCodexHome()
            try requireXcodeClosedForDefaultHome(xcodeCodexHome, dryRun: options.dryRun)
            try restorePluginProfile(
                from: backup,
                xcodeCodexHome: xcodeCodexHome,
                source: source,
                pluginName: pluginName,
                dryRun: options.dryRun
            )
        }
        return 0
    } catch {
        fputs("error: \(error)\n", stderr)
        return 1
    }
}

Darwin.exit(main())
