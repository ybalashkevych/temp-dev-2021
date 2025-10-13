//
//  VocabularyService.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for managing custom technical vocabulary for speech recognition.
final class VocabularyService: VocabularyServiceProtocol, Sendable {
    static let shared = VocabularyService()

    private init() {}

    var allVocabulary: [String] {
        VocabularyCategory.allCases.flatMap { vocabulary(for: $0) }
    }

    var categorizedVocabulary: [VocabularyCategory: [String]] {
        var result: [VocabularyCategory: [String]] = [:]
        for category in VocabularyCategory.allCases {
            result[category] = vocabulary(for: category)
        }
        return result
    }

    func vocabulary(for category: VocabularyCategory) -> [String] {
        switch category {
        case .programmingLanguages:
            return programmingLanguages
        case .frameworksLibraries:
            return frameworksLibraries
        case .developmentTools:
            return developmentTools
        case .cloudInfrastructure:
            return cloudInfrastructure
        case .conceptsPatterns:
            return conceptsPatterns
        case .companiesProducts:
            return companiesProducts
        }
    }

    // MARK: - Vocabulary Lists

    private let programmingLanguages = [
        "Swift", "Objective-C", "Objective C",
        "Python", "JavaScript", "TypeScript",
        "Java", "Kotlin", "Scala",
        "C++", "C plus plus", "C#", "C sharp",
        "Go", "Golang", "Rust",
        "Ruby", "PHP",
        "Dart", "R",
        "MATLAB", "Perl",
        "Haskell", "Elixir", "Clojure",
        "F#", "F sharp", "Julia", "Lua",
        "Assembly", "SQL", "NoSQL",
        "HTML", "CSS", "SASS", "SCSS",
        "Shell", "Bash", "PowerShell",
    ]

    private let frameworksLibraries = [
        "SwiftUI", "UIKit", "AppKit", "Combine",
        "React", "React Native", "Angular", "Vue", "Vue.js",
        "Django", "Flask", "FastAPI",
        "Spring", "Spring Boot",
        ".NET", "dot NET", "ASP.NET",
        "TensorFlow", "PyTorch", "Keras",
        "Pandas", "NumPy", "SciPy",
        "Express", "Express.js",
        "Next.js", "Nuxt", "Nuxt.js",
        "Flutter", "Xamarin", "Ionic",
        "Electron", "Qt", "GTK",
        "Bootstrap", "Tailwind", "Tailwind CSS",
        "Material UI", "Ant Design",
        "Redux", "MobX", "Vuex", "Pinia",
        "RxSwift", "RxJava", "RxJS",
        "GraphQL", "Apollo", "Relay",
        "Jest", "Mocha", "Chai", "Cypress",
        "JUnit", "TestNG", "Mockito",
    ]

    private let developmentTools = [
        "Xcode", "VSCode", "Visual Studio Code",
        "IntelliJ", "IntelliJ IDEA",
        "PyCharm", "WebStorm", "Android Studio",
        "Eclipse", "Visual Studio",
        "Sublime", "Sublime Text",
        "Atom", "Vim", "Neovim", "Emacs",
        "Git", "GitHub", "GitLab", "Bitbucket",
        "Docker", "Kubernetes", "K8s", "kubectl",
        "Jenkins", "CircleCI", "Travis", "Travis CI",
        "GitHub Actions", "GitLab CI",
        "Maven", "Gradle", "Ant",
        "npm", "yarn", "pnpm", "pip", "conda",
        "Webpack", "Vite", "Rollup", "Parcel",
        "Babel", "ESLint", "Prettier",
        "Postman", "Insomnia", "cURL",
        "Jira", "Confluence", "Trello",
        "Figma", "Sketch", "Adobe XD",
        "Homebrew", "Cocoapods", "SPM", "Swift Package Manager",
        "Fastlane", "TestFlight",
    ]

    private let cloudInfrastructure = [
        "AWS", "Amazon Web Services",
        "Azure", "Microsoft Azure",
        "GCP", "Google Cloud", "Google Cloud Platform",
        "Firebase", "Firestore", "Realtime Database",
        "Heroku", "Netlify", "Vercel",
        "DigitalOcean", "Linode",
        "Terraform", "Ansible", "Puppet", "Chef",
        "CloudFormation", "ARM templates",
        "Lambda", "AWS Lambda",
        "EC2", "S3", "CloudFront",
        "API Gateway", "Route 53",
        "DynamoDB", "RDS", "Aurora",
        "CloudWatch", "CloudTrail",
        "Kubernetes", "EKS", "AKS", "GKE",
        "OpenStack", "VMware",
        "Supabase", "PlanetScale", "MongoDB Atlas",
    ]

    private let conceptsPatterns = [
        "MVVM", "Model View ViewModel",
        "MVC", "Model View Controller",
        "MVP", "Model View Presenter",
        "VIPER",
        "async await", "async/await",
        "Combine", "reactive programming",
        "RxSwift", "RxJava",
        "REST API", "RESTful", "REST",
        "GraphQL", "gRPC",
        "WebSocket", "WebSockets",
        "OAuth", "OAuth2", "OAuth 2.0",
        "JWT", "JSON Web Token",
        "SSL", "TLS", "HTTPS",
        "CI/CD", "continuous integration", "continuous deployment",
        "DevOps", "DevSecOps",
        "Agile", "Scrum", "Kanban",
        "TDD", "test driven development",
        "BDD", "behavior driven development",
        "microservices", "monolith", "monolithic",
        "serverless", "FaaS", "function as a service",
        "containerization", "virtualization",
        "dependency injection", "singleton", "factory pattern",
        "observer pattern", "repository pattern",
        "API", "SDK", "CLI", "UI", "UX",
        "frontend", "backend", "full stack", "fullstack",
        "database", "caching", "Redis", "Memcached",
        "ORM", "object relational mapping",
        "JSON", "XML", "YAML", "TOML",
        "middleware", "webhook", "cron job",
    ]

    private let companiesProducts = [
        "Apple", "Google", "Microsoft",
        "Amazon", "Meta", "Facebook",
        "Netflix", "Uber", "Lyft",
        "Airbnb", "Spotify", "Twitter",
        "Slack", "Discord", "Zoom", "Teams",
        "Figma", "Notion", "Linear",
        "Jira", "Asana", "Monday",
        "Stripe", "PayPal", "Square",
        "Shopify", "Salesforce",
        "Oracle", "SAP", "IBM",
        "OpenAI", "ChatGPT", "Claude", "Anthropic",
        "Stack Overflow", "GitHub Copilot",
        "TestFlight", "App Store", "Play Store",
    ]
}
