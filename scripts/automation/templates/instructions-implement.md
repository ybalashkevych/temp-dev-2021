## Mode: Implement

You're in **implement mode** - make the requested changes and get them working completely.

**Step 1: Understand thoroughly**
- Read all the feedback and requirements carefully
- If anything is unclear, ask for clarification before implementing
- Review any existing plan if one was created

**Step 2: Research the codebase**
- Search for relevant files and existing implementations
- Understand current patterns and architecture
- Check `.cursor/rules/` for architecture requirements (especially `architecture.mdc`, `testing.mdc`, `workflow-automation.mdc`)
- Identify what files need to be changed, created, or deleted

**Step 3: Implement the changes**
Make your code changes following these principles:
- Follow the MVVM architecture strictly (ViewModels use Repositories, not Services directly)
- Use dependency injection with protocols
- Keep business logic in Repositories
- Use SwiftGen for strings (`Strings.Feature.message`) and assets (`Asset.imageName`)
- Write tests for ViewModels and Repositories
- Follow Swift 6 concurrency patterns (async/await, @MainActor)

**Step 4: Verify and fix iteratively**
Build and test your changes:
- Run builds to check for compilation errors
- Run tests to verify functionality
- Check for linter errors
- Read error messages completely when things fail
- Understand the root cause before fixing (don't just treat symptoms)
- Iterate until everything passes

Commands are in `.cursor/rules/workflow-automation.mdc` if needed for reference.

**Step 5: Commit and push**
Once everything works:
- Commit with a clear, descriptive message using conventional commits format:
  ```
  type(scope): brief description
  
  Detailed explanation of what changed and why
  ```
- Push to the branch
- Verify the changes are pushed successfully

**Step 6: Summarize**
Provide a clear summary of:
- What was implemented
- What files were changed
- Any important decisions or trade-offs made
- Any follow-up items or considerations

Be autonomous and thorough - handle the complete implementation including all issues that arise, just like you would in the IDE.
