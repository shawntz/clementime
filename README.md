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

# or install for Azure deployment in current directory
# curl -fsSL https://raw.githubusercontent.com/shawntz/clementime/main/INSTALL-AZURE.sh -c . | bash

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

<https://hub.docker.com/r/shawnschwartz/clementime>

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

## New Features

### Configuration Panel Enhancements

The enhanced configuration panel now includes:

1. **File Tree Viewer**: View the complete directory structure of `/app/data` mount point
   - Navigate to Config → File Tree tab
   - Real-time refresh capability
   - Shows file sizes and directory structure

2. **Section-Student CSV Mappings**: Manage student lists dynamically
   - Upload CSV files per section
   - Override config.yml mappings on-the-fly
   - Activate/deactivate different student lists
   - CSV format: `name,email,slack_id` (header required)

### How to Use Section Mappings

1. Navigate to Config → Section Mappings tab
2. Upload a CSV file with student data for a specific section
3. Select which mapping to activate from the dropdown
4. The system will use the active database mapping instead of config.yml

### Priority Order for Student Lists

1. Active database mapping (if set)
2. CSV file specified in config.yml
3. Inline students in config.yml

Full documentation available at:
<https://github.com/shawntz/clementime>

## Support

- GitHub Issues: <https://github.com/shawntz/clementime/issues>
- Documentation: <https://github.com/shawntz/clementime/wiki>

## License

MIT License - See [LICENSE](https://github.com/shawntz/clementime/blob/main/LICENSE) for details.
  
