//
//  Notion Postprocess
//

import Foundation

extension String {
	
	// MARK: Range
	
	public var fullRange: Range<String.Index> {
		startIndex ..< endIndex
	}
	
	public var fullMatchingRange: NSRange {
		NSRange(fullRange, in: self)
	}
	
	// MARK: Pattern In (Capture Groups)
	
	public func firstMatchGroups(_ pattern: String, expressionOptions: NSRegularExpression.Options = [], matchingOptions: NSRegularExpression.MatchingOptions = []) throws -> [Int: Substring]? {
		let expression = try NSRegularExpression(pattern: pattern, options: expressionOptions)
		
		guard let result = expression.firstMatch(in: self, options: matchingOptions, range: fullMatchingRange) else {
			return nil
		}
		
		return indexedMatchGroups(from: result)
	}
	
	public func allMatchGroups(_ pattern: String, expressionOptions: NSRegularExpression.Options = [], matchingOptions: NSRegularExpression.MatchingOptions = []) throws -> [[Int: Substring]] {
		let expression = try NSRegularExpression(pattern: pattern, options: expressionOptions)
		let results = expression.matches(in: self, options: matchingOptions, range: fullMatchingRange)

		var matchGroups: [[Int: Substring]] = []
		
		for result in results {
			matchGroups.append(indexedMatchGroups(from: result))
		}
		
		return matchGroups
	}
	
	private func indexedMatchGroups(from result: NSTextCheckingResult) -> [Int: Substring] {
		var substrings: [Int: Substring] = [:]
		
		for index in 0 ..< result.numberOfRanges {
			let range = Range(result.range(at: index), in: self)!
			let substring = self[range]
			substrings[index] = substring
		}
		
		return substrings
	}
	
	// MARK: Pattern In (Whole Matches)
	
	/// Returns a match of the string against the given regular expression pattern.
	public func matches(_ pattern: String, expressionOptions: NSRegularExpression.Options = [], matchingOptions: NSRegularExpression.MatchingOptions = []) throws -> Bool {
		let expression = try NSRegularExpression(pattern: pattern, options: expressionOptions)
		return expression.firstMatch(in: self, options: matchingOptions, range: fullMatchingRange) != nil
	}
	
	/// Matches the string against the given regular expression pattern using the defined matching
	/// options and replaces each match with the given template and returns the resulting string.
	public func replacingMatches(matching pattern: String, expressionOptions: NSRegularExpression.Options = [], matchingOptions: NSRegularExpression.MatchingOptions = [], with template: String) throws -> String {
		let expression = try NSRegularExpression(pattern: pattern, options: expressionOptions)
		return replacingMatches(matching: expression, options: matchingOptions, with: template)
	}
	
	/// Matches the string against the given regular expression pattern using the defined matching
	/// options and returns a string with each match removed.
	public func removingMatches(matching pattern: String, expressionOptions: NSRegularExpression.Options = [], matchingOptions: NSRegularExpression.MatchingOptions = []) throws -> String {
		let expression = try NSRegularExpression(pattern: pattern, options: expressionOptions)
		return removingMatches(matching: expression, options: matchingOptions)
	}
	
	// MARK: Expression In
	
	/// Returns a match of the string against the given regular expression.
	public func matches(_ expression: NSRegularExpression, options: NSRegularExpression.MatchingOptions = []) -> Bool {
		return expression.firstMatch(in: self, options: options, range: fullMatchingRange) != nil
	}
	
	/// Matches the string against the given regular expression using the defined matching
	/// options and replaces each match with the given template and returns the resulting string.
	public func replacingMatches(matching expression: NSRegularExpression, options: NSRegularExpression.MatchingOptions = [], with template: String) -> String {
		let mutableString = NSMutableString(string: self)
		let range = NSRange(location: 0, length: mutableString.length)
		let _ = expression.replaceMatches(in: mutableString, options: options, range: range, withTemplate: template)
		
		return String(mutableString)
	}
	
	/// Matches the string against the given regular expression using the defined matching
	/// options and returns a string with each match removed.
	public func removingMatches(matching expression: NSRegularExpression, options: NSRegularExpression.MatchingOptions = []) -> String {
		return replacingMatches(matching: expression, options: options, with: "")
	}
	
}
