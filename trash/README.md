# Navbar Component

## Usage

To include the navbar component in any EJS template, simply add:

```ejs
<%- include('partials/navbar') %>
```

## Features

- **Customizable Title**: The navbar title is controlled by the `config.web_ui.navbar_title` setting in your `config.yml` file
- **Active State Highlighting**: The current page is automatically highlighted with bold text
- **Responsive Design**: Uses Tailwind CSS for responsive navigation
- **Consistent Branding**: Includes the Clementime branding and GitHub link

## Configuration

Add this to your `config.yml` file to customize the navbar title:

```yaml
web_ui:
  navbar_title: "Your Custom Title Here"
```

## Server-Side Setup

Make sure to pass the `currentPage` variable in your route handlers:

```typescript
res.render("your-template", {
  config: this.config,
  currentPage: "dashboard", // or 'schedules', 'recording', 'config'
  // ... other variables
});
```

## Available Pages

- `dashboard` - Dashboard page
- `schedules` - Schedules page
- `recording` - Recording page
- `config` - Configuration page

## Files Updated

The following files now use the reusable navbar component:

- `dashboard.ejs`
- `schedules.ejs`
- `recording.ejs`
- `config.ejs`
