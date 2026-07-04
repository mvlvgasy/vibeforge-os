# Child projects (each has its own Git)
/projets/*/
!/projets/.gitkeep
!/projets/README.md

# Credentials
.env
.env.local
**/credentials.env
**/*.local.json

# Logs
*.log
.claude/logs/

# OS
.DS_Store
Thumbs.db
desktop.ini

# Editor
.vscode/settings.json
.idea/
*.swp

# Temp
*.tmp
*.bak
pending-capitalization.md

# Claude Code session artifacts
.claude/sessions/
.claude/cache/
