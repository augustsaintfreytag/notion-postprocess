//
//  Notion Postprocessor
//

import Foundation

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
	func rewrittenDocumentContents(_ contents: String) -> String {
		return try! contents
			.removingMatches(matching: #"^# .+?\n\s+"#)
			.replacingMatches(matching: #"<aside>\s*(.+?)\s*</aside>"#, with: "> $1")
	}
	
	/// Finds paths to resources inside the given document contents and rewrites
	func rewrittenDocumentResourceLinks(_ contents: String, index: CanonicalNameIndex) -> String {
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
			
			var rewrittenPath = originalPath
			
			for (originalName, canonicalName) in index {
				rewrittenPath = rewrittenPath.replacingOccurrences(of: originalName, with: canonicalName)
			}
			
			paths.append((String(matchedPathString), rewrittenPath))
		}
		
		var rewrittenContents = contents
		
		for (match, replacement) in paths {
			rewrittenContents = rewrittenContents.replacingOccurrences(of: match, with: replacement)
		}
		
		return rewrittenContents
	}
	
	// MARK: Name Indexing
	
	func indexCanonicalDocumentNames(in directory: URL) throws -> CanonicalNameIndex {
		var cachedNames = CanonicalNameIndex()
		let (documents, directories) = try fileURLs(in: directory)
		
		for directory in directories {
			let cachedDirectoryNames = try indexCanonicalDocumentNames(in: directory)
			cachedNames.merge(cachedDirectoryNames) { _, newKey in newKey }
		}
		
		for document in documents {
			guard let canonicalDocumentName = try canonicalDocumentName(forDocumentAt: document) else {
				print("Could not determine canonical name for file '\(document.path)'.")
				continue
			}
			
			let originalDocumentName = try document.lastPathComponent.removingMatches(matching: #"\.\w+$"#)
			cachedNames[originalDocumentName] = canonicalDocumentName
		}
		
		return cachedNames
	}
	
}
