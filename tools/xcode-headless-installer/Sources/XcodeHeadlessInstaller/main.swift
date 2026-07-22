import Foundation
import Darwin

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
      --install-plugin-profile Copy the embedded xcode-headless plugin profile.
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
    Replacing an existing same-version profile always creates a rollback backup.
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
    dryRun: Bool
) throws -> URL? {
    let fileManager = FileManager.default
    let identity = try validatePluginProfile(at: payload)
    var backup: URL?
    if fileManager.fileExists(atPath: destination.path) {
        backup = try uniquePath(
            quarantineRoot.appendingPathComponent(
                "\(identity.version)-full-plugin-cache-\(timestamp())",
                isDirectory: true
            )
        )
        describe("backup existing plugin profile: \(destination.path) -> \(backup!.path)")
    }
    describe("install xcode-headless plugin profile: \(payload.path) -> \(destination.path)")
    if dryRun {
        describe("dry-run: Xcode active Codex agent remains unchanged")
        return backup
    }

    try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let backup {
        try fileManager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: destination, to: backup)
    }
    do {
        try copyDirectory(from: payload, to: destination)
        _ = try validatePluginProfile(
            at: destination,
            expectedName: identity.name,
            expectedVersion: identity.version
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
        if let backup, fileManager.fileExists(atPath: backup.path),
           !fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.moveItem(at: backup, to: destination)
            } catch {
                rollbackErrors.append("restore prior profile failed: \(error)")
            }
        }
        if rollbackErrors.isEmpty {
            throw installError
        }
        let backupLocation = backup?.path ?? "none"
        throw InstallerError(
            description: "plugin install failed: \(installError); automatic rollback incomplete: "
                + rollbackErrors.joined(separator: "; ")
                + "; prior-profile backup: \(backupLocation)"
        )
    }
    if let backup {
        describe("rollback backup: \(backup.path)")
    }
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
    let identity = try validatePluginProfile(at: backup, expectedName: pluginName)
    let destination = pluginCacheTarget(
        xcodeCodexHome: xcodeCodexHome,
        source: source,
        pluginName: pluginName,
        version: identity.version
    )
    let replacedBackup = try uniquePath(
        quarantineRoot.appendingPathComponent(
            "\(identity.version)-before-restore-\(timestamp())",
            isDirectory: true
        )
    )
    describe("restore xcode-headless plugin profile: \(backup.path) -> \(destination.path)")
    if fileManager.fileExists(atPath: destination.path) {
        describe("preserve replaced profile: \(destination.path) -> \(replacedBackup.path)")
    }
    if dryRun {
        describe("dry-run: Xcode active Codex agent remains unchanged")
        return
    }

    try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    var preservedCurrent = false
    if fileManager.fileExists(atPath: destination.path) {
        try fileManager.createDirectory(
            at: replacedBackup.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(at: destination, to: replacedBackup)
        preservedCurrent = true
    }
    var requestedBackupMoved = false
    do {
        try fileManager.moveItem(at: backup, to: destination)
        requestedBackupMoved = true
        _ = try validatePluginProfile(
            at: destination,
            expectedName: pluginName,
            expectedVersion: identity.version
        )
    } catch {
        let restoreError = error
        var recoveryErrors: [String] = []
        if requestedBackupMoved,
           fileManager.fileExists(atPath: destination.path),
           !fileManager.fileExists(atPath: backup.path) {
            do {
                try fileManager.moveItem(at: destination, to: backup)
            } catch {
                recoveryErrors.append("preserve requested backup failed: \(error)")
            }
        }
        if preservedCurrent,
           fileManager.fileExists(atPath: replacedBackup.path),
           !fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.moveItem(at: replacedBackup, to: destination)
            } catch {
                recoveryErrors.append("restore replaced profile failed: \(error)")
            }
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
    if preservedCurrent {
        describe("rollback backup for replaced profile: \(replacedBackup.path)")
    }
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

func installPackagedPluginProfile(options: Options) throws {
    let source = try validatePathComponent(options.pluginSource, label: "plugin source")
    let pluginName = try validatePathComponent(options.pluginName, label: "plugin name")
    let xcodeCodexHome = options.xcodeCodexHome ?? defaultXcodeCodexHome()
    let payloadRoot = try options.pluginPayloadRoot ?? defaultResourceDirectory("XcodePluginProfile")
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
    try installPluginProfile(
        from: payload,
        to: destination,
        quarantineRoot: quarantineRoot,
        dryRun: options.dryRun
    )
}

func main() -> Int32 {
    do {
        let options = try parseArguments(Array(CommandLine.arguments.dropFirst()))
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
            try installPackagedPluginProfile(options: options)
        } else if let backup = options.restorePluginBackup {
            let source = try validatePathComponent(options.pluginSource, label: "plugin source")
            let pluginName = try validatePathComponent(options.pluginName, label: "plugin name")
            let xcodeCodexHome = options.xcodeCodexHome ?? defaultXcodeCodexHome()
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
