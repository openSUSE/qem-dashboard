# QEM Dashboard

The QEM Dashboard is a graphical user interface addon for [qem-bot](https://github.com/openSUSE/qem-bot). It can show
the current state for all incidents that are being processed. To help identify which tests are currently blocking
which incidents.

## Getting Started

  To get started all you need is an empty PostgreSQL database and the following dependencies:

    $ sudo zypper in -C postgresql-server postgresql-contrib
    $ sudo zypper in -C perl-Mojolicious perl-Mojolicious-Plugin-Webpack \
      perl-Mojo-Pg perl-Cpanel-JSON-XS perl-JSON-Validator perl-IO-Socket-SSL nodejs16
    $ npm install

Update the config file `dashboard.yml` to point to your PostgreSQL database (and other services where appropriate):

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
### Local Development

An quick way to build and run the dashboard and its dependencies can be with docker.
More info here https://gitlab.suse.de/qsf-u/dev-dashboard

## License

This project is licensed under the [GPLv2 license](http://www.gnu.org/licenses/gpl-2.0.html), see the COPYING file for
details.
