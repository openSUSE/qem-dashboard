# Contributing to QEM Dashboard

Thank you for your interest in contributing to the QEM Dashboard! This document provides instructions for setting up your development environment and submitting changes.

## Development Environment Setup

### Prerequisites

- **Perl**: Mojolicious, Mojo::Pg, etc.
- **Node.js**: Version 20 or higher.
- **PostgreSQL**: Used as the primary database.
- **RabbitMQ**: Used for real-time updates (optional for basic development).

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/openSUSE/qem-dashboard.git
   cd qem-dashboard
   ```

2. **Install Perl dependencies**:
   ```bash
   make install-deps-cpanm
   ```

3. **Install JavaScript dependencies**:
   ```bash
   npm clean-install --ignore-scripts
   ```

### Running the Application

1. **Start PostgreSQL**:
   You can use Podman/Docker to start a local database:
   ```bash
   make start-postgres
   ```

2. **Build frontend assets**:
   ```bash
   npm run build
   ```

3. **Start the Mojolicious server**:
   ```bash
   script/dashboard daemon
   ```

4. **Start the Vite dev server** (for frontend development):
   ```bash
   npm run dev
   ```

## Testing

Always run the tests before submitting a Pull Request.

- **Unit tests (Perl)**: `make test-unit`
- **Unit tests (JavaScript)**: `npm run test:unit`
- **UI tests (Playwright)**: `make test-ui`
- **Check coverage**: `make test-coverage`

## Coding Standards

- **Format**: Run `make tidy` to format your code.
- **JavaScript/Vue**: Use `eslint` and `prettier`. Linting is enforced via git hooks.
- **Git**: Follow standard commit message conventions.

## Submitting Changes

1. Create a new branch for your feature or bugfix.
2. Commit your changes in small, logical increments.
3. Ensure all tests pass and coverage is maintained at 100%.
4. Submit a Pull Request to the `main` branch.
