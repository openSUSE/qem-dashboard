# Configuration

The QEM Dashboard is configured primarily through a configuration file and environment variables.

## Configuration File

The default configuration file is `dashboard.yml` in the project root. The path can be overridden by the `DASHBOARD_CONF` environment variable.

### Example `dashboard.yml`

```yaml
---
secrets:
  - some_secret_to_protect_sessions
pg: postgresql://postgres@localhost:5432/postgres
rabbitmq: amqp://user:password@rabbit.suse.de:5672
tokens:
  - a_secret_token_openQABot_will_use
status: 0
openqa:
  url: https://openqa.opensuse.org
obs:
  url: https://build.opensuse.org
smelt:
  url: https://smelt.suse.de
```

## Environment Variables

### `DASHBOARD_CONF`

Specifies the path to the configuration file.

```bash
DASHBOARD_CONF=/path/to/my/config.yml script/dashboard daemon
```

### `DASHBOARD_CONF_OVERRIDE`

Allows overriding specific configuration values using a JSON string. This override is applied after the configuration file is loaded.

```bash
DASHBOARD_CONF_OVERRIDE='{"pg": "postgresql://other_db"}' script/dashboard daemon
```

This is particularly useful in containerized environments where you might want to pass secrets or environment-specific settings without modifying the configuration file.

## Application specific commands

The dashboard provides several custom commands that can be seen by running `script/dashboard --help`.

- `amqp-watcher`: Watches the message bus for job results and updates the database.
- `migrate`: Runs database migrations.
