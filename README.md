# QEM Dashboard

The QEM Dashboard is a graphical user interface for [qem-bot](https://github.com/openSUSE/qem-bot), designed to visualize the state of incidents and their corresponding test results in the openSUSE/SUSE Quality Engineering Maintenance (QEM) workflow.

## Features

- Real-time visualization of QEM incident status.
- Integration with openQA for test result tracking.
- Interactive dashboard for managing and monitoring the maintenance process.
- Native Model Context Protocol (MCP) server for AI agent interaction.
- RESTful API with OpenAPI documentation.

## Getting Started

### Prerequisites

- Perl (with Mojolicious and other dependencies)
- Node.js and npm
- PostgreSQL
- RabbitMQ (optional, for real-time updates)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/openSUSE/qem-dashboard.git
   cd qem-dashboard
   ```

2. Install Perl dependencies:

   ```bash
   make install-deps-cpanm
   ```

3. Install Node.js dependencies:

   ```bash
   npm install
   ```

4. Set up the database:
   ```bash
   make start-postgres
   # The migrations will be applied automatically when the application starts
   ```

### Running the Application

1. Build the frontend assets:

   ```bash
   npm run build
   ```

2. Start the Mojolicious development server:

   ```bash
   script/dashboard daemon
   ```

3. Access the dashboard in your browser:
   `http://127.0.0.1:3000`

### Configuration

The dashboard can be configured via a YAML file. By default, it looks for `dashboard.yml` in the current directory or `/home/lurklur/dashboard.yml`.

The following environment variables can be used to override the configuration:

- `DASHBOARD_CONF`: Path to the configuration file.
- `DASHBOARD_CONF_OVERRIDE`: A JSON string used to override configuration values. This is especially useful for passing secrets or temporary configuration changes in containerized environments.

See **[docs/Configuration.md](docs/Configuration.md)** for more details.

Example:

```bash
DASHBOARD_CONF_OVERRIDE='{"pg":"postgresql://postgres:postgres@localhost:5432/postgres"}' script/dashboard daemon
```

### Mocking for Local Development

For development and manual testing of the UI without needing a full backend environment, you can use the provided mocking tool:

1. Build the frontend assets (if not already done):
   ```bash
   npm run build
   ```
2. Run the mock server:
   ```bash
   script/run-mock
   ```
3. The dashboard will be available at `http://localhost:3000` with multiple incidents and job results already loaded.

### Model Context Protocol (MCP)

The dashboard provides a native [MCP server](https://modelcontextprotocol.io) for interaction with AI agents.
It supports both HTTP/SSE (`/app/mcp`) and Stdio (`script/mcp-stdio`) transports.
See **[docs/MCP.md](docs/MCP.md)** for more details.

### REST API

The dashboard exposes a RESTful API for integration with other tools. It is documented using OpenAPI 3.0 and includes an interactive Swagger UI.

- **Swagger UI:** `http://localhost:3000/swagger`
- **OpenAPI Spec:** `http://localhost:3000/api/v1/openapi.yaml`

See **[docs/API.md](docs/API.md)** for more details.

### Frontend Development

When modifying Vue components or stylesheets:

- Run `npm run dev` to start the Vite development server with Hot Module Replacement (HMR).
- Use `npm run lint` to check for code style issues.

### Backend Development

- Use `prove -l` or `make test` to run the test suite.
- Check code coverage with `make test-coverage`.
- Adhere to the Mojolicious coding style and use `make tidy` to format Perl code.

## License

This project is licensed under the MIT License - see the [COPYING](COPYING) file for details.
