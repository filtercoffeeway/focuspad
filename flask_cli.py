#!/usr/bin/env python3
"""
Flask CLI commands for FocusPad API.
"""

import click
from flask.cli import with_appcontext
from app import create_app, db

@click.command()
@with_appcontext
def init_db():
    """Initialize the database."""
    db.create_all()
    click.echo('✅ Database initialized!')

@click.command()
@with_appcontext
def drop_db():
    """Drop all database tables."""
    if click.confirm('This will delete all data. Continue?'):
        db.drop_all()
        click.echo('🗑️  Database dropped!')
    else:
        click.echo('❌ Operation cancelled.')

@click.command()
@with_appcontext
def reset_db():
    """Reset the database (drop and recreate)."""
    if click.confirm('This will delete all data and recreate tables. Continue?'):
        db.drop_all()
        db.create_all()
        click.echo('🔄 Database reset!')
    else:
        click.echo('❌ Operation cancelled.')

def register_commands(app):
    """Register CLI commands with Flask app."""
    app.cli.add_command(init_db)
    app.cli.add_command(drop_db)
    app.cli.add_command(reset_db)

if __name__ == '__main__':
    app = create_app()
    with app.app_context():
        init_db() 