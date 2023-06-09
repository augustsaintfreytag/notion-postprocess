//
//  Notion Postprocess
//

import Foundation
import ArgumentParser

///
/// Main procedure for processing:
///
/// - Move per directory level (recursive action)
/// - Find all markdown files in directory
/// - Check for corresponding subdirectory of same name
/// - Correct name (read top level heading in `.md` file)
///

@main struct NotionPostprocess: ParsableCommand, RewriteCommand, RegroupCommand {
	
	static let configuration = CommandConfiguration(
		commandName: Manifest.command,
		abstract: "Process and rewrite data exported from Notion for import and use in Craft.",
		discussion: lines(
			"The utility processes a Markdown export from Notion, either of a single page or a whole workspace.",
			"Note that Notion produces a compressed ZIP archive by default, the utility expects an extracted directory structure.",
			"The passed input directory and files are *changed in place*.",
			"All operation modes should be considered not idempotent, it is recommended to",
			"keep a backup of the exported data should the migration encounter issues."
		),
		version: "\(Manifest.name), Version \(Manifest.versionDescription)",
		helpNames: [.customShort("?"), .long]
	)
	
	// MARK: Parameters
	
	@Argument(help: "The mode of operation. (options: \(Mode.allCasesHelpDescription))")
	var mode: Mode
	
	@Argument(help: "Path to the directory exported from Notion to be processed.", completion: CompletionKind.directory)
	var inputPath: String
	
	@Flag(help: "Print the changes made to the input but do not not execute them.")
	var dryRun: Bool = false
	
	// MARK: State
	
	var profile = PerformanceProfile()
	
	// MARK: Run
	
	func run() throws {
		let directory = URL(fileURLWithPath: inputPath, isDirectory: true).standardizedFileURL
		
		switch mode {
		case .all:
			try processDocuments(in: directory)
			try groupDocuments(in: directory)
		case .rewrite:
			try processDocuments(in: directory)
		case .regroup:
			try groupDocuments(in: directory)
		}
		
		print(profile.counts)
	}
	
}

extension NotionPostprocess {
	
	enum CodingKeys: CodingKey {
		case mode
		case inputPath
		case dryRun
	}
	
}

// MARK: Mode

enum Mode: String, CaseIterable, ExpressibleByArgument {
	case all
	case rewrite
	case regroup
}

// MARK: Performance

class PerformanceProfile: Codable {
	
	private(set) var counts: [String: Int] = [:]
	
	func tick(_ key: String) {
		counts[key] = count(for: key) + 1
	}
	
	func count(for key: String) -> Int {
		return counts[key] ?? 0
	}
	
}
