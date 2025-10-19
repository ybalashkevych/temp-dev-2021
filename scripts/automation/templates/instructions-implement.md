## Your Task: Implement Mode

You are implementing changes for this PR. Follow this workflow:

### Step 1: Understand Requirements
Read `context.md` carefully and understand what needs to be changed.

### Step 2: Make Code Changes
- Follow project architecture rules (`.cursor/rules/`)
- Follow coding standards (`CONTRIBUTING.md`)
- Make focused, minimal changes
- Ensure code quality

### Step 3: Build & Test Loop (Max 10 Attempts)

You have up to 10 attempts to get the build and tests passing. Track your attempts and learn from each failure.

#### Retry Loop Algorithm:

For **attempt 1 through 10**:

1. **Build Phase:**
   ```bash
   xcodebuild clean build -scheme LiveAssistant 2>&1 | tee build-attempt-${ATTEMPT_NUM}.log
   ```
   
   - **If build succeeds**: Proceed to Test Phase below
   - **If build fails**: 
     - Read `build-attempt-${ATTEMPT_NUM}.log` carefully
     - Identify the specific error (syntax, missing import, type mismatch, etc.)
     - Understand WHY it failed
     - Fix the error in the code
     - Log what you fixed: `echo "Attempt ${ATTEMPT_NUM}: Fixed <description>" >> retry.log`
     - Increment attempt counter
     - Go to next attempt (back to step 1)

2. **Test Phase** (only runs if build succeeded):
   ```bash
   xcodebuild test -scheme LiveAssistant -testPlan LiveAssistant 2>&1 | tee test-attempt-${ATTEMPT_NUM}.log
   ```
   
   - **If all tests pass**: SUCCESS! Proceed to Step 4 (Commit)
   - **If tests fail**:
     - Read `test-attempt-${ATTEMPT_NUM}.log` carefully
     - Identify which specific tests failed
     - Read the test failure messages and assertions
     - Understand WHY the tests failed (logic error, wrong output, exception, etc.)
     - Fix the code to address the root cause
     - Log what you fixed: `echo "Attempt ${ATTEMPT_NUM}: Fixed test failure - <description>" >> retry.log`
     - Increment attempt counter
     - Go to next attempt (back to step 1)

3. **Learning Between Attempts:**
   - Keep track of errors you've seen to avoid repeating fixes
   - If you see the same error twice, try a DIFFERENT approach
   - Read previous logs: `cat retry.log` to see what you already tried
   - Consider if your approach is fundamentally wrong

4. **Stop Conditions:**
   - **Success**: Build passes AND all tests pass → Proceed to Step 4
   - **Exhausted attempts**: After 10 failed attempts → Proceed to Failure Handling

#### Example Progression:

```
Attempt 1: Build fails - "Expected '}' on line 42" → Fix syntax error
Attempt 2: Build succeeds, test fails - "testAddUser: Expected true but got false" → Fix logic in addUser()
Attempt 3: Build succeeds, all tests pass → SUCCESS! Continue to commit.
```

#### Important Notes:

- Each attempt should BUILD on knowledge from previous failures
- Don't make random changes - understand the error first
- If stuck after 3-4 attempts with same error, reconsider your approach
- Save all logs (build-attempt-N.log, test-attempt-N.log, retry.log)

### Step 4: Commit Changes

Use proper commit format:
```
type(scope): brief description

Addresses feedback in PR #{{PR_NUMBER}} thread {{THREAD_ID}}

- Detailed change 1
- Detailed change 2
```

**Commit types**: feat, fix, refactor, test, docs, chore, perf, style

### Step 5: Push Changes

```bash
git push origin {{BRANCH}}
```

### Step 6: Update PR Description

Call the update function to add changes summary to PR description.

### Step 7: Report Success

Write a summary of what was implemented and any important notes.

---

## Your Implementation

Please implement the changes following the workflow above:
