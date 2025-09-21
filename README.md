# 🍊 ClemenTime
**Transform any scheduling workflow into a smart, automated system that integrates seamlessly with Slack + Google Meet.**

### 🌟 Example Use Cases
| **Academia** | **Corporate** | **Sports & Community** |
|--------------|---------------|------------------------|
| 📚 Sessions | 💼 Client meetings | ⚽ Practice sessions |
| 👨‍🏫 Office hours | 📞 Interview scheduling | 🏃‍♀️ Coaching meetings |
| 🎓 Thesis defenses | 📊 Performance reviews | 🏆 Tournament planning |
| 🔬 Lab scheduling | 🤝 Team standups | 🎪 Event coordination |

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/shawntz/clementime/main/INSTALL.sh | bash

cd clementime
cp .env.example .env  # edit .env with your credentials
cp config.example.yml config.yml  # update for your needs

./clementime start
```

### What You Get

The install script downloads:
- `clementime` - Management CLI script
- `docker-compose.yml` - Docker orchestration
- `config.example.yml` - Configuration template
- `.env.example` - Environment variables template
- `README.md` – This README file with usage instructions

### Docker

https://hub.docker.com/repository/docker/shawnschwartz/clementime

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
https://github.com/shawntz/clementime

## Support

- GitHub Issues: https://github.com/shawntz/clementime/issues
- Documentation: https://github.com/shawntz/clementime/wiki

## License

MIT License - See [LICENSE](https://github.com/shawntz/clementime/blob/main/LICENSE) for details.
  
