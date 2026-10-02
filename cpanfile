requires 'Mojolicious', '>= 9.48';
requires 'Mojolicious::Plugin::OpenAPI';
requires 'Mojo::Pg', '>= 4.25';
requires 'Mojo::RabbitMQ::Client';
requires 'Cpanel::JSON::XS', '>= 4.41';
requires 'Devel::Cover';
requires 'JSON::Validator';
requires 'YAML::XS', '>= 0.903.0';
requires 'IO::Socket::SSL', '>= 2.009';
requires 'MCP', '< 0.15';

# The following are only indirect dependencies to satisfy cpan-audit:
requires 'Compress::Raw::Zlib', '>= 2.220';
requires 'HTTP::Tiny', '>= 0.095';
requires 'IO::Compress', '>= 2.220';

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
