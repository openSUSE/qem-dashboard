requires 'Mojolicious', '>= 9.39';
requires 'Mojolicious::Plugin::OpenAPI';
requires 'Mojo::Pg', '>= 4.25';
requires 'Mojo::RabbitMQ::Client';
requires 'Cpanel::JSON::XS', '>= 4.40';
requires 'Devel::Cover';
requires 'JSON::Validator';
requires 'YAML::XS';
requires 'IO::Socket::SSL', '>= 2.009';
requires 'MCP';

on 'test' => sub {
    requires 'CPAN::Audit';
    requires 'Test::Deep';
    requires 'Test::Harness', '>= 3.48';
    requires 'Test::MockModule';
    requires 'Test::Output';
    requires 'Test::Warnings';
};

feature 'coverage', 'coverage for CI' => sub {
    requires 'Devel::Cover';
    requires 'Devel::Cover::Report::Coveralls';
};
