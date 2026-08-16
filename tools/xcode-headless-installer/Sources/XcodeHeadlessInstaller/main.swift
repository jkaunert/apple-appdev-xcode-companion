import Foundation
import Darwin
import AppKit
import Dispatch

struct InstallerError: Error, CustomStringConvertible {
    let description: String
}

struct Options {
    var installAgent = false
    var activateAgent = false
    var installPluginProfile = false
    var installXcodeBuildMCPRuntime = false
    var reviewPluginHooks = false
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
    var xcodeBuildMCPVersion: String?
    var xcodeBuildMCPPlatform: String?
    var xcodeBuildMCPPayloadRoot: URL?
    var xcodeBuildMCPRuntimeRoot: URL?
}

struct PluginIdentity {
    let name: String
    let version: String
}

struct HookProcessResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

struct XcodeBuildMCPRuntimeIdentity {
    let version: String
    let platform: String
    let archiveSHA256: String
    let archiveSize: String
}

struct XcodeBuildMCPRuntimeInstallResult {
    let destination: URL
    let backup: URL?
    let alreadyCurrent: Bool
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
let hookRuntimeRelativePath = "hooks/runtime/node"
let hookRuntimeLicenseRelativePath = "hooks/runtime/LICENSE"
let userPromptSubmitHookCommand =
    "\"$PLUGIN_ROOT/hooks/runtime/node\" \"$PLUGIN_ROOT/hooks/apple_router.mjs\""
let stopHookCommand =
    "\"$PLUGIN_ROOT/hooks/runtime/node\" \"$PLUGIN_ROOT/hooks/apple_contract_guard.mjs\""

func usage() -> String {
    """
    Usage:
      xcode-headless-installer --install-agent [options]
      xcode-headless-installer --install-plugin-profile [options]
      xcode-headless-installer --install-xcodebuildmcp-runtime [options]
      xcode-headless-installer --review-plugin-hooks [options]
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
      --review-plugin-hooks    Open stock Codex's hook review for Xcode's Codex home.

    Portable XcodeBuildMCP runtime options:
      --install-xcodebuildmcp-runtime
                               Install the embedded, exact portable CLI/MCP runtime.
      --xcodebuildmcp-version VALUE
                               Payload version under XcodeBuildMCPRuntime/releases.
      --xcodebuildmcp-platform VALUE
                               Payload platform, such as darwin-arm64.
      --xcodebuildmcp-payload-root PATH
                               Defaults to Contents/Resources/XcodeBuildMCPRuntime.
      --xcodebuildmcp-runtime-root PATH
                               Defaults to ~/Library/Application Support/Apple AppDev Workflow/runtime/xcodebuildmcp.

    Shared options:
      --dry-run                Print actions without mutating files.
      -h, --help               Show this help.

    Plugin-profile installation never changes Xcode's active Codex agent.
    The packaged profile contains its own hook runtime; no shell Node is used.
    The portable XcodeBuildMCP runtime is shared by Desktop/CLI plugin launchers;
    installing it does not register an MCP server in Xcode CodingAssistant.
    Install and restore transactionally preserve the prior profile and config.
    """
}

func expandedDirectoryURL(_ value: String) -> URL {
    URL(
        fileURLWithPath: NSString(string: value).expandingTildeInPath,
        isDirectory: true
    )
}

func canonicalURL(_ url: URL, isDirectory: Bool) -> URL {
    guard let resolved = Darwin.realpath(url.path, nil) else {
        return url.standardizedFileURL
    }
    defer { Darwin.free(resolved) }
    return URL(fileURLWithPath: String(cString: resolved), isDirectory: isDirectory)
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
        case "--install-xcodebuildmcp-runtime":
            options.installXcodeBuildMCPRuntime = true
            index += 1
        case "--review-plugin-hooks":
            options.reviewPluginHooks = true
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
        case "--xcodebuildmcp-version":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--xcodebuildmcp-version requires a value")
            }
            options.xcodeBuildMCPVersion = arguments[index + 1]
            index += 2
        case "--xcodebuildmcp-platform":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--xcodebuildmcp-platform requires a value")
            }
            options.xcodeBuildMCPPlatform = arguments[index + 1]
            index += 2
        case "--xcodebuildmcp-payload-root":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--xcodebuildmcp-payload-root requires a value")
            }
            options.xcodeBuildMCPPayloadRoot = expandedDirectoryURL(arguments[index + 1])
            index += 2
        case "--xcodebuildmcp-runtime-root":
            guard index + 1 < arguments.count else {
                throw InstallerError(description: "--xcodebuildmcp-runtime-root requires a value")
            }
            options.xcodeBuildMCPRuntimeRoot = expandedDirectoryURL(arguments[index + 1])
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

