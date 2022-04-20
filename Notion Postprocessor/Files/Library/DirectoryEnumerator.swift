//
//  Notion Postprocessor
//

import Foundation

protocol DirectoryEnumerator {}

extension DirectoryEnumerator {
	
	func fileURLs(in directory: URL) throws -> (documents: [URL], directories: [URL]) {
		let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
		
		var documentURLs: [URL] = []
		var directoryURLs: [URL] = []
		
		for url in fileURLs {
			if urlIsDirectory(url) {
				directoryURLs.append(url)
				continue
			}
			
			if urlIsDocument(url) {
				documentURLs.append(url)
				continue
			}
		}
		
		return (documentURLs, directoryURLs)
	}
	
	func documentFileURLs(in directory: URL) throws -> [URL] {
		let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
		return fileURLs.filter { url in urlIsDocument(url) }
	}
	
	private func urlIsDirectory(_ url: URL) -> Bool {
		return url.hasDirectoryPath
	}
	
	private func urlIsDocument(_ url: URL) -> Bool {
		return url.lastPathComponent.contains(".md")
	}
	
}
