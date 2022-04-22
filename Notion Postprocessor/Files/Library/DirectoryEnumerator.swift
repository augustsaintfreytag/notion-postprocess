//
//  Notion Postprocessor
//

import Foundation

protocol DirectoryEnumerator {}

extension DirectoryEnumerator {
	
	private var fileManager: FileManager { FileManager.default }
	
	func fileURLs(in directory: URL) throws -> (directories: [URL], documents: [URL], tables: [URL]) {
		let fileURLs = try fileManager
			.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
			.sorted(by: { lhs, rhs in lhs.lastPathComponent < rhs.lastPathComponent })
		
		var directoryURLs: [URL] = []
		var documentURLs: [URL] = []
		var tableURLs: [URL] = []
		
		for url in fileURLs {
			if urlIsDirectory(url) {
				directoryURLs.append(url)
				continue
			}
			
			if urlIsDocument(url) {
				documentURLs.append(url)
				continue
			}
			
			if urlIsTable(url) {
				tableURLs.append(url)
				continue
			}
		}
		
		return (directoryURLs, documentURLs, tableURLs)
	}
	
	func documentFileURLs(in directory: URL) throws -> [URL] {
		let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
		return fileURLs.filter { url in urlIsDocument(url) }
	}
	
	private func urlIsDirectory(_ url: URL) -> Bool {
		return url.hasDirectoryPath
	}
	
	private func urlIsTable(_ url: URL) -> Bool {
		return url.lastPathComponent.contains(".csv")
	}
	
	private func urlIsDocument(_ url: URL) -> Bool {
		return url.lastPathComponent.contains(".md")
	}
	
}
