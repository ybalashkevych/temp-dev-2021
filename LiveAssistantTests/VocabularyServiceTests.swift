//
//  VocabularyServiceTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Testing

@testable import LiveAssistant

/// Tests for VocabularyService to improve code coverage.
@Suite("VocabularyService Tests")
struct VocabularyServiceTests {
    
    // MARK: - Service Creation Tests
    
    @Test
    func createVocabularyService() {
        let service = VocabularyService.shared
        #expect(service != nil)
    }
    
    // MARK: - Vocabulary Category Tests
    
    @Test
    func vocabularyCategoryCases() {
        let categories: [VocabularyCategory] = [
            .programmingLanguages,
            .frameworksLibraries,
            .developmentTools,
            .cloudInfrastructure,
            .conceptsPatterns,
            .companiesProducts
        ]
        
        #expect(categories.count == VocabularyCategory.allCases.count)
        
        for category in categories {
            #expect(!category.rawValue.isEmpty)
        }
    }
    
    @Test
    func vocabularyCategoryRawValues() {
        #expect(VocabularyCategory.programmingLanguages.rawValue == "Programming Languages")
        #expect(VocabularyCategory.frameworksLibraries.rawValue == "Frameworks & Libraries")
        #expect(VocabularyCategory.developmentTools.rawValue == "Development Tools")
        #expect(VocabularyCategory.cloudInfrastructure.rawValue == "Cloud Infrastructure")
        #expect(VocabularyCategory.conceptsPatterns.rawValue == "Concepts & Patterns")
        #expect(VocabularyCategory.companiesProducts.rawValue == "Companies & Products")
    }
    
    // MARK: - Vocabulary Loading Tests
    
    @Test
    func allVocabularyNotEmpty() {
        let service = VocabularyService.shared
        let allVocabulary = service.allVocabulary
        
        #expect(!allVocabulary.isEmpty)
        #expect(allVocabulary.count > 50) // Should have substantial vocabulary
    }
    
    @Test
    func vocabularyForEachCategory() {
        let service = VocabularyService.shared
        
        for category in VocabularyCategory.allCases {
            let vocabulary = service.vocabulary(for: category)
            #expect(!vocabulary.isEmpty, "Category \(category) should have vocabulary")
        }
    }
    
    @Test
    func categorizedVocabularyStructure() {
        let service = VocabularyService.shared
        let categorized = service.categorizedVocabulary
        
        #expect(categorized.count == VocabularyCategory.allCases.count)
        
        for category in VocabularyCategory.allCases {
            #expect(categorized[category] != nil)
            #expect(!categorized[category]!.isEmpty)
        }
    }
    
    // MARK: - Specific Vocabulary Tests
    
    @Test
    func programmingLanguagesVocabulary() {
        let service = VocabularyService.shared
        let vocabulary = service.vocabulary(for: .programmingLanguages)
        
        // Check for common programming languages
        let expectedLanguages = ["Swift", "Python", "JavaScript", "Java", "C++", "C#", "Go", "Rust"]
        for language in expectedLanguages {
            #expect(vocabulary.contains(language), "Should contain \(language)")
        }
    }
    
    @Test
    func frameworksLibrariesVocabulary() {
        let service = VocabularyService.shared
        let vocabulary = service.vocabulary(for: .frameworksLibraries)
        
        // Check for common frameworks
        let expectedFrameworks = ["SwiftUI", "UIKit", "React", "Vue", "Angular", "Django", "Flask"]
        for framework in expectedFrameworks {
            #expect(vocabulary.contains(framework), "Should contain \(framework)")
        }
    }
    
    @Test
    func developmentToolsVocabulary() {
        let service = VocabularyService.shared
        let vocabulary = service.vocabulary(for: .developmentTools)
        
        // Check for common development tools
        let expectedTools = ["Xcode", "VSCode", "Git", "Docker", "Kubernetes", "Jenkins"]
        for tool in expectedTools {
            #expect(vocabulary.contains(tool), "Should contain \(tool)")
        }
    }
    
    @Test
    func cloudInfrastructureVocabulary() {
        let service = VocabularyService.shared
        let vocabulary = service.vocabulary(for: .cloudInfrastructure)
        
        // Check for common cloud services
        let expectedServices = ["AWS", "Azure", "Firebase", "Heroku", "DigitalOcean"]
        for service in expectedServices {
            #expect(vocabulary.contains(service), "Should contain \(service)")
        }
    }
    
    @Test
    func conceptsPatternsVocabulary() {
        let service = VocabularyService.shared
        let vocabulary = service.vocabulary(for: .conceptsPatterns)
        
        // Check for common concepts
        let expectedConcepts = ["MVVM", "MVC", "REST", "API", "async", "await"]
        for concept in expectedConcepts {
            #expect(vocabulary.contains(concept), "Should contain \(concept)")
        }
    }
    
    @Test
    func companiesProductsVocabulary() {
        let service = VocabularyService.shared
        let vocabulary = service.vocabulary(for: .companiesProducts)
        
        // Check for common companies
        let expectedCompanies = ["Apple", "Google", "Microsoft", "Amazon", "Meta"]
        for company in expectedCompanies {
            #expect(vocabulary.contains(company), "Should contain \(company)")
        }
    }
    
    // MARK: - Vocabulary Search Tests
    
    @Test
    func searchVocabulary() {
        let service = VocabularyService.shared
        let results = service.searchVocabulary("Swift")
        
        #expect(!results.isEmpty)
        #expect(results.contains("Swift"))
    }
    
    @Test
    func searchVocabularyCaseInsensitive() {
        let service = VocabularyService.shared
        let results = service.searchVocabulary("swift")
        
        #expect(!results.isEmpty)
        #expect(results.contains("Swift"))
    }
    
    @Test
    func searchVocabularyPartialMatch() {
        let service = VocabularyService.shared
        let results = service.searchVocabulary("UI")
        
        #expect(!results.isEmpty)
        #expect(results.contains { $0.contains("UI") })
    }
    
    @Test
    func searchVocabularyEmptyQuery() {
        let service = VocabularyService.shared
        let results = service.searchVocabulary("")
        
        #expect(results.isEmpty)
    }
    
    @Test
    func searchVocabularyNoMatches() {
        let service = VocabularyService.shared
        let results = service.searchVocabulary("nonexistentterm12345")
        
        #expect(results.isEmpty)
    }
    
    // MARK: - Vocabulary Statistics Tests
    
    @Test
    func vocabularyStatistics() {
        let service = VocabularyService.shared
        let stats = service.getVocabularyStatistics()
        
        #expect(stats.totalTerms > 0)
        #expect(stats.categoriesCount == VocabularyCategory.allCases.count)
        #expect(stats.averageTermsPerCategory > 0)
    }
    
    @Test
    func vocabularyStatisticsConsistency() {
        let service = VocabularyService.shared
        let stats = service.getVocabularyStatistics()
        let allVocabulary = service.allVocabulary
        
        #expect(stats.totalTerms == allVocabulary.count)
    }
}