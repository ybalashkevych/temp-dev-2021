## Description

<!-- Provide a brief overview of what this PR does and why -->

## Changes

<!-- List the specific changes made in this PR -->

- 
- 
- 

## Type of Change

<!-- Mark the relevant option with an 'x' -->

- [ ] `feat`: New feature
- [ ] `fix`: Bug fix
- [ ] `refactor`: Code refactoring
- [ ] `test`: Adding or updating tests
- [ ] `docs`: Documentation changes
- [ ] `chore`: Maintenance or tooling
- [ ] `perf`: Performance improvement
- [ ] `style`: Code style changes

## Testing

<!-- Describe how this was tested -->

- [ ] Unit tests added/updated
- [ ] All tests pass locally
- [ ] Manual testing performed
- [ ] Code coverage maintained (≥90%)

## Architecture Compliance

<!-- Verify architecture requirements are met -->

- [ ] ViewModels use `@Observable` and `@MainActor`
- [ ] ViewModels access data through Repositories only
- [ ] Protocol-based dependency injection used
- [ ] Follows MVVM pattern per ARCHITECTURE.md
- [ ] Business logic in Repositories, not Services

## Code Quality

<!-- Verify code quality standards are met -->

- [ ] SwiftLint passes (strict mode, zero warnings)
- [ ] swift-format validation passes
- [ ] No force unwraps without justification
- [ ] All user-facing strings use `Strings` enum (no hardcoded strings)
- [ ] All assets use `Asset` enum (no hardcoded names)
- [ ] Functions under 60 lines (warning threshold)
- [ ] Type bodies under 300 lines (warning threshold)

## Documentation

<!-- Update relevant documentation -->

- [ ] Code comments added for complex logic
- [ ] README.md updated (if needed)
- [ ] ARCHITECTURE.md updated (if patterns changed)
- [ ] Localizable.strings updated (if new strings added)

## Screenshots

<!-- If this PR includes UI changes, add screenshots here -->

<!-- Drag and drop images here -->

## Related Issues

<!-- Link related issues using keywords -->

Closes #

## Additional Notes

<!-- Any additional information, context, or discussion points -->

---

**Checklist for Reviewer:**

- [ ] Code follows project architecture and standards
- [ ] Tests are comprehensive and pass
- [ ] Documentation is adequate
- [ ] No obvious performance or security issues
- [ ] Changes are backwards compatible (or migration path provided)
