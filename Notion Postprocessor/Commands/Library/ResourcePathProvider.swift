//
//  Notion Postprocessor
//

import Foundation

protocol ResourcePathProvider {}

extension ResourcePathProvider {
	
	func rewriteResourcePaths(in contents: String, block: (_ path: String) -> String?) -> String {
		var paths: [(match: String, replacement: String)] = []
		var rewrittenContents = contents
		
		forEachResourcePath(in: contents) { matchedEncodedPath, path in
			guard let rewrittenPath = block(path) else {
				return
			}
			
			paths.append((
				match: matchedEncodedPath,
				replacement: rewrittenPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
			))
		}
		
		for (match, replacement) in paths {
			rewrittenContents = rewrittenContents.replacingOccurrences(of: match, with: replacement)
		}
		
		return rewrittenContents
	}
	
	func forEachResourcePath(in contents: String, _ block: (_ matchedPathString: String, _ path: String) -> Void) {
		let matches = try! contents.allMatchGroups(#"\[.+?\]\((.+?)\)"#)
		
		for match in matches {
			guard let matchedPathString = match[1], let path = matchedPathString.removingPercentEncoding else {
				continue
			}
			
			block(String(matchedPathString), path)
		}
	}
	
}
