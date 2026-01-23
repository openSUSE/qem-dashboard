# QEM Dashboard

[![Coverage Status](https://coveralls.io/repos/github/openSUSE/qem-dashboard/badge.svg?branch=main)](https://coveralls.io/github/openSUSE/qem-dashboard?branch=main)

The QEM Dashboard is a graphical user interface addon for [qem-bot](https://github.com/openSUSE/qem-bot). It can show
the current state for all incidents that are being processed. To help identify which tests are currently blocking
which incidents. Its deployment happens once a day via
[GitLab pipelines](https://gitlab.suse.de/opensuse/qem-dashboard/-/pipeline_schedules).

## Getting Started

### Install Dependencies

To install all required dependencies, run

    sudo zypper in -C postgresql-server postgresql-contrib
    sudo zypper in -C perl-Mojolicious perl-Mojolicious-Plugin-Webpack \
      perl-Mojo-Pg perl-Cpanel-JSON-XS perl-JSON-Validator perl-IO-Socket-SSL nodejs-default npm
    npm clean-install --ignore-scripts

if you are on an apt-based system, run

    npx playwright install --with-deps

if you are on a zypper-based system, omit the `--with-deps` parameter

    npx playwright install

and ignore the missing dependencies

### Postgres Database

The postgresql-server package installation in the previous step created a database called `postgres` by the user `postgres`.

Allow this user to connect to the local postgres server by modifying `/var/lib/psgql/data/pg_hba.conf`

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             all                                     ident
# IPv4 local connections:
host    postgres        postgres        127.0.0.1/32            trust
host    all             all             127.0.0.1/32            reject
# IPv6 local connections:
host    postgres        postgres        ::1/128                 trust
host    all             all             ::1/128                 reject
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     reject
host    replication     all             127.0.0.1/32            reject
host    replication     all             ::1/128                 reject
```

Alternatively use a postgres container which is especially useful for testing,
e.g. from https://hub.docker.com/_/postgres/:

```
podman run -p 5432:5432 -e POSTGRES_PASSWORD=postgres -d docker.io/library/postgres
```

Make sure the config file `dashboard.yml` points to your PostgreSQL database (and other services where appropriate):

    ---
    secrets:
      - some_secret_to_protect_sessions
    pg: postgresql://postgres@127.0.0.1:5432/postgres
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

Call `npm run build` to bundle assets.

And finally use the `script/dashboard daemon` development web server to make the web application available under
`http://127.0.0.1:3000`.

    $ script/dashboard daemon
    Web application available at http://127.0.0.1:3000

### Local Development with Mock Data

For development and manual testing of the UI without a full production environment, you can start a local instance prepopulated with fixture data:

1. Ensure a PostgreSQL container is running: `make start-postgres`
2. Start the dashboard using the mock data wrapper:
   ```bash
   make run-mock
   ```
3. The dashboard will be available at `http://127.0.0.1:3000` with multiple incidents and job results already loaded.

### Frontend Development

When modifying Vue components or stylesheets:

- **Rebuilding Assets:** `make run-mock` automatically runs `npm run watch` in
  the background. Changes will be instantly rebuilt whenever you save a file.
  If you are running the server via `script/dashboard daemon`, you must
  manually run `npm run build` or `npm run watch` to see your changes.
- **Browser Caching:** The dashboard automatically detects server restarts via a
  `boot_id`. On every route navigation, it verifies if the server has restarted
  and will perform a full browser reload if necessary to ensure you see the
  latest changes. Manual "force-refreshes" (Ctrl+F5) should no longer be
  routinely required.
- **Automatic Rebuilding (Legacy/Manual):** While `make run-mock` handles
  rebuilding automatically, you can still run it manually in a second
  terminal if needed:
  ```bash
  npm run watch
  ```
  You will still need to refresh your browser.

## Contribute

This project lives on GitHub at https://github.com/openSUSE/qem-dashboard. Feel free to add issues or send pull
requests there.

### Rules for Commits

- For git commit messages use the rules stated on
  [How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/) as a reference.
- **Automated Validation:** Commit messages are automatically checked using `commitlint` to ensure they
  follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.
- **Line Width:** The commit body is restricted to a maximum of **80 characters** per line.
- As a SUSE colleague consider signing commits which we consider to use for
  automatic deployments within SUSE.

If this is too much hassle for you feel free to provide incomplete pull requests for consideration or create an issue
with a code change proposal.

### Local Testing

To execute all tests a PostgreSQL instance is needed and needs to be specified in the environment variable
`TEST_ONLINE`. For a local PostgreSQL instance with a username and password one could call:

```
TEST_ONLINE=postgresql://postgres:postgres@localhost:5432/postgres prove -l t/*.t t/*.t.js
```

### Coverage Requirement

Every change to the Perl backend must maintain or achieve **100% statement coverage**. Use the following command to verify coverage:

```bash
make test-coverage
```

Tasks are only considered complete once full coverage is confirmed and all tests pass.

### Documentation

For further documentation, please see **[docs](https://github.com/openSUSE/qem-dashboard/tree/main/docs)**

### Further notes

A containerized environment could be used to build and run the dashboard and its dependencies.
For a concrete example, checkout the (so far) internal documentation under
https://gitlab.suse.de/qe-core/dev-dashboard or containers quick start guide
in **[docs/Containers](https://github.com/openSUSE/qem-dashboard/tree/main/docs/Containers.md)**

## License

This project is licensed under the [GPLv2 license](http://www.gnu.org/licenses/gpl-2.0.html), see the COPYING file for
details.
