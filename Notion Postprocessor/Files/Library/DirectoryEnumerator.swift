//
//  Notion Postprocessor
//

import Foundation

protocol DirectoryEnumerator {}

extension DirectoryEnumerator {
	
	func documentFileURLs(in directory: URL) throws -> [URL] {
		let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
		
		return fileURLs.filter { url in
			url.lastPathComponent.contains(".md")
		}
	}
	
}
