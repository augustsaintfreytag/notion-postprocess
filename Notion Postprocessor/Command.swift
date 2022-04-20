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
		let inputURL = URL(fileURLWithPath: inputPath, isDirectory: true).standardizedFileURL
		try processAllDocuments(in: inputURL)
	}
	
}

// MARK: File Contents

protocol DocumentProcessor: DirectoryEnumerator, DocumentNameProvider {
	
	var dryRun: Bool { get }
	
}

extension DocumentProcessor {
	
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
		
		let documentName = url.lastPathComponent
		let associateDirectoryName = try documentName.removingMatches(matching: #"\.\w+$"#)
		
		assert(documentName != associateDirectoryName, "Derived associate directory name transformation not valid; transform produced '\(associateDirectoryName)'.")
		
		let parentDirectoryURL = url.deletingLastPathComponent()
		let associateDirectoryURL = parentDirectoryURL.appendingPathComponent(associateDirectoryName, isDirectory: true)
		
		let hasAssociateDirectory = FileManager.default.fileExists(atPath: associateDirectoryURL.path)
		
		// Execution
		if dryRun {
			print("Operations in path '\(parentDirectoryURL.path)':")
			print("Document rename: '\(documentName)' → '\(canonicalDocumentName).md'")
			
			var documentContents = try documentContents(at: url)
			documentContents = processDocumentContents(documentContents)
			documentContents = rewriteDocumentResourceLinks(documentContents, names: (original: associateDirectoryName, canonical: canonicalDocumentName))
			
			print("Rewrite document to: \n\(documentContents)")
			
			if hasAssociateDirectory {
				print("Directory rename: '\(associateDirectoryName)' → '\(canonicalDocumentName)'")
			}
		}
	}
	
	/// Reads and rewrites the document, applies transformations for destination format.
	///
	/// This function may perform the following:
	///   - Detect callout blocks (beginning of line, emoji, text until newline)
	func processDocumentContents(_ contents: String) -> String {
		return try! contents
			.removingMatches(matching: #"^# .+?\n\s+"#)
			.replacingMatches(matching: #"<aside>\s*(.+?)\s*</aside>"#, with: "> $1")
	}
	
	/// Finds paths to resources inside the given document contents and rewrites
	func rewriteDocumentResourceLinks(_ contents: String, names: (original: String, canonical: String)) -> String {
		// return try! contents.replacingOccurrences(of: names.original, with: names.canonical)
		let matches = try! contents.allMatchGroups(#"\[.+?]\((.+?)\)"#)
		var paths: [(match: String, replacement: String)] = []
		
		for match in matches {
			guard let matchedPathString = match[1], let originalPath = matchedPathString.removingPercentEncoding else {
				continue
			}
			
			// Skip external paths
			guard !originalPath.contains("http") else {
				continue
			}
			
			let rewrittenPath = originalPath.replacingOccurrences(of: names.original, with: names.canonical)
			paths.append((String(matchedPathString), rewrittenPath))
		}
		
		var rewrittenContents = contents
		
		for (match, replacement) in paths {
			rewrittenContents = rewrittenContents.replacingOccurrences(of: match, with: replacement)
		}
		
		return rewrittenContents
	}
	
}

// MARK: Document Names

protocol DocumentNameProvider: FileReader {}

extension DocumentNameProvider {
	
	private var firstHeadingMatchPattern: String { #"# (.+)\n"# }
	
	/// Reads the document at the given URL and returns its canonical name if possible.
	func canonicalDocumentName(forDocumentAt fileURL: URL) throws -> String? {
		let contents = try documentContents(at: fileURL)
		return documentName(fromFileContents: contents)
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
