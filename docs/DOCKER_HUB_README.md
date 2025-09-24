# 🍊 ClemenTime - Universal Scheduling Automation Platform

[![GitHub](https://img.shields.io/badge/GitHub-Repository-black?logo=github)](https://github.com/shawnschwartz/clementime)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/shawnschwartz/clementime/blob/main/LICENSE)

## Quick Install

```bash
# One-line install with all necessary files
curl -fsSL https://raw.githubusercontent.com/shawnschwartz/clementime/main/scripts/install-clementime.sh | bash

cd clementime
cp .env.example .env
# Edit .env with your credentials
./clementime start
```

## What You Get

The install script downloads:
- `clementime` - Management CLI script
- `docker-compose.yml` - Docker orchestration
- `config.example.yml` - Configuration template
- `.env.example` - Environment variables template

## Available Tags

- `latest` - Latest stable release
- `main` - Main branch (stable)
- `dev` - Development branch (unstable)
- `1.x.x` - Specific version tags

## Usage

### Start ClemenTime
```bash
./clementime start
```

### Stop ClemenTime
```bash
./clementime stop
```

### View Logs
```bash
./clementime logs
```

### Update to Latest Version
```bash
./clementime update
```

## Configuration

1. **Set up environment variables** (`.env`):
   - Google OAuth credentials
   - Slack bot tokens
   - Session secret

2. **Configure scheduling** (`config.yml`):
   - Course/organization details
   - Scheduling preferences
   - Authorized users
   - Notification settings

## Features

- 🤖 **Smart Scheduling** - Algorithmic optimization
- 📅 **Google Calendar** - Automatic event creation
- 💬 **Slack Integration** - Smart notifications
- 🎥 **AI Recording** - Fireflies.ai, Otter.ai support
- 🔐 **Secure Dashboard** - Google OAuth authentication
- 💾 **Data Persistence** - SQLite database
- 🐳 **Production Ready** - Health checks & monitoring

## System Requirements

- Docker & Docker Compose
- 1GB RAM minimum
- 2GB disk space

## Documentation

Full documentation available at:
https://github.com/shawnschwartz/clementime

## Support

- GitHub Issues: https://github.com/shawnschwartz/clementime/issues
- Documentation: https://github.com/shawnschwartz/clementime/wiki

## License

MIT License - See [LICENSE](https://github.com/shawnschwartz/clementime/blob/main/LICENSE) for details.