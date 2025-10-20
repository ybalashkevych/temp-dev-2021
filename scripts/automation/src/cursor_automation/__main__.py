"""
CLI entry point for cursor automation
"""

import logging
import sys
from pathlib import Path

import click

from .config import Config
from .daemon import CursorDaemon
from .utils import setup_logging


@click.group()
@click.option("--debug", is_flag=True, help="Enable debug logging")
@click.pass_context
def cli(ctx: click.Context, debug: bool) -> None:
    """Cursor Automation - GitHub PR feedback automation with Cursor AI"""
    ctx.ensure_object(dict)
    ctx.obj["debug"] = debug


@cli.command()
@click.option("--poll-interval", default=60, help="Seconds between PR checks")
@click.option("--log-file", type=click.Path(), help="Path to log file")
@click.pass_context
def daemon(ctx: click.Context, poll_interval: int, log_file: str | None) -> None:
    """Start the PR monitoring daemon"""
    debug = ctx.obj.get("debug", False)

    # Setup logging
    log_path = Path(log_file) if log_file else None
    logger = setup_logging(log_path, debug)

    try:
        # Load config
        config = Config(poll_interval=poll_interval)

        # Verify prerequisites
        if not config.github_token:
            logger.error("GitHub token not configured")
            logger.error(
                "Set CURSOR_GITHUB_TOKEN environment variable or run 'gh auth login'"
            )
            sys.exit(1)

        # Start daemon
        daemon_instance = CursorDaemon(config)
        daemon_instance.run()

    except KeyboardInterrupt:
        logger.info("\nShutdown requested by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)


@cli.command()
@click.argument("pr_number", type=int)
@click.pass_context
def process_pr(ctx: click.Context, pr_number: int) -> None:
    """Process a specific PR once (for testing)"""
    debug = ctx.obj.get("debug", False)
    logger = setup_logging(debug=debug)

    try:
        config = Config()

        if not config.github_token:
            logger.error("GitHub token not configured")
            sys.exit(1)

        # Create daemon and process single PR
        daemon_instance = CursorDaemon(config)
        daemon_instance.process_pr(pr_number)

        logger.info("Done")

    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        sys.exit(1)


@cli.command()
def version() -> None:
    """Show version information"""
    from . import __version__

    click.echo(f"Cursor Automation v{__version__}")


def main() -> None:
    """Main entry point"""
    cli(obj={})


if __name__ == "__main__":
    main()