func defaultXcodeBuildMCPRuntimeRoot() -> URL {
    URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("Library/Application Support/Apple AppDev Workflow/runtime/xcodebuildmcp", isDirectory: true)
}

func hookTrustOnboardingRoot(_ xcodeCodexHome: URL) -> URL {
    xcodeCodexHome
        .appendingPathComponent(".tmp", isDirectory: true)
        .appendingPathComponent("hook-trust-onboarding", isDirectory: true)
}

func createOrValidateRealDirectory(
    _ directory: URL,
    withIntermediateDirectories: Bool,
    label: String
) throws {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: directory.path) {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: withIntermediateDirectories
        )
    }
    let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
        throw InstallerError(description: "\(label) must be a real directory: \(directory.path)")
    }
}

func prepareHookReviewWorkspace(_ xcodeCodexHome: URL) throws -> URL {
    let temporaryRoot = xcodeCodexHome.appendingPathComponent(".tmp", isDirectory: true)
    let onboardingRoot = hookTrustOnboardingRoot(xcodeCodexHome)
    let workspace = onboardingRoot.appendingPathComponent("workspace", isDirectory: true)

    try createOrValidateRealDirectory(
        xcodeCodexHome,
        withIntermediateDirectories: true,
        label: "Xcode Codex home"
    )
    try createOrValidateRealDirectory(
        temporaryRoot,
        withIntermediateDirectories: false,
        label: "Xcode Codex temporary directory"
    )
    try createOrValidateRealDirectory(
        onboardingRoot,
        withIntermediateDirectories: false,
        label: "hook-trust onboarding directory"
    )
    try createOrValidateRealDirectory(
        workspace,
        withIntermediateDirectories: false,
        label: "hook-review workspace"
    )
    guard isContained(onboardingRoot, in: xcodeCodexHome),
          isContained(workspace, in: onboardingRoot)
    else {
        throw InstallerError(
            description: "hook-review workspace must remain inside Xcode's Codex home"
        )
    }
    return workspace
}

func xcodeCodexAgentURL(agentsRoot: URL, xcodeBuild: String) throws -> URL {
    let safeBuild = try validatePathComponent(xcodeBuild, label: "Xcode build")
    return agentsRoot
        .appendingPathComponent("XcodeVersions", isDirectory: true)
        .appendingPathComponent(safeBuild, isDirectory: true)
        .appendingPathComponent("codex", isDirectory: true)
        .appendingPathComponent("codex", isDirectory: false)
}

func reviewPluginHooks(options: Options) throws {
    let xcodeCodexHome = options.xcodeCodexHome ?? defaultXcodeCodexHome()
    let agentsRoot = options.agentsRoot ?? defaultAgentsRoot()
    let xcodeBuild = try options.xcodeBuild ?? detectXcodeBuild()
    let agent = try xcodeCodexAgentURL(agentsRoot: agentsRoot, xcodeBuild: xcodeBuild)
    let hookReviewWorkspace = hookTrustOnboardingRoot(xcodeCodexHome)
        .appendingPathComponent("workspace", isDirectory: true)
    try requireXcodeClosedForDefaultHome(xcodeCodexHome, dryRun: options.dryRun)

    describe("xcode_codex_home=\(xcodeCodexHome.path)")
    describe("xcode_build=\(xcodeBuild)")
    describe("xcode_codex_agent=\(agent.path)")
    describe("hook_review_workspace=\(hookReviewWorkspace.path)")
    if options.dryRun {
        describe("dry-run: would open stock Codex hook review for Xcode")
        return
    }

    let values = try? agent.resourceValues(forKeys: [.isRegularFileKey])
    guard values?.isRegularFile == true,
          FileManager.default.isExecutableFile(atPath: agent.path)
    else {
        throw InstallerError(
            description: "Xcode's stock Codex agent is missing or not executable: \(agent.path)"
        )
    }

    let preparedWorkspace = try prepareHookReviewWorkspace(xcodeCodexHome)
    guard FileManager.default.changeCurrentDirectoryPath(preparedWorkspace.path) else {
        throw InstallerError(description: "could not enter the dedicated hook-review workspace")
    }
    guard Darwin.setenv("CODEX_HOME", xcodeCodexHome.path, 1) == 0 else {
        throw InstallerError(description: "could not set Xcode's Codex home")
    }

    let result = agent.path.withCString { executable in
        var arguments = [UnsafeMutablePointer(mutating: executable), nil]
        return Darwin.execv(executable, &arguments)
    }
    let message = String(cString: Darwin.strerror(Darwin.errno))
    throw InstallerError(
        description: "could not execute Xcode's stock Codex agent: \(message) (\(result))"
    )
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

func readHooksManifest(at profile: URL) throws -> [String: Any] {
    let hooksURL = profile.appendingPathComponent("hooks/hooks.json")
    guard (try? hooksURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
        throw InstallerError(description: "hooks manifest is missing: \(hooksURL.path)")
    }
    do {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: hooksURL))
        guard let hooks = object as? [String: Any] else {
            throw InstallerError(description: "hooks manifest must be a JSON object: \(hooksURL.path)")
        }
        return hooks
    } catch let error as InstallerError {
        throw error
    } catch {
        throw InstallerError(description: "hooks manifest is invalid: \(hooksURL.path)")
    }
}

