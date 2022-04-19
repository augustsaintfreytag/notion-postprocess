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
struct NotionPostprocessor: ParsableCommand, DirectoryEnumerator, DocumentNameProvider {
	
	@Argument(help: "Path to the directory exported from Notion to be processed.", completion: CompletionKind.directory)
	var inputPath: String
	
	@Flag(help: "Prints out the changes that would be made to the input directory and its files but does not execute them.")
	var dryRun: Bool = false
	
	// MARK: Run
	
	func run() throws {
		let inputURL = URL(fileURLWithPath: inputPath, isDirectory: true).standardizedFileURL
		try processAllDocuments(in: inputURL)
	}
	
	// MARK: Processing (TBD)
	
	func processAllDocuments(in directory: URL) throws {
		let fileURLs = try documentFileURLs(in: directory)
		
		for fileURL in fileURLs {
			try processDocumentAndAssociates(at: fileURL)
		}
	}
	
	/// Takes the document at the given URL and determines its restorable name.
	/// Further tries to locate an associate ("nested page") directory to be processed.
	func processDocumentAndAssociates(at url: URL) throws {
		assert(FileManager.default.fileExists(atPath: url.path), "File manager integrity assertion failed, can not determine own path.")
		
		// Preparation
		guard let canonicalDocumentName = try canonicalDocumentName(forDocumentAt: url) else {
			throw ProcessingError(kind: .missingData, description: "Could not read canonical document name for file at path '\(url.path)'.")
		}
		
		let fileName = url.lastPathComponent
		let associateDirectoryName = try fileName.removingMatches(matching: #"\.\w+$"#)
		
		assert(fileName != associateDirectoryName, "Derived associate directory name transformation not valid; transform produced '\(associateDirectoryName)'.")
		
		let parentDirectoryURL = url.deletingLastPathComponent()
		let associateDirectoryURL = parentDirectoryURL.appendingPathComponent(associateDirectoryName, isDirectory: true)
		
		let hasAssociateDirectory = FileManager.default.fileExists(atPath: associateDirectoryURL.path)
		
		// Execution
		if dryRun {
			print("Operations in path '\(parentDirectoryURL.path)':")
			print("Document rename: '\(fileName)' → '\(canonicalDocumentName).md'")
			
			if hasAssociateDirectory {
				print("Directory rename: '\(associateDirectoryName)' → '\(canonicalDocumentName)'")
			}
		}
	}
	
}

// MARK: Enumeration

protocol DirectoryEnumerator {}

extension DirectoryEnumerator {
	
	func documentFileURLs(in directory: URL) throws -> [URL] {
		let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
		
		return fileURLs.filter { url in
			url.lastPathComponent.contains(".md")
		}
	}
	
}

// MARK: Document Names

protocol DocumentNameProvider {}

extension DocumentNameProvider {
	
	private var firstHeadingMatchPattern: String { #"# (.+)\n"# }
	
	/// Reads the document at the given URL and returns its canonical name if possible.
	func canonicalDocumentName(forDocumentAt fileURL: URL) throws -> String? {
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
