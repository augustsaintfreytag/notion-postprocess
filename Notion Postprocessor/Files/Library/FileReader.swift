//
//  Notion Postprocessor
//

import Foundation

protocol FileReader {}

extension FileReader {
	
	func documentContents(at url: URL) throws -> String {
		let fileData = try Data(contentsOf: url)
		
		guard let fileContents = String(data: fileData, encoding: .utf8) else {
			throw ProcessingError(kind: .unreadableData, description: "Could not decode document data to string.")
		}
		
		return fileContents
	}
	
}
