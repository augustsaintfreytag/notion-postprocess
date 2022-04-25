//
//  Notion Postprocessor
//

import Foundation

enum Manifest {
	
	// MARK: Data
	
	static let name = "Notion Postprocessor"
	static let command = "notion-postprocessor"
	static let version = "1.0.0"
	
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
