//
//  Notion Postprocessor
//

import Foundation

protocol FileWriter: FileReader {
	
	var dryRun: Bool { get }
	
}

extension FileWriter {
	
	private var fileManager: FileManager { FileManager.default }
	
	func moveAndUpdateDocument(_ document: URL, into directory: URL? = nil, updatingName newName: String? = nil, updatingContents newContents: String? = nil) throws {
		let newDocumentName = newName ?? document.lastPathComponent
		let newDocument = directory?.appendingPathComponent(newDocumentName) ?? document
		
		if let newContents = newContents {
			try moveAndUpdateDocument(document, to: newDocument, updatingContents: newContents)
		} else {
			try moveDocument(document, to: newDocument)
		}
	}
	
	func moveDocument(_ document: URL, to newDocument: URL) throws {
		guard !dryRun else {
			print("Move file '\(document.lastPathComponent)' to '\(newDocument.lastPathComponent)'.")
			return
		}
		
		do {
			try fileManager.moveItem(at: document, to: newDocument)
		} catch {
			throw FileError(description: "Could not move document '\(newDocument.lastPathComponent)' to '\(newDocument.path)'. \(error.localizedDescription)")
		}
	}
	
	func moveAndUpdateDocument(_ document: URL, to newDocument: URL, updatingContents newContents: String) throws {
		guard !dryRun else {
			print("Rename and update file '\(document.lastPathComponent)' to '\(newDocument.lastPathComponent)'.")
			return
		}
		
		do {
			try newContents.write(to: newDocument, atomically: false, encoding: .utf8)
		} catch {
			throw FileError(description: "Could not write renamed document '\(newDocument.lastPathComponent)' to disk (at '\(newDocument.path)'). \(error.localizedDescription)")
		}
		
		guard document != newDocument else {
			return
		}
		
		do {
			try fileManager.removeItem(at: document)
		} catch {
			throw FileError(description: "Could not remove document '\(document.lastPathComponent)' (at '\(document.path)'). \(error.localizedDescription)")
		}
	}
	
}
