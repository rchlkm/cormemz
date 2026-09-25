// CoreMems/Services/PersistedStateDump.swift
#if DEBUG
  import Foundation

  /// Debug-only report of everything the app persists: the `core-mems-*.json`
  /// files in Application Support and the `cm_*` UserDefaults keys. Written to
  /// the temporary directory; Settings can share or delete the file.
  enum PersistedStateDump {
    static let enabledKey = "cm_debugStateDumpEnabled"

    private static let filePrefix = "core-mems-"
    private static let defaultsKeyPrefix = "cm_"

    static let reportURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("core-mems-state-dump.txt")

    /// Dumps only while the Settings toggle is on.
    static func runIfEnabled(reason: String) {
      guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
      run(reason: reason)
    }

    /// Prints the report and writes it to `reportURL`.
    static func run(reason: String) {
      let report = makeReport(reason: reason)
      print(report)
      try? report.write(to: reportURL, atomically: true, encoding: .utf8)
      print("[CoreMems] state dump written to \(reportURL.path)")
    }

    static var reportExists: Bool { FileManager.default.fileExists(atPath: reportURL.path) }

    static func deleteReport() {
      try? FileManager.default.removeItem(at: reportURL)
    }

    private static func makeReport(reason: String) -> String {
      let files = persistedFiles()
      let defaults = persistedDefaults()
      let defaultsBytes = defaults.reduce(0) { $0 + $1.value.utf8.count }
      let totalBytes = files.reduce(0) { $0 + $1.size } + defaultsBytes

      var lines = ["[CoreMems] persisted state (\(reason)) — total \(format(totalBytes))"]
      for file in files {
        lines.append("\n== \(file.name) — \(format(file.size))\n\(file.contents)")
      }
      lines.append("\n== UserDefaults (\(defaultsKeyPrefix)*) — \(format(defaultsBytes))")
      lines += defaults.map { "\($0.key) = \($0.value)" }
      return lines.joined(separator: "\n")
    }

    private static func persistedFiles() -> [(name: String, size: Int, contents: String)] {
      guard
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
          .first,
        let urls = try? FileManager.default.contentsOfDirectory(
          at: dir, includingPropertiesForKeys: nil)
      else { return [] }
      return urls
        .filter { $0.lastPathComponent.hasPrefix(filePrefix) && $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .compactMap { url in
          guard let data = try? Data(contentsOf: url) else { return nil }
          return (url.lastPathComponent, data.count, prettyPrinted(data))
        }
    }

    private static func persistedDefaults() -> [(key: String, value: String)] {
      UserDefaults.standard.dictionaryRepresentation()
        .filter { $0.key.hasPrefix(defaultsKeyPrefix) }
        .map { ($0.key, "\($0.value)") }
        .sorted { $0.key < $1.key }
    }

    private static func prettyPrinted(_ data: Data) -> String {
      guard let object = try? JSONSerialization.jsonObject(with: data),
        let pretty = try? JSONSerialization.data(
          withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
        let text = String(data: pretty, encoding: .utf8)
      else { return String(decoding: data, as: UTF8.self) }
      return text
    }

    private static func format(_ bytes: Int) -> String {
      "\(bytes) bytes (\(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)))"
    }
  }
#endif
