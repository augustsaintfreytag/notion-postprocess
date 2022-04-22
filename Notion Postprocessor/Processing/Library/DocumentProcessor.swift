//
//  Notion Postprocessor
//

import Foundation

protocol DocumentProcessor: DirectoryEnumerator, DocumentNameProvider {

	typealias CanonicalNameMap = [String: String]
	
	var dryRun: Bool { get }
	var profile: PerformanceProfile { get }
	
}

extension DocumentProcessor {
	
	private var fileManager: FileManager { FileManager.default }
	
	func processDocuments(in directory: URL) throws {
		let _ = try processDocumentsAndWriteMap(startingIn: directory)
	}
	
	private func processDocumentsAndWriteMap(startingIn directory: URL) throws -> CanonicalNameMap {
		var map = CanonicalNameMap()
		let (documents, directories) = try fileURLs(in: directory)
		
		for directory in directories {
			let cachedDirectoryNames = try processDocumentsAndWriteMap(startingIn: directory)
			map.merge(cachedDirectoryNames) { _, newKey in newKey }
		}
		
		let cachedDirectoryNames = try indexDocumentNames(documents, map: map)
		map.merge(cachedDirectoryNames) { _, newKey in newKey }
		
		try documents.forEach { document in
			try rewriteAndRenameDocument(document, map: map)
			profile.tick("documentProcessed")
		}
		
		try directories.forEach { directory in
			try renameDirectory(directory, map: map)
			profile.tick("directoryProcessed")
		}
		
		return map
	}
	
	/// Indexes canonical names for all given documents and returns a map.
	/// Skips all names already defined in the provided map.
	private func indexDocumentNames(_ documents: [URL], map existingMap: CanonicalNameMap) throws -> CanonicalNameMap {
		var map = CanonicalNameMap()
		
		for document in documents {
			let originalDocumentName = fileNameWithoutExtension(from: document)
			
			guard !existingMap.keys.contains(originalDocumentName), !map.keys.contains(originalDocumentName) else {
				profile.tick("duplicateNameIndexSkipped")
				continue
			}
			
			guard let canonicalDocumentName = try canonicalDocumentName(for: document) else {
				print("Could not determine canonical name for file '\(document.path)'.")
				profile.tick("documentNameNotIndexed")
				continue
			}
			
			map[originalDocumentName] = canonicalDocumentName
			profile.tick("documentNameIndexed")
		}
		
		return map
	}
	
	private func rewriteAndRenameDocument(_ document: URL, map: CanonicalNameMap) throws {
		var documentContents = try documentContents(at: document)
		documentContents = rewrittenDocumentContents(documentContents)
		documentContents = rewrittenDocumentResourceLinks(documentContents, map: map)
		
		guard let canonicalDocumentName = try canonicalDocumentName(for: document, using: map) else {
			throw ProcessingError(kind: .missingData, description: "Could not determine canonical document name for '\(document.lastPathComponent)' (at '\(document.description)') to rewrite and rename.")
		}
		
		try rewriteAndRenameDocument(document, newName: canonicalDocumentName, newContents: documentContents)
	}
	
	private func rewriteAndRenameDocument(_ document: URL, newName: String, newContents: String) throws {
		let newDocumentFileName = fileName(forCanonicalName: newName)
		let newDocument = document.deletingLastPathComponent().appendingPathComponent(newDocumentFileName)
		
		guard !dryRun else {
			print("Rename file '\(document.lastPathComponent)' to '\(newDocumentFileName)'.")
			return
		}
		
		try newContents.write(to: newDocument, atomically: false, encoding: .utf8)
		try fileManager.removeItem(at: document)
	}
	
	private func renameDirectory(_ directory: URL, map: CanonicalNameMap) throws {
		let directoryName = directory.lastPathComponent
		
		guard let canonicalDirectoryName = map[directoryName] else {
			throw ProcessingError(kind: .missingData, description: "Could not determine canonical directory name for '\(directory.lastPathComponent)' (at '\(directory.description)') to rename.")
		}
		
		try renameDirectory(directory, newName: canonicalDirectoryName)
	}
	
	private func renameDirectory(_ directory: URL, newName: String) throws {
		guard !dryRun else {
			print("Rename directory '\(directory.lastPathComponent)' to '\(newName)'.")
			return
		}
		
		let movedDirectory = directory.deletingLastPathComponent().appendingPathComponent(newName, isDirectory: true)
		try fileManager.moveItem(at: directory, to: movedDirectory)
	}
	
	// MARK: Document Contents
	
	/// Reads and rewrites the document, applies transformations for destination format.
	///
	/// This function may perform the following:
	///   - Detect callout blocks (beginning of line, emoji, text until newline)
	private func rewrittenDocumentContents(_ contents: String) -> String {
		return try! contents
			.removingMatches(matching: #"^# .+?\n\s+"#)
			.replacingMatches(matching: #"<aside>\s*(.+?)\s*</aside>"#, with: "$1")
			.replacingOccurrences(of: "```js", with: "```javascript")
			.replacingOccurrences(of: "```ts", with: "```typescript")
			.replacingOccurrences(of: "```tsx", with: "```typescript")
	}
	
	/// Finds paths to resources inside the given document contents and rewrites
	private func rewrittenDocumentResourceLinks(_ contents: String, map: CanonicalNameMap) -> String {
		var paths: [(match: String, replacement: String)] = []
		var rewrittenContents = contents
		
		forEachResourcePath(in: contents) { matchedPathString, path in
			// Skip external paths
			guard !path.contains("http") else {
				return
			}
			
			var rewrittenPath = path
			
			for (originalName, canonicalName) in map {
				rewrittenPath = rewrittenPath.replacingOccurrences(of: originalName, with: canonicalName)
			}
			
			paths.append((
				match: matchedPathString,
				replacement: rewrittenPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
			))
		}
		
		for (match, replacement) in paths {
			rewrittenContents = rewrittenContents.replacingOccurrences(of: match, with: replacement)
		}
		
		if dryRun {
			print("Rewriting resource links: \(paths.map { match, replacement in "'\(match)' → '\(replacement)'" }).")
		}
		
		return rewrittenContents
	}
	
	private func forEachResourcePath(in contents: String, _ block: (_ matchedPathString: String, _ path: String) -> Void) {
		let matches = try! contents.allMatchGroups(#"\[.+?\]\((.+?)\)"#)
		
		for match in matches {
			guard let matchedPathString = match[1], let path = matchedPathString.removingPercentEncoding else {
				continue
			}
			
			block(String(matchedPathString), path)
		}
	}
	
	// MARK: Name Indexing
	
	private func canonicalDocumentName(for document: URL, using map: CanonicalNameMap) throws -> String? {
		let originalDocumentName = fileNameWithoutExtension(from: document)
		return map[originalDocumentName]
	}
	
	private func fileNameWithoutExtension(from file: URL) -> String {
		return try! file.lastPathComponent.removingMatches(matching: #"\.\w+$"#)
	}
	
	private func fileName(forCanonicalName canonicalName: String) -> String {
		return canonicalName + ".md"
	}
	
}
