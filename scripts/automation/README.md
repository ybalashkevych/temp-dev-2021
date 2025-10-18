# Cursor Automation

Automated GitHub PR feedback system powered by Cursor AI.

## Installation

```bash
cd scripts/automation
python3.11 -m pip install -e . --user
```

## Usage

```bash
# Start daemon
export PATH="/Users/yurii/Library/Python/3.11/bin:$PATH"
cursor-daemon daemon

# Or use convenience script
./start-daemon.sh
```

## Testing

```bash
python3.11 -m pytest tests/ -v
```

## Logging

All runtime logs are in `logs/` directory (absolute path, works from any directory).  
See `logs/README.md` for structure and cleanup guidelines.
