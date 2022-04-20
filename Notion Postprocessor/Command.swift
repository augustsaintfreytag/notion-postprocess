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

@main
struct NotionPostprocessor: ParsableCommand, DocumentProcessor {
	
	@Argument(help: "Path to the directory exported from Notion to be processed.", completion: CompletionKind.directory)
	var inputPath: String
	
	@Flag(help: "Prints out the changes that would be made to the input directory and its files but does not execute them.")
	var dryRun: Bool = false
	
	// MARK: Run
	
	func run() throws {
		let directory = URL(fileURLWithPath: inputPath, isDirectory: true).standardizedFileURL
		try processDocuments(in: directory)
	}
	
}
