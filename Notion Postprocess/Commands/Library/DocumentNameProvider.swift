//
//  Notion Postprocessor
//

import Foundation

protocol DocumentNameProvider: FileReader {}

extension DocumentNameProvider {
	
	private var firstHeadingMatchPattern: String { #"# (.+)\n?"# }
	
	/// Reads the document at the given URL and returns its canonical name if possible.
	func canonicalDocumentName(for document: URL) throws -> String? {
		let contents = try fileContents(for: document)
		return documentName(fromFileContents: contents)
	}
	
	/// Extracts the first found (first level) heading from the given document contents
	/// and returns the trimmed matching string.
	func documentName(fromFileContents fileContents: String) -> String? {
		let matchCaptureGroups = try! fileContents.firstMatchGroups(firstHeadingMatchPattern)
		
		guard let headingSubstring = matchCaptureGroups?[1] else {
			return nil
		}
		
		return try! String(headingSubstring)
			.removingMatches(matching: #"[^0-9a-zA-Z #&@()+_,;.'\-\u00c0-\u017f]"#)
			.replacingMatches(matching: #"\s+"#, with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
}
