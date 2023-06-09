//
//  Notion Postprocess
//

import Foundation

protocol RewriteCommand: FileWriter, DirectoryReader, DirectoryWriter, DocumentNameProvider, ResourcePathProvider {

	typealias CanonicalNameMap = [String: String]
	
	var dryRun: Bool { get }
	var profile: PerformanceProfile { get }
	
}

extension RewriteCommand {
	
	// MARK: Processing
	
	func processDocuments(in directory: URL) throws {
		let _ = try processDocumentsAndWriteMap(startingIn: directory)
	}
	
	private func processDocumentsAndWriteMap(startingIn directory: URL) throws -> CanonicalNameMap {
		var map = CanonicalNameMap()
		let (directories, documents, tables) = try fileURLs(in: directory)
		
		for directory in directories {
			let cachedDirectoryNames = try processDocumentsAndWriteMap(startingIn: directory)
			map.merge(cachedDirectoryNames) { _, newKey in newKey }
		}
		
		let cachedDocumentNames = try indexDocumentNames(documents, map: map)
		map.merge(cachedDocumentNames) { _, newKey in newKey }
		
		let cachedTableNames = indexProvisoryFileName(tables, map: map)
		map.merge(cachedTableNames) { _, newKey in newKey }
		
		let cachedDirectoryNames = indexProvisoryFileName(directories, map: map)
		map.merge(cachedDirectoryNames) { _, newKey in newKey }
		
		for document in documents {
			try rewriteAndRenameDocument(document, map: map)
			profile.tick("documentProcessed")
		}
		
		for directory in directories {
			try rewriteAndRenameDirectory(directory, map: map)
			profile.tick("directoryProcessed")
		}
		
		return map
	}
	
	// MARK: Indexing
	
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
			
			guard let canonicalDocumentName = try canonicalDocumentNameWithFallback(for: document) else {
				profile.tick("documentNameIndeterminate")
				continue
			}
			
			map[originalDocumentName] = canonicalDocumentName
			profile.tick("documentNameIndexed")
		}
		
		return map
	}
	
	private var provisoryFileNameAppendix: String { "(Migrated)" }
	
	/// Index a provisory name for all given files or directories.
	///
	/// Generic indexing function that can be used with either directories or other
	/// loose files (e.g. exported table data). Only indexes a derived provisory name
	/// from the file name itself and append "(Migrated)" to indicate the makeshift
	/// nature of the set name.
	private func indexProvisoryFileName(_ files: [URL], map existingMap: CanonicalNameMap) -> CanonicalNameMap {
		var map = CanonicalNameMap()
		
		for file in files {
			let originalFileName = fileNameWithoutExtension(from: file)
			let provisoryFileName = try! originalFileName.removingMatches(matching: #"\s[0-9a-f]{5}"#)
			
			guard !provisoryFileName.contains(provisoryFileNameAppendix) else {
				profile.tick("duplicateNameIndexSkipped")
				continue
			}
			
			guard !existingMap.keys.contains(originalFileName), !map.keys.contains(originalFileName) else {
				profile.tick("duplicateNameIndexSkipped")
				continue
			}
			
			map[originalFileName] = "\(provisoryFileName) \(provisoryFileNameAppendix)"
			profile.tick("provisoryNameIndexed")
		}
		
		return map
	}
	
	private func canonicalDocumentNameWithFallback(for document: URL) throws -> String? {
		if let canonicalDocumentName = try canonicalDocumentName(for: document) {
			profile.tick("documentNameReadFromContents")
			return canonicalDocumentName
		}
		
		print("Could not determine canonical name for file '\(document.lastPathComponent)' (at '\(document.path)').")
		
		let originalDocumentName = fileNameWithoutExtension(from: document)
		
		if try! originalDocumentName.matches(#"\s[0-9a-f]{5}"#) == false {
			let canonicalDocumentName = fileNameWithoutExtension(from: originalDocumentName)
			print("Recovering document name from file as '\(canonicalDocumentName)', preserved by exporter.")
			profile.tick("documentNameReadFromPreservedName")
			
			return canonicalDocumentName
		}
		
		return nil
	}
	
	// MARK: Rewrite & Rename
	
	private func rewriteAndRenameDocument(_ document: URL, map: CanonicalNameMap) throws {
		var documentContents = try fileContents(for: document)
		documentContents = rewrittenDocumentContents(documentContents)
		documentContents = rewrittenDocumentResourceLinks(documentContents, map: map)
		
		guard let canonicalDocumentName = try canonicalDocumentName(for: document, using: map) else {
			throw CommandError(kind: .missingData, description: "Could not determine canonical document name for '\(document.lastPathComponent)' (at '\(document.path)') to rewrite and rename.")
		}
		
		try moveAndUpdateDocument(document, updatingName: canonicalDocumentName, updatingContents: documentContents)
		profile.tick("renameDocument")
	}
	
	private func rewriteAndRenameDirectory(_ directory: URL, map: CanonicalNameMap) throws {
		let directoryName = directory.lastPathComponent
		
		guard let canonicalDirectoryName = map[directoryName] else {
			throw CommandError(kind: .missingData, description: "Could not determine canonical directory name for '\(directory.lastPathComponent)' (at '\(directory.path)') to rename.")
		}
		
		try renameDirectory(directory, to: canonicalDirectoryName)
		profile.tick("renameDirectory")
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
		return rewriteResourcePaths(in: contents) { path in
			// Skip external paths
			guard !path.contains("http") else {
				return nil
			}
			
			var rewrittenPath = path
			
			for (originalName, canonicalName) in map {
				rewrittenPath = rewrittenPath.replacingOccurrences(of: originalName, with: canonicalName)
			}
			
			if dryRun {
				print("Rewriting resource link '\(path)' → '\(rewrittenPath)'.")
			}
			
			return rewrittenPath
		}
	}
	
	// MARK: Name Indexing
	
	/// Extracts the document identifier from its `URL` and returns its canonical name from the given map.
	private func canonicalDocumentName(for document: URL, using map: CanonicalNameMap) throws -> String? {
		let originalDocumentName = fileNameWithoutExtension(from: document)
		return map[originalDocumentName]
	}
	
}
