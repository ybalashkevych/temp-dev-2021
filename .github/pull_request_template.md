# Pull Request

## Description

<!-- Provide a brief description of the changes in this PR -->

## Type of Change

<!-- Mark the relevant option with an "x" -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Refactoring (no functional changes, code improvements)
- [ ] Documentation update
- [ ] Configuration/tooling change

## Related Issues

<!-- Link to related issues: Fixes #123, Relates to #456 -->

## Changes Made

<!-- List the main changes made in this PR -->

-
-
-

## Architecture Compliance

<!-- Ensure the changes follow project architecture -->

- [ ] Follows MVVM pattern (View → ViewModel → Repository → Service)
- [ ] Uses `@Observable` and `@MainActor` for ViewModels
- [ ] Dependencies injected via protocols
- [ ] Repository pattern used for data access
- [ ] No business logic in Views
- [ ] Proper separation of concerns

## Code Quality Checklist

- [ ] SwiftLint passes without errors or warnings
- [ ] SwiftFormat applied (code is properly formatted)
- [ ] All files have correct copyright headers
- [ ] Code follows naming conventions (see CODING_STANDARDS.md)
- [ ] No force unwrapping (unless explicitly justified)
- [ ] Proper error handling with specific error types
- [ ] All user-facing strings are localized

## Testing

- [ ] Unit tests added/updated for new functionality
- [ ] All tests pass
- [ ] Tests follow Swift Testing framework (`@Test` attribute)
- [ ] Mock/fake implementations provided for dependencies
- [ ] Edge cases covered

## Documentation

- [ ] Public APIs documented with doc comments
- [ ] ARCHITECTURE.md updated (if architecture changed)
- [ ] README.md updated (if setup/usage changed)
- [ ] Inline comments added for complex logic

## Performance & Security

- [ ] No performance regressions
- [ ] Async/await used for asynchronous operations
- [ ] Memory management considered (no retain cycles)
- [ ] Sensitive data handled securely
- [ ] API keys/secrets not hardcoded

## Screenshots/Videos

<!-- If UI changes, add screenshots or videos demonstrating the changes -->

## Reviewer Notes

<!-- Any specific areas you'd like reviewers to focus on? -->

## Pre-merge Checklist

- [ ] Branch is up to date with main
- [ ] No merge conflicts
- [ ] CI/CD pipeline passes (if applicable)
- [ ] Reviewed own code changes
- [ ] Ready for review

---

**Reviewer Guidelines:**
- Verify architecture compliance
- Check test coverage
- Ensure code quality standards are met
- Look for potential bugs or edge cases
- Validate error handling
- Consider performance implications


