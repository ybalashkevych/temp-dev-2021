# Legacy Bash Scripts

This directory contains the original bash implementation of the cursor automation system.

## ⚠️ Deprecated

These scripts have been replaced by the Python implementation in the parent directory.

**Use the Python version instead:**

```bash
cd ..
cursor-daemon daemon
```

## Why Deprecated?

The bash scripts (~1,100 lines) have been replaced with a modern Python application that provides:

- Type safety with Pydantic
- Comprehensive test coverage (80%+)
- Better error handling and debugging
- Direct GitHub API access (faster)
- IDE support and maintainability

## Files Archived

- `daemon.sh` - Main monitoring daemon
- `agent.sh` - Cursor agent invocation
- `thread.sh` - Thread management
- `state.sh` - State tracking
- `common.sh` - Common utilities
- `invoke-cursor-agent.sh` - Cursor CLI wrapper

## For Reference Only

These scripts are kept for:

1. Reference during migration
2. Fallback if needed (not recommended)
3. Historical purposes

## Migration

See `../MIGRATION.md` for full migration guide.

## Running Legacy Scripts (Not Recommended)

If you must run the bash version:

```bash
./daemon.sh
```

**Note**: The bash and Python versions are fully compatible with the same data formats, so you can switch between them if needed.

