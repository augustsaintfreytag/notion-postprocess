//
//  Notion Postprocess
//

import Foundation

struct CommandError: LocalizedError {
	
	let kind: Kind
	let errorDescription: String?
	
	init(kind: Kind, description: String) {
		self.kind = kind
		self.errorDescription = description
	}
	
}

extension CommandError {
	
	enum Kind: String {
		case unreadableData
		case missingData
		case invalidStructure
	}
	
}
