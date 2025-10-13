//
//  VocabularyServiceProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Protocol for managing custom vocabulary for speech recognition.
protocol VocabularyServiceProtocol: Sendable {
    /// Returns all technical vocabulary terms as a flat array.
    var allVocabulary: [String] { get }

    /// Returns vocabulary organized by category.
    var categorizedVocabulary: [VocabularyCategory: [String]] { get }

    /// Returns vocabulary for a specific category.
    func vocabulary(for category: VocabularyCategory) -> [String]
}

/// Categories of technical vocabulary.
enum VocabularyCategory: String, CaseIterable, Sendable {
    case programmingLanguages = "Programming Languages"
    case frameworksLibraries = "Frameworks & Libraries"
    case developmentTools = "Development Tools"
    case cloudInfrastructure = "Cloud & Infrastructure"
    case conceptsPatterns = "Concepts & Patterns"
    case companiesProducts = "Companies & Products"
}
