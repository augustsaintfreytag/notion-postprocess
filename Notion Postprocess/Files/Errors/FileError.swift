//
//  Notion Postprocess
//

import Foundation

struct FileError: LocalizedError {
	
	let errorDescription: String?
	
	init(description: String) {
		self.errorDescription = description
	}
	
}
