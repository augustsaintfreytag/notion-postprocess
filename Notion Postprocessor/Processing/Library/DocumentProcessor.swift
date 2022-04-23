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
			try renameDirectory(directory, map: map)
			profile.tick("directoryProcessed")
		}
		
		return map
	}
	
	func groupDocuments(in directory: URL) throws {
		let (directories, documents, _) = try fileURLs(in: directory)
		
		for directory in directories {
			try groupDocuments(in: directory)
			profile.tick("directoryProcessed")
		}
		
		try groupDocumentsWithDirectories(directories: directories, documents: documents)
	}
	
	// MARK: Grouping
	
	private func groupDocumentsWithDirectories(directories: [URL], documents: [URL]) throws {
		guard !directories.isEmpty else {
			return
		}
		
		let directoryByName = directories.reduce(into: [String: URL]()) { dictionary, directory in
			dictionary[directory.lastPathComponent] = directory
		}
		
		for document in documents {
			let documentName = fileNameWithoutExtension(from: document)
			
			guard let associatedDirectory = directoryByName[documentName] else {
				continue
			}
			
			let documentContents = try documentContents(at: document)
			let rewrittenDocumentContents = rewrittenDocumentGroupPaths(documentContents, removingPathComponent: documentName)
			
			try moveDocument(document, into: associatedDirectory, withUpdatedContents: rewrittenDocumentContents)
		}
	}
	
	private func rewrittenDirectoryAndDocumentURLs(directories: [URL], documents: [URL], map: CanonicalNameMap) throws -> (directories: [URL], documents: [URL]) {
		let updatedDirectories: [URL] = directories.compactMap { directory in
			let originalDirectoryName = directory.lastPathComponent
			
			guard let canonicalDirectoryName = map[originalDirectoryName] else {
				return nil
			}
			
			return directory.deletingLastPathComponent().appendingPathComponent(canonicalDirectoryName)
		}
		
		let updatedDocuments: [URL] = try documents.compactMap { document in
			guard let canonicalDocumentName = try canonicalDocumentName(for: document, using: map) else {
				return nil
			}
			
			return document.deletingLastPathComponent().appendingPathComponent(canonicalDocumentName)
		}
		
		return (updatedDirectories, updatedDocuments)
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
		var documentContents = try documentContents(at: document)
		documentContents = rewrittenDocumentContents(documentContents)
		documentContents = rewrittenDocumentResourceLinks(documentContents, map: map)
		
		guard let canonicalDocumentName = try canonicalDocumentName(for: document, using: map) else {
			throw ProcessingError(kind: .missingData, description: "Could not determine canonical document name for '\(document.lastPathComponent)' (at '\(document.path)') to rewrite and rename.")
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
		
		do {
			try newContents.write(to: newDocument, atomically: false, encoding: .utf8)
		} catch {
			throw FileError(description: "Could not write renamed document '\(newDocument.lastPathComponent)' to disk (at '\(newDocument.path)'). \(error.localizedDescription)")
		}
		
		do {
			try fileManager.removeItem(at: document)
		} catch {
			throw FileError(description: "Could not remove document '\(document.lastPathComponent)' (at '\(document.path)'). \(error.localizedDescription)")
		}
		
		profile.tick("renameDocument")
	}
	
	private func renameDirectory(_ directory: URL, map: CanonicalNameMap) throws {
		let directoryName = directory.lastPathComponent
		
		guard let canonicalDirectoryName = map[directoryName] else {
			throw ProcessingError(kind: .missingData, description: "Could not determine canonical directory name for '\(directory.lastPathComponent)' (at '\(directory.path)') to rename.")
		}
		
		try renameDirectory(directory, newName: canonicalDirectoryName)
	}
	
	private func renameDirectory(_ directory: URL, newName: String) throws {
		guard !dryRun else {
			print("Rename directory '\(directory.lastPathComponent)' to '\(newName)'.")
			return
		}
		
		let movedDirectory = directory.deletingLastPathComponent().appendingPathComponent(newName, isDirectory: true)
		
		do {
			try fileManager.moveItem(at: directory, to: movedDirectory)
		} catch {
			throw FileError(description: "Could not rename directory '\(directory.lastPathComponent)' to '\(movedDirectory.lastPathComponent)' (at '\(directory.path)'). \(error.localizedDescription)")
		}
		
		profile.tick("renameDirectory")
	}
	
	private func moveDocument(_ document: URL, into directory: URL, withUpdatedContents contents: String? = nil) throws {
		guard !dryRun else {
			print("Move document '\(document.lastPathComponent)' into '\(directory.lastPathComponent)' (at '\(directory.path)').")
			return
		}
		
		do {
			guard let contents = contents else {
				try fileManager.moveItem(at: document, to: directory)
				return
			}
			
			let newDocument = document.appendingPathComponent(document.lastPathComponent, isDirectory: false)
			try contents.write(to: newDocument, atomically: false, encoding: .utf8)
			try fileManager.removeItem(at: document)
		} catch {
			throw FileError(description: "Could not move document '\(document.lastPathComponent)' into '\(directory.lastPathComponent)' (at '\(directory.path)'). \(error.localizedDescription)")
		}
		
		profile.tick("moveDocument")
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
	
	private func rewrittenDocumentGroupPaths(_ contents: String, removingPathComponent name: String) -> String {
		return rewriteResourcePaths(in: contents) { path in
			// Skip external paths
			guard !path.contains("http") else {
				return nil
			}
			
			let rewrittenPath = try! path.removingMatches(matching: "\(name)/")
			
			if dryRun {
				print("Rewriting resource link for grouping '\(path)' → '\(rewrittenPath)'.")
			}
			
			return rewrittenPath
		}
	}
	
	private func rewriteResourcePaths(in contents: String, block: (_ path: String) -> String?) -> String {
		var paths: [(match: String, replacement: String)] = []
		var rewrittenContents = contents
		
		forEachResourcePath(in: contents) { matchedEncodedPath, path in
			guard let rewrittenPath = block(path) else {
				return
			}
			
			paths.append((
				match: matchedEncodedPath,
				replacement: rewrittenPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
			))
		}
		
		for (match, replacement) in paths {
			rewrittenContents = rewrittenContents.replacingOccurrences(of: match, with: replacement)
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
	
	/// Extracts the document identifier from its `URL` and returns its canonical name from the given map.
	private func canonicalDocumentName(for document: URL, using map: CanonicalNameMap) throws -> String? {
		let originalDocumentName = fileNameWithoutExtension(from: document)
		return map[originalDocumentName]
	}
	
	private func fileNameWithoutExtension(from file: URL) -> String {
		return fileNameWithoutExtension(from: file.lastPathComponent)
	}
	
	private func fileNameWithoutExtension(from fileName: String) -> String {
		return try! fileName.removingMatches(matching: #"\.\w+$"#)
	}
	
	private func fileName(forCanonicalName canonicalName: String) -> String {
		return canonicalName + ".md"
	}
	
}
