## Description & Changes

<!-- Brief overview of what this PR does, why, and key changes made -->

## Type of Change

- [ ] `feat` | `fix` | `refactor` | `test` | `docs` | `chore` | `perf` | `style`

## Testing

- [ ] Tests added/updated and passing locally
- [ ] Manual testing completed (if applicable)
- [ ] Code coverage maintained (≥30%)

## Architecture & Quality Checklist

- [ ] Follows MVVM: ViewModels use `@Observable` + `@MainActor`, access data via Repositories only
- [ ] Protocol-based DI used, business logic in Repositories (not Services)
- [ ] All strings use `Strings` enum, assets use `Asset` enum (no hardcoded values)
- [ ] No unjustified force unwraps, functions <60 lines, type bodies <300 lines
- [ ] Documentation updated (code comments, README, ARCHITECTURE.md, Localizable.strings)

## Screenshots (if UI changes)

<!-- Drag and drop images here -->

## Related Issues

Closes #

## Additional Context

<!-- Optional: migrations, breaking changes, performance notes, or discussion points -->

---

**For Reviewers:** Verify architecture compliance, test coverage, and no security/performance issues.
