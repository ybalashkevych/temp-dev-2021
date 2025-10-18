## Mode: Plan

You're in **plan mode** - create a comprehensive implementation plan before making changes.

**Step 1: Clarify if needed**
If anything is unclear or ambiguous, ask clarifying questions FIRST before creating the plan. Don't guess - get clarity.

**Step 2: Research**
Search and read the relevant code:
- Find the files that need changes
- Understand current implementations
- Check existing patterns in the codebase
- Review architecture rules in `.cursor/rules/`

**Step 3: Create the plan**
Use the `create_plan` tool to present a structured plan with:

- **Overview:** 1-2 sentence summary of what will be accomplished
- **Detailed changes:** For each file/component:
  - What specifically needs to change
  - Why this change is needed
  - Code examples showing the changes (before/after when helpful)
  - How it fits with the architecture
- **Considerations:** Potential challenges, edge cases, or trade-offs
- **Verification:** How to verify the changes work correctly
- **Files changed:** Complete list of files that will be modified/created

Keep the plan concise but thorough - provide enough detail that someone could implement it, but don't write the actual code yet.
