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
struct NotionPostprocessor: ParsableCommand, DirectoryEnumerator, DocumentNameRestoration {
	
	@Argument(help: "Path to the directory exported from Notion to be processed.", completion: CompletionKind.directory)
	var inputPath: String
	
	func run() throws {
		let inputURL = URL(fileURLWithPath: inputPath, isDirectory: true).standardizedFileURL
		let fileURLs = try markdownFileURLs(in: inputURL)
		
		print("File URLs:")
		fileURLs.forEach { url in print(url.path) }
	}
	
	func processAllDocuments(in directory: URL) throws {
		// …
	}
	
	func processDocumentAndAssociates(_ url: URL) throws {
		// …
	}
	
}

// MARK: Enumeration

protocol DirectoryEnumerator {}

extension DirectoryEnumerator {
	
	func markdownFileURLs(in directory: URL) throws -> [URL] {
		print("Getting list of files in input directory '\(directory.path)'.")
		
		let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
		
		return fileURLs
	}
	
}

// MARK: Document Names

protocol DocumentNameRestoration {}

extension DocumentNameRestoration {
	
	private var firstHeadingMatchPattern: String { #"# (\w+)\n"# }
	
	/// Reads the document at the given URL and returns its restore name if possible.
	func restoredDocumentName(forDocumentAt fileURL: URL) throws -> String? {
		let fileData = try Data(contentsOf: fileURL)
		
		guard let fileContents = String(data: fileData, encoding: .utf8) else {
			return nil
		}
		
		return documentName(fromFileContents: fileContents)
	}
	
	/// Extracts the first found (first level) heading from the given document contents 
	/// and returns the trimmed matching string.
	func documentName(fromFileContents fileContents: String) -> String? {
		let matchCaptureGroups = try! fileContents.firstMatchGroups(firstHeadingMatchPattern)
		
		guard let headingSubstring = matchCaptureGroups?[1] else {
			return nil
		}
		
		return String(headingSubstring).trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
}
