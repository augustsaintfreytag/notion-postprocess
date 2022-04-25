//
//  Notion Postprocessor
//

import Foundation
import ArgumentParser

extension ExpressibleByArgument {
	
	/// Returns a joined description of all enumerable options of the argument type for use in help texts.
	///
	/// Creates a formatted description in the form of "one|two|three|four|five".
	static var allCasesHelpDescription: String {
		return joinedCasesHelpDescriptions(allValueStrings)
	}
	
	static func joinedCasesHelpDescriptions(_ descriptions: [String]) -> String {
		return descriptions.joined(separator: "|")
	}
	
}

func lines(_ strings: String...) -> String {
	return strings.joined(separator: " ")
}
