//
//  Notion Postprocessor
//

import Foundation

protocol FileReader {}

extension FileReader {
	
	// MARK: Name
	
	func fileNameWithoutExtension(from file: URL) -> String {
		return fileNameWithoutExtension(from: file.lastPathComponent)
	}
	
	func fileNameWithoutExtension(from fileName: String) -> String {
		return try! fileName.removingMatches(matching: #"\.\w+$"#)
	}
	
	func fileName(forDocumentWithName name: String) -> String {
		return name + ".md"
	}
	
	// MARK: Contents
	
	func fileContents(for file: URL) throws -> String {
		let fileData = try Data(contentsOf: file)
		
		guard let fileContents = String(data: fileData, encoding: .utf8) else {
			throw CommandError(kind: .unreadableData, description: "Could not decode document data to string.")
		}
		
		return fileContents
	}
	
}
