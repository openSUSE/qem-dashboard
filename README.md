# QEM Dashboard

  The QEM Dashboard is a graphical user interface addon for the not yet released **openQABot**. It can show the current
  state for all incidents that are being processed. To help identify which tests are currently blocking which incidents.

## Getting Started

  To get started all you need is an empty PostgreSQL database and the following dependencies:

    $ sudo zypper in -C postgresql-server postgresql-contrib
    $ sudo zypper in -C perl-Mojolicious perl-Mojolicious-Plugin-AssetPack \
      perl-Mojo-Pg perl-Cpanel-JSON-XS perl-JSON-Validator perl-IO-Socket-SSL

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


  And finally use the `morbo` development web server to make the web application available under
  `http://127.0.0.1:3000`.

    $ morbo script/dashboard
    Web application available at http://127.0.0.1:3000
