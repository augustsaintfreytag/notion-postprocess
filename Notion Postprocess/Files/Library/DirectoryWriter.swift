//
//  Notion Postprocess
//

import Foundation

protocol DirectoryWriter {
	
	var dryRun: Bool { get }
	
}

extension DirectoryWriter {
	
	private var fileManager: FileManager { FileManager.default }
	
	func renameDirectory(_ directory: URL, to newName: String) throws {
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
	}
	
}
