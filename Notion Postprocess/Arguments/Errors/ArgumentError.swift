//
//  Notion Postprocess
//

import Foundation

struct ArgumentError: LocalizedError {
	
	let errorDescription: String?
	
	init(description: String) {
		self.errorDescription = description
	}
	
}
