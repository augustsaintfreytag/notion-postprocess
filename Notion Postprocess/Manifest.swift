//
//  Notion Postprocessor
//

import Foundation

enum Manifest {
	
	// MARK: Data
	
	static let name = "Notion Postprocess"
	static let command = "notion-postprocess"
	static let version = "1.1.0"
	
	// MARK: Formatting
	
	private static var releaseVersionDescription: String { version }
	private static var debugVersionDescription: String { "\(version) Debug Preview" }
	
	static var versionDescription: String {
		#if DEBUG
		return debugVersionDescription
		#else
		return releaseVersionDescription
		#endif
	}
	
}