func hookCommand(in manifest: [String: Any], event: String) -> String? {
    guard let hooks = manifest["hooks"] as? [String: Any],
          let matchers = hooks[event] as? [[String: Any]],
          matchers.count == 1,
          let handlers = matchers[0]["hooks"] as? [[String: Any]],
          handlers.count == 1,
          handlers[0]["type"] as? String == "command"
    else {
        return nil
    }
    return handlers[0]["command"] as? String
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

func validateContainedSymbolicLinks(in payload: URL) throws {
    let canonicalPayload = canonicalURL(payload, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: payload,
        includingPropertiesForKeys: [.isSymbolicLinkKey],
        options: [],
        errorHandler: nil
    ) else {
        throw InstallerError(description: "could not enumerate runtime payload: \(payload.path)")
    }
    for case let entry as URL in enumerator {
        let values = try entry.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values.isSymbolicLink == true else {
            continue
        }
        let resolved = canonicalURL(entry, isDirectory: false)
        guard isContained(resolved, in: canonicalPayload) else {
            throw InstallerError(
                description: "runtime payload contains escaping symbolic link: \(entry.path)"
            )
        }
    }
}

func readRuntimeReceipt(at payload: URL) throws -> [String: String] {
    let receipt = payload.appendingPathComponent("runtime-receipt.env")
    let text: String
    do {
        text = try String(contentsOf: receipt, encoding: .utf8)
    } catch {
        throw InstallerError(description: "runtime receipt is missing: \(receipt.path)")
    }
    var values: [String: String] = [:]
    for rawLine in text.split(whereSeparator: { $0.isNewline }) {
        let line = String(rawLine)
        let pieces = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard pieces.count == 2 else {
            throw InstallerError(description: "runtime receipt contains malformed content")
        }
        let key = String(pieces[0])
        let value = String(pieces[1])
        guard values[key] == nil, !value.isEmpty else {
            throw InstallerError(description: "runtime receipt contains duplicate or empty fields")
        }
        values[key] = value
    }
    let required = Set([
        "SCHEMA_VERSION", "RUNTIME", "VERSION", "PLATFORM", "ARCHIVE_SHA256", "ARCHIVE_SIZE",
    ])
    guard Set(values.keys) == required,
          values["SCHEMA_VERSION"] == "1",
          values["RUNTIME"] == "xcodebuildmcp",
          values["ARCHIVE_SHA256"]?.range(
            of: #"^[0-9a-f]{64}$"#,
            options: .regularExpression
          ) != nil,
          values["ARCHIVE_SIZE"]?.range(
            of: #"^[1-9][0-9]*$"#,
            options: .regularExpression
          ) != nil
    else {
        throw InstallerError(description: "runtime receipt does not satisfy the promoted schema")
    }
    return values
}

func runPortableXcodeBuildMCP(_ executable: URL, arguments: [String]) throws -> (Int32, String) {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.environment = [
        "HOME": NSHomeDirectory(),
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "XCODEBUILDMCP_SENTRY_DISABLED": "true",
        "SENTRY_DISABLED": "true",
    ]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func validateXcodeBuildMCPRuntime(
    at payload: URL,
    expectedVersion: String? = nil,
    expectedPlatform: String? = nil
) throws -> XcodeBuildMCPRuntimeIdentity {
    let fileManager = FileManager.default
    let rootValues = try payload.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
        throw InstallerError(description: "XcodeBuildMCP runtime root must be a real directory")
    }
    try validateContainedSymbolicLinks(in: payload)
    let receipt = try readRuntimeReceipt(at: payload)
    let version = try validatePathComponent(receipt["VERSION"] ?? "", label: "XcodeBuildMCP version")
    let platform = try validatePathComponent(receipt["PLATFORM"] ?? "", label: "XcodeBuildMCP platform")
    if let expectedVersion, expectedVersion != version {
        throw InstallerError(
            description: "XcodeBuildMCP runtime version mismatch: expected \(expectedVersion); found \(version)"
        )
    }
    if let expectedPlatform, expectedPlatform != platform {
        throw InstallerError(
            description: "XcodeBuildMCP runtime platform mismatch: expected \(expectedPlatform); found \(platform)"
        )
    }

    let lockURL = payload.appendingPathComponent("runtime-lock.json")
    let lockObject: Any
    do {
        lockObject = try JSONSerialization.jsonObject(with: Data(contentsOf: lockURL))
    } catch {
        throw InstallerError(description: "XcodeBuildMCP runtime lock is missing or invalid")
    }
    guard let lock = lockObject as? [String: Any],
          lock["schemaVersion"] as? Int == 1,
          lock["runtime"] as? String == "xcodebuildmcp",
          lock["channel"] as? String == "qualified-stable",
          lock["resolvedFrom"] as? String == "latest",
          let package = lock["package"] as? [String: Any],
          package["version"] as? String == version,
          let provenance = lock["provenance"] as? [String: Any],
          provenance["repository"] as? String == "https://github.com/getsentry/XcodeBuildMCP",
          let portable = lock["portable"] as? [String: Any],
          let assets = portable["assets"] as? [String: Any],
          let asset = assets[platform] as? [String: Any],
          asset["sha256"] as? String == receipt["ARCHIVE_SHA256"],
          String(describing: asset["size"] ?? "") == receipt["ARCHIVE_SIZE"],
          let policy = lock["runtimePolicy"] as? [String: Any],
          policy["installScripts"] as? String == "forbidden",
          policy["ambientRuntimeFallback"] as? String == "forbidden",
          let telemetry = policy["telemetryEnvironment"] as? [String: Any],
          telemetry["XCODEBUILDMCP_SENTRY_DISABLED"] as? String == "true",
          telemetry["SENTRY_DISABLED"] as? String == "true",
          let workflows = policy["enabledWorkflows"] as? [String],
          workflows.contains("session-management")
    else {
        throw InstallerError(description: "XcodeBuildMCP runtime lock does not match its receipt or policy")
    }

    for relativePath in [
        "bin/xcodebuildmcp",
        "bin/xcodebuildmcp-doctor",
        "libexec/node-runtime",
        "runtime.env",
        "runtime-lock.json",
    ] {
        let file = payload.appendingPathComponent(relativePath)
        guard (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
            throw InstallerError(description: "XcodeBuildMCP runtime lacks \(relativePath)")
        }
    }
    let binary = payload.appendingPathComponent("bin/xcodebuildmcp")
    let doctor = payload.appendingPathComponent("bin/xcodebuildmcp-doctor")
    let node = payload.appendingPathComponent("libexec/node-runtime")
    guard fileManager.isExecutableFile(atPath: binary.path),
          fileManager.isExecutableFile(atPath: doctor.path),
          fileManager.isExecutableFile(atPath: node.path)
    else {
        throw InstallerError(description: "XcodeBuildMCP runtime executables are incomplete")
    }
    let (signatureStatus, signatureOutput) = try run(
        "/usr/bin/codesign",
        ["--verify", "--strict", node.path]
    )
    guard signatureStatus == 0 else {
        throw InstallerError(
            description: "XcodeBuildMCP bundled Node signature failed: "
                + signatureOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    let (versionStatus, versionOutput) = try runPortableXcodeBuildMCP(
        binary,
        arguments: ["--version"]
    )
    guard versionStatus == 0,
          versionOutput.trimmingCharacters(in: .whitespacesAndNewlines) == version
    else {
        throw InstallerError(description: "XcodeBuildMCP runtime binary version does not match receipt")
    }
    return XcodeBuildMCPRuntimeIdentity(
        version: version,
        platform: platform,
        archiveSHA256: receipt["ARCHIVE_SHA256"] ?? "",
        archiveSize: receipt["ARCHIVE_SIZE"] ?? ""
    )
}

func validatePluginProfile(
    at profile: URL,
    expectedName: String? = nil,
    expectedVersion: String? = nil,
    requireSelfContainedHooks: Bool = false
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
        "hooks/apple_contract_guard.mjs",
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
    if requireSelfContainedHooks {
        let runtime = profile.appendingPathComponent(hookRuntimeRelativePath)
        let license = profile.appendingPathComponent(hookRuntimeLicenseRelativePath)
        guard (try? runtime.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
              fileManager.isExecutableFile(atPath: runtime.path)
        else {
            throw InstallerError(
                description: "xcode-headless plugin payload lacks executable hook runtime: \(hookRuntimeRelativePath)"
            )
        }
        guard (try? license.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
            throw InstallerError(
                description: "xcode-headless plugin payload lacks hook runtime license: \(hookRuntimeLicenseRelativePath)"
            )
        }
        let hooks = try readHooksManifest(at: profile)
        guard hookCommand(in: hooks, event: "UserPromptSubmit") == userPromptSubmitHookCommand else {
            throw InstallerError(
                description: "UserPromptSubmit must use the packaged hook runtime"
            )
        }
        guard hookCommand(in: hooks, event: "Stop") == stopHookCommand else {
            throw InstallerError(description: "Stop must use the packaged hook runtime")
        }
        let (status, output) = try run(runtime.path, ["--version"])
        let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard status == 0,
              version.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+"#, options: .regularExpression) != nil
        else {
            throw InstallerError(
                description: "packaged hook runtime --version failed: \(version)"
            )
        }
    }
    return PluginIdentity(name: name, version: version)
}

func runHookProcess(
    executable: URL,
    script: URL,
    input: [String: Any],
    environment: [String: String],
    timeout: TimeInterval = 10
) throws -> HookProcessResult {
    let process = Process()
    process.executableURL = executable
    process.arguments = [script.path]
    process.environment = environment
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    let finished = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in finished.signal() }
    try process.run()
    var data = try JSONSerialization.data(withJSONObject: input, options: [.sortedKeys])
    data.append(0x0A)
    inputPipe.fileHandleForWriting.write(data)
    try inputPipe.fileHandleForWriting.close()
    if finished.wait(timeout: .now() + timeout) == .timedOut {
        process.terminate()
        if finished.wait(timeout: .now() + 2) == .timedOut {
            Darwin.kill(process.processIdentifier, SIGKILL)
            _ = finished.wait(timeout: .now() + 2)
        }
        throw InstallerError(description: "hook postflight timed out: \(script.lastPathComponent)")
    }
    process.waitUntilExit()
    let stdout = String(
        data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let stderr = String(
        data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    return HookProcessResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
}

func hookJSONOutput(_ result: HookProcessResult, label: String) throws -> [String: Any] {
    guard result.status == 0 else {
        throw InstallerError(
            description: "\(label) hook postflight failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
    let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = text.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let output = object as? [String: Any]
    else {
        throw InstallerError(
            description: "\(label) hook postflight emitted invalid JSON "
                + "(stdout_bytes=\(result.stdout.utf8.count), "
                + "stderr=\(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))"
        )
    }
    return output
}

func postflightPluginHooks(at profile: URL, xcodeCodexHome: URL) throws {
    let fileManager = FileManager.default
    let canonicalProfile = canonicalURL(profile, isDirectory: true)
    let runtime = canonicalProfile.appendingPathComponent(hookRuntimeRelativePath)
    let router = canonicalProfile.appendingPathComponent("hooks/apple_router.mjs")
    let guardScript = canonicalProfile.appendingPathComponent("hooks/apple_contract_guard.mjs")
    let identifier = "installer-postflight-\(UUID().uuidString.lowercased())"
    let stateRoot = xcodeCodexHome
        .appendingPathComponent(".tmp/apple-appdev-hook-postflight", isDirectory: true)
        .appendingPathComponent(identifier, isDirectory: true)
    defer {
        if fileManager.fileExists(atPath: stateRoot.path) {
            try? fileManager.removeItem(at: stateRoot)
        }
    }
    let environment = [
        "HOME": NSHomeDirectory(),
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "CODEX_HOME": xcodeCodexHome.path,
        "PLUGIN_ROOT": canonicalProfile.path,
        "APPLE_APPDEV_ROUTE_STATE_ROOT": stateRoot.path,
        "LANG": "en_US.UTF-8",
    ]
    let routerResult = try runHookProcess(
        executable: runtime,
        script: router,
        input: [
            "hook_event_name": "UserPromptSubmit",
            "prompt": "Build an iOS app. INSTALLER-HOOK-POSTFLIGHT",
            "cwd": canonicalProfile.path,
            "session_id": identifier,
            "turn_id": "user-prompt-submit",
        ],
        environment: environment
    )
    let routerOutput = try hookJSONOutput(routerResult, label: "UserPromptSubmit")
    let hookSpecificOutput = routerOutput["hookSpecificOutput"] as? [String: Any]
    let additionalContext = hookSpecificOutput?["additionalContext"] as? String
    guard routerOutput["continue"] as? Bool == true,
          hookSpecificOutput?["hookEventName"] as? String == "UserPromptSubmit",
          additionalContext?.contains("Routing: orchestrator-led") == true,
          additionalContext?.contains("Selected owner: apple-appdev-workflow:apple-app-orchestrator") == true,
          additionalContext?.contains("Top-level owner injection: applied") == true,
          additionalContext?.contains("Reason: prompt-signal:ios") == true
    else {
        throw InstallerError(description: "UserPromptSubmit hook postflight returned the wrong route contract")
    }
    describe("hook postflight passed under sanitized PATH: UserPromptSubmit")

    let stopResult = try runHookProcess(
        executable: runtime,
        script: guardScript,
        input: [
            "hook_event_name": "Stop",
            "session_id": identifier,
            "turn_id": "user-prompt-submit",
            "stop_hook_active": false,
            "last_assistant_message": "Installer postflight intentionally omits the Apple final-output contract.",
        ],
        environment: environment
    )
    let stopOutput = try hookJSONOutput(stopResult, label: "Stop")
    guard stopOutput["decision"] as? String == "block",
          (stopOutput["reason"] as? String)?.contains("Apple workflow final-output contract failed") == true
    else {
        throw InstallerError(description: "Stop hook postflight did not enforce one correction")
    }
    describe("hook postflight passed under sanitized PATH: Stop")

    let retryResult = try runHookProcess(
        executable: runtime,
        script: guardScript,
        input: [
            "hook_event_name": "Stop",
            "session_id": identifier,
            "turn_id": "user-prompt-submit",
            "stop_hook_active": true,
            "last_assistant_message": "Installer postflight retry sentinel.",
        ],
        environment: environment
    )
    guard retryResult.status == 0,
          retryResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
        throw InstallerError(description: "Stop hook postflight attempted more than one correction")
    }
    describe("hook postflight passed under sanitized PATH: Stop one-retry guard")
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
    let identity = try validatePluginProfile(at: payload, requireSelfContainedHooks: true)
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
        describe("dry-run: would postflight UserPromptSubmit and Stop under sanitized PATH")
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
            expectedVersion: identity.version,
            requireSelfContainedHooks: true
        )
        try postflightPluginHooks(at: destination, xcodeCodexHome: xcodeCodexHome)
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

func installXcodeBuildMCPRuntime(
    from payload: URL,
    to runtimeRoot: URL,
    force: Bool,
    dryRun: Bool
) throws -> XcodeBuildMCPRuntimeInstallResult {
    let fileManager = FileManager.default
    let identity = try validateXcodeBuildMCPRuntime(at: payload)
    let destination = runtimeRoot
        .appendingPathComponent("releases", isDirectory: true)
        .appendingPathComponent(identity.version, isDirectory: true)
        .appendingPathComponent(identity.platform, isDirectory: true)

    if fileManager.fileExists(atPath: destination.path) {
        do {
            let existing = try validateXcodeBuildMCPRuntime(
                at: destination,
                expectedVersion: identity.version,
                expectedPlatform: identity.platform
            )
            if existing.archiveSHA256 == identity.archiveSHA256,
               existing.archiveSize == identity.archiveSize {
                describe("plugin-owned XcodeBuildMCP runtime is already current: \(destination.path)")
                return XcodeBuildMCPRuntimeInstallResult(
                    destination: destination,
                    backup: nil,
                    alreadyCurrent: true
                )
            }
        } catch {
            guard force else {
                throw InstallerError(
                    description: "existing XcodeBuildMCP runtime is invalid; pass --force to preserve and replace it: \(error)"
                )
            }
        }
        guard force else {
            throw InstallerError(
                description: "existing XcodeBuildMCP runtime does not match the embedded promoted payload; pass --force to preserve and replace it"
            )
        }
    }

    let backup = fileManager.fileExists(atPath: destination.path)
        ? try uniquePath(
            runtimeRoot.appendingPathComponent("backups", isDirectory: true)
                .appendingPathComponent(
                    "\(identity.version)-\(identity.platform)-\(timestamp())",
                    isDirectory: true
                )
        )
        : nil
    describe("install plugin-owned XcodeBuildMCP runtime: \(payload.path) -> \(destination.path)")
    if let backup {
        describe("preserve previous XcodeBuildMCP runtime: \(destination.path) -> \(backup.path)")
    }
    if dryRun {
        return XcodeBuildMCPRuntimeInstallResult(
            destination: destination,
            backup: backup,
            alreadyCurrent: false
        )
    }

    try createOrValidateRealDirectory(
        runtimeRoot,
        withIntermediateDirectories: true,
        label: "XcodeBuildMCP shared runtime root"
    )
    let releasesRoot = runtimeRoot.appendingPathComponent("releases", isDirectory: true)
    let backupsRoot = runtimeRoot.appendingPathComponent("backups", isDirectory: true)
    try createOrValidateRealDirectory(
        releasesRoot,
        withIntermediateDirectories: false,
        label: "XcodeBuildMCP releases directory"
    )
    try createOrValidateRealDirectory(
        backupsRoot,
        withIntermediateDirectories: false,
        label: "XcodeBuildMCP backups directory"
    )
    let stagingRoot = runtimeRoot.appendingPathComponent(
        ".install-\(UUID().uuidString.lowercased())",
        isDirectory: true
    )
    let stagingPayload = stagingRoot.appendingPathComponent("payload", isDirectory: true)
    try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: false)
    defer {
        if fileManager.fileExists(atPath: stagingRoot.path) {
            try? fileManager.removeItem(at: stagingRoot)
        }
    }
    try copyDirectory(from: payload, to: stagingPayload)
    _ = try validateXcodeBuildMCPRuntime(
        at: stagingPayload,
        expectedVersion: identity.version,
        expectedPlatform: identity.platform
    )
    try fileManager.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    if let backup {
        try fileManager.moveItem(at: destination, to: backup)
    }
    do {
        try fileManager.moveItem(at: stagingPayload, to: destination)
        _ = try validateXcodeBuildMCPRuntime(
            at: destination,
            expectedVersion: identity.version,
            expectedPlatform: identity.platform
        )
    } catch {
        let installError = error
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        if let backup,
           fileManager.fileExists(atPath: backup.path),
           !fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.moveItem(at: backup, to: destination)
            } catch {
                throw InstallerError(
                    description: "XcodeBuildMCP runtime install failed: \(installError); rollback failed: \(error); backup: \(backup.path)"
                )
            }
        }
        throw installError
    }
    describe("installed plugin-owned XcodeBuildMCP runtime: \(destination.path)")
    describe("Xcode CodingAssistant MCP ownership unchanged")
    return XcodeBuildMCPRuntimeInstallResult(
        destination: destination,
        backup: backup,
        alreadyCurrent: false
    )
}

func installPackagedXcodeBuildMCPRuntime(options: Options) throws -> XcodeBuildMCPRuntimeInstallResult {
    let payloadRoot = try options.xcodeBuildMCPPayloadRoot
        ?? defaultResourceDirectory("XcodeBuildMCPRuntime")
    let releasesRoot = payloadRoot.appendingPathComponent("releases", isDirectory: true)
    let version = try resolveOnlyDirectory(
        root: releasesRoot,
        requested: options.xcodeBuildMCPVersion,
        label: "--xcodebuildmcp-version"
    )
    let versionRoot = releasesRoot.appendingPathComponent(version, isDirectory: true)
    let platform = try resolveOnlyDirectory(
        root: versionRoot,
        requested: options.xcodeBuildMCPPlatform,
        label: "--xcodebuildmcp-platform"
    )
    let payload = versionRoot.appendingPathComponent(platform, isDirectory: true)
    _ = try validateXcodeBuildMCPRuntime(
        at: payload,
        expectedVersion: version,
        expectedPlatform: platform
    )
    let runtimeRoot = options.xcodeBuildMCPRuntimeRoot ?? defaultXcodeBuildMCPRuntimeRoot()
    describe("xcodebuildmcp_payload_root=\(payloadRoot.path)")
    describe("xcodebuildmcp_runtime_root=\(runtimeRoot.path)")
    describe("xcodebuildmcp_version=\(version)")
    describe("xcodebuildmcp_platform=\(platform)")
    describe("dry_run=\(options.dryRun)")
    return try installXcodeBuildMCPRuntime(
        from: payload,
        to: runtimeRoot,
        force: options.force,
        dryRun: options.dryRun
    )
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
        expectedVersion: version,
        requireSelfContainedHooks: true
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

func shellSingleQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}

func launchHookReviewInTerminal() throws {
    guard let installer = Bundle.main.executableURL else {
        throw InstallerError(description: "could not resolve the installer executable")
    }
    let fileManager = FileManager.default
    let xcodeCodexHome = defaultXcodeCodexHome()
    _ = try prepareHookReviewWorkspace(xcodeCodexHome)
    let launcherRoot = hookTrustOnboardingRoot(xcodeCodexHome)
    let launcher = try uniquePath(
        launcherRoot.appendingPathComponent(
            "review-hooks-\(timestamp()).command",
            isDirectory: false
        )
    )
    let script = """
    #!/bin/zsh
    launcherPath="$0"
    cleanup() { /bin/rm -f -- "$launcherPath"; }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM
    \(shellSingleQuoted(installer.path)) --review-plugin-hooks
    """
    guard let data = script.data(using: .utf8) else {
        throw InstallerError(description: "could not encode the hook-review launcher")
    }
    try data.write(to: launcher, options: .atomic)
    try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launcher.path)
    guard NSWorkspace.shared.open(launcher) else {
        try? fileManager.removeItem(at: launcher)
        throw InstallerError(description: "Terminal did not open the stock Codex hook review")
    }
}

func launchHookReviewOrPresentFailure() {
    do {
        try launchHookReviewInTerminal()
    } catch {
        _ = presentAlert(
            message: "Hook review did not open",
            information: "The profile is installed, but Terminal could not open stock Codex. \(error)",
            style: .warning,
            primaryButton: "OK"
        )
    }
}

func presentAlert(
    message: String,
    information: String,
    style: NSAlert.Style,
    primaryButton: String,
    secondaryButton: String? = nil,
    tertiaryButton: String? = nil
) -> NSApplication.ModalResponse {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = information
    alert.alertStyle = style
    alert.addButton(withTitle: primaryButton)
    if let secondaryButton {
        alert.addButton(withTitle: secondaryButton)
        if secondaryButton == "Cancel" || secondaryButton == "Done" {
            alert.buttons[1].keyEquivalent = "\u{1b}"
        }
    }
    if let tertiaryButton {
        alert.addButton(withTitle: tertiaryButton)
        if tertiaryButton == "Cancel" || tertiaryButton == "Done" {
            alert.buttons[2].keyEquivalent = "\u{1b}"
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

        This installs and enables the xcode-headless plugin profile in Xcode's separate Codex home and installs the exact promoted XcodeBuildMCP portable runtime for Desktop/CLI plugin fallback. Neither payload depends on Homebrew, Malt, or your shell PATH. The portable runtime is not registered inside Xcode, does not replace native xcode-tools, and does not replace Xcode's Codex agent or pre-trust either lifecycle hook: UserPromptSubmit or Stop.
        """,
        style: .informational,
        primaryButton: "Install",
        secondaryButton: "Cancel"
    )
    guard confirmation == .alertFirstButtonReturn else {
        return 0
    }

    do {
        var runtimeOptions = Options()
        runtimeOptions.installXcodeBuildMCPRuntime = true
        let runtimeResult = try installPackagedXcodeBuildMCPRuntime(options: runtimeOptions)
        var options = Options()
        options.installPluginProfile = true
        let backup = try installPackagedPluginProfile(options: options)
        let backupPath = backup?.path ?? "No prior state required a rollback backup."
        let runtimeBackupPath = runtimeResult.backup?.path
            ?? (runtimeResult.alreadyCurrent
                ? "The exact portable runtime was already installed."
                : "No prior portable runtime required a rollback backup.")
        let completion = presentAlert(
            message: "Installation complete",
            information: """
            Apple AppDev Workflow is enabled for Xcode. Both lifecycle hooks passed an automatic sanitized-PATH postflight. The exact plugin-owned XcodeBuildMCP runtime is available to Desktop/CLI launchers at:
            \(runtimeResult.destination.path)

            Xcode still owns native tool execution; no Xcode MCP registration or active Codex agent was changed.

            Before opening Xcode, review and trust each lifecycle hook: UserPromptSubmit and Stop. Review Hooks opens Xcode's stock Codex in Terminal. Stock Codex may first ask you to trust its dedicated empty hook-review workspace; that trust does not apply to your home or projects. Inspect each hook command and source before trusting it. If startup hook review is not shown, enter /hooks.

            Rollback backup:
            \(backupPath)

            Portable runtime rollback:
            \(runtimeBackupPath)
            """,
            style: .informational,
            primaryButton: "Review Hooks",
            secondaryButton: backup == nil ? "Done" : "Copy Rollback Path",
            tertiaryButton: backup == nil ? nil : "Done"
        )
        if completion == .alertFirstButtonReturn {
            launchHookReviewOrPresentFailure()
        } else if completion == .alertSecondButtonReturn, let backup {
            copyToPasteboard(backup.path)
            let copied = presentAlert(
                message: "Rollback path copied",
                information: "Keep the installer DMG if you may need to restore this backup later. Review both lifecycle hooks before opening Xcode.",
                style: .informational,
                primaryButton: "Review Hooks",
                secondaryButton: "Done"
            )
            if copied == .alertFirstButtonReturn {
                launchHookReviewOrPresentFailure()
            }
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
            options.installXcodeBuildMCPRuntime,
            options.reviewPluginHooks,
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
        } else if options.installXcodeBuildMCPRuntime {
            _ = try installPackagedXcodeBuildMCPRuntime(options: options)
        } else if options.installPluginProfile {
            _ = try installPackagedPluginProfile(options: options)
        } else if options.reviewPluginHooks {
            try reviewPluginHooks(options: options)
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
