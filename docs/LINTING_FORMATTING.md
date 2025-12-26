# Code Linting and Formatting

This project uses automated linting and formatting to ensure consistent code style across all contributions.

## Tools Used

### JavaScript/React (Landing & Web Client)
- **ESLint** - Code linting to catch errors and enforce best practices
- **Prettier** - Automatic code formatting

### Ruby (Rails Backend)
- **RuboCop** - Ruby code linting and formatting

## Local Development

### Setup

Install dependencies for the projects you're working on:

```bash
# Landing page
cd landing
npm install

# Web client
cd clementime-web/client
npm install

# Rails backend
cd clementime-web
bundle install
```

### Running Linters Locally

#### JavaScript/React

**Landing Page:**
```bash
cd landing
npm run lint          # Check for linting errors
npm run lint:fix      # Auto-fix linting errors
npm run format        # Format code with Prettier
npm run format:check  # Check if code is formatted
```

**Web Client:**
```bash
cd clementime-web/client
npm run lint          # Check for linting errors
npm run lint:fix      # Auto-fix linting errors
npm run format        # Format code with Prettier
npm run format:check  # Check if code is formatted
```

#### Ruby/Rails

```bash
cd clementime-web
bin/rubocop           # Check for linting errors
bin/rubocop -a        # Auto-fix linting errors
```

## CI/CD Integration

### Automated Checks

All pull requests and pushes to `main` automatically run:

1. **Ruby Security Scan** - Brakeman checks for security vulnerabilities
2. **Ruby Linting** - RuboCop ensures Ruby code style
3. **JavaScript Linting** - ESLint checks landing page and web client
4. **Format Checking** - Prettier verifies code formatting

### Auto-Formatting on Pull Requests

When you open a pull request, the `format-check.yml` workflow automatically:

1. Runs Prettier on all JavaScript/React code
2. Commits any formatting changes back to your PR branch
3. Skips CI on the auto-format commit to avoid loops

This ensures all code is properly formatted without manual intervention.

## Configuration Files

- `landing/.prettierrc` - Prettier config for landing page
- `landing/eslint.config.js` - ESLint config for landing page
- `clementime-web/client/.prettierrc` - Prettier config for web client
- `clementime-web/client/eslint.config.js` - ESLint config for web client
- `clementime-web/.rubocop.yml` - RuboCop config for Rails backend

## Best Practices

1. **Before committing**: Run `npm run format` and `npm run lint:fix` to auto-fix issues
2. **IDE Integration**: Install ESLint and Prettier extensions for your editor for real-time feedback
3. **Pre-commit hooks**: Consider setting up Husky to auto-format on commit
4. **CI Failures**: If CI fails due to linting, run the fix commands locally and push

## Prettier Configuration

Our Prettier setup uses:
- Single quotes
- 2-space indentation
- Semicolons
- 100 character line width
- Trailing commas (ES5)
- LF line endings

## ESLint Rules

We use:
- React recommended rules
- React Hooks rules
- React Refresh for HMR
- Browser globals
- ES2020+ syntax support
