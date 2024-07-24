# QEM Dashboard

[![Coverage Status](https://coveralls.io/repos/github/openSUSE/qem-dashboard/badge.svg?branch=main)](https://coveralls.io/github/openSUSE/qem-dashboard?branch=main)

The QEM Dashboard is a graphical user interface addon for [qem-bot](https://github.com/openSUSE/qem-bot). It can show
the current state for all incidents that are being processed. To help identify which tests are currently blocking
which incidents. Its deployment happens once a day via
[GitLab pipelines](https://gitlab.suse.de/opensuse/qem-dashboard/-/pipeline_schedules).

## Getting Started

### Dependencies

To get started all you need is an empty PostgreSQL database and the following dependencies:

    $ sudo zypper in -C postgresql-server postgresql-contrib
    $ sudo zypper in -C perl-Mojolicious perl-Mojolicious-Plugin-Webpack \
      perl-Mojo-Pg perl-Cpanel-JSON-XS perl-JSON-Validator perl-IO-Socket-SSL nodejs16
    $ npm install

#### nodejs16

In case `nodejs16` is not available (e.g. Tumbleweed), you can alternatively get it via the [Node Version Manager](https://github.com/nvm-sh/nvm). Simply [install nvm](https://github.com/nvm-sh/nvm?tab=readme-ov-file#install--update-script) then run `nvm install 16` and `nvm use 16`.

### Postgres Database

The postgresql-server package installation in the previous step, created a database called `postgres` by the user `postgres`.

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

And finally use the `mojo webpack` development web server to make the web application available under
`http://127.0.0.1:3000`.

    $ mojo webpack script/dashboard
    Web application available at http://127.0.0.1:3000

### Project structure

- **[API.md](https://github.com/openSUSE/qem-dashboard/blob/main/API.md)**: API documentation.
- **[assets](https://github.com/openSUSE/qem-dashboard/tree/main/assets)**: Contains JavaScript files, stylesheets, etc.
- **[cpanfile](https://github.com/openSUSE/qem-dashboard/blob/main/cpanfile)**: Configuration file used to manage Perl dependencies.
- **[eslint.config.mjs](https://github.com/openSUSE/qem-dashboard/blob/main/eslint.config.mjs)**: Configuration file for JavaScript linter.
- **[lib](https://github.com/openSUSE/qem-dashboard/tree/main/lib)**: Core library of Perl code.
- **[migrations](https://github.com/openSUSE/qem-dashboard/blob/main/migrations)**: Database migration scripts.
- **[node_modules](https://github.com/openSUSE/qem-dashboard/tree/main/node_modules)**: Dependencies installed by npm (Node Package Manager)
- **[package.json](https://github.com/openSUSE/qem-dashboard/tree/main/package.json)** and **[package-lock.json](https://github.com/openSUSE/qem-dashboard/tree/main/package-lock.json)**: Configuration files used to manage dependencies.
- **[public](https://github.com/openSUSE/qem-dashboard/tree/main/public)**: Publicly accessible assets, such as images and static files.
- **[script](https://github.com/openSUSE/qem-dashboard/tree/main/script)**: Used to automate tasks and workflows.
- **[t](https://github.com/openSUSE/qem-dashboard/tree/main/t)**: Containing test files.
- **[templates](https://github.com/openSUSE/qem-dashboard/tree/main/templates)**: Template files, used to generate dynamic content.
- **[webpack.config.js](https://github.com/openSUSE/qem-dashboard/tree/main/webpack.config.js)**: Configuration file for Webpack, a JavaScript bundler used to prepare code for production.

## Contribute

This project lives on GitHub at https://github.com/openSUSE/qem-dashboard. Feel free to add issues or send pull
requests there.

### Rules for Commits

* For git commit messages use the rules stated on
  [How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/) as a reference

If this is too much hassle for you feel free to provide incomplete pull requests for consideration or create an issue
with a code change proposal.

### Local Testing

To execute all tests a PostgreSQL instance is needed and needs to specified in the environment variable `TEST_ONLINE`.
For a local PostgreSQL instance with a username and password one could call:

```
TEST_ONLINE=postgresql://postgres:postgres@localhost:5432/postgres prove -l t/*.t t/*.t.js
```
### Further notes
A containerized environment could be used to build and run the dashboard and its dependencies.
For a concrete example, checkout the (so far) internal documentation under
https://gitlab.suse.de/qe-core/dev-dashboard.

## License

This project is licensed under the [GPLv2 license](http://www.gnu.org/licenses/gpl-2.0.html), see the COPYING file for
details.
