//
//  Notion Postprocessor
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

@main struct NotionPostprocessor: ParsableCommand, RewriteCommand, RegroupCommand {
	
	// MARK: Parameters
	
	@Argument(help: "The mode of operation. (options: \(Mode.allCasesHelpDescription)) (default: both)")
	var mode: Mode?
	
	@Argument(help: "Path to the directory exported from Notion to be processed.", completion: CompletionKind.directory)
	var inputPath: String
	
	@Flag(help: "Prints out the changes that would be made to the input but does not execute them.")
	var dryRun: Bool = false
	
	// MARK: State
	
	var profile = PerformanceProfile()
	
	// MARK: Run
	
	func run() throws {
		let directory = URL(fileURLWithPath: inputPath, isDirectory: true).standardizedFileURL
		
		switch mode {
		case .none:
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

extension NotionPostprocessor {
	
	enum CodingKeys: CodingKey {
		case mode
		case inputPath
		case dryRun
	}
	
}

// MARK: Mode

enum Mode: String, CaseIterable, ExpressibleByArgument {
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
