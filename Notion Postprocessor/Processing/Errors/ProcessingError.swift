//
//  Notion Postprocessor
//

import Foundation

struct ProcessingError: LocalizedError {
	
	let kind: Kind
	let errorDescription: String?
	
	init(kind: Kind, description: String) {
		self.kind = kind
		self.errorDescription = description
	}
	
}

extension ProcessingError {
	
	enum Kind: String {
		case unreadableData
		case missingData
		case invalidStructure
	}
	
}
