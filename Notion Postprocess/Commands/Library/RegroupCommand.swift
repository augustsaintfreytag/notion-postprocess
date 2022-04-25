//
//  Notion Postprocess
//

import Foundation

protocol RegroupCommand: FileWriter, DirectoryReader, DirectoryWriter, ResourcePathProvider {
	
	typealias CanonicalNameMap = [String: String]
	
	var dryRun: Bool { get }
	var profile: PerformanceProfile { get }
	
}

extension RegroupCommand {
	
	// MARK: Processing
	
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
			
			let documentContents = try fileContents(for: document)
			let rewrittenDocumentContents = rewrittenDocumentGroupPaths(documentContents, removingPathComponent: documentName)
			
			try moveAndUpdateDocument(document, into: associatedDirectory, updatingContents: rewrittenDocumentContents)
			profile.tick("moveDocument")
		}
	}
	
	// MARK: Document Contents
	
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
	
}
