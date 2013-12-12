use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Test::More tests => 13;

BEGIN { use_ok 'Plack::Middleware::ExtDirect'; }

use Plack::Builder;
use Plack::Test;
use HTTP::Request;

use RPC::ExtDirect::Test::Util;

# Test modules
use lib 't/lib';
use RPC::ExtDirect::Test::Foo;
use RPC::ExtDirect::Test::Bar;
use RPC::ExtDirect::Test::Qux;
use RPC::ExtDirect::Test::PollProvider;

my $dfile = 't/data/extdirect/api';
my $tests = eval do { local $/; open my $fh, '<', $dfile; <$fh> } ## no critic
    or die "Can't eval $dfile: '$@'";

our ($name, $url, $method, $input_content, $http_status, $content_type);
our ($plack_input, $expected_content);

for my $test ( @$tests ) {
    local $name             = $test->{name};
    local $url              = $test->{plack_url};
    local $method           = $test->{method};
    local $input_content    = $test->{input_content};
    local $plack_input      = $test->{plack_input};
    local $http_status      = $test->{http_status};
    local $content_type     = $test->{content_type};
    local $expected_content = $test->{expected_content};

    my $test_app    = builder {
        enable 'ExtDirect', @$plack_input;
        sub {
            [ 200, [ 'Content-type', 'text/plain' ], [ 'ok' ] ]
        };
    };

    my $test_client = sub {
        my ($cb) = @_;

        my $req = HTTP::Request->new($method => $url);
        my $res = $cb->($req);

        ok   $res,                              "$name not empty";
        is   $res->code,   $http_status,        "$name http status";
        like $res->content_type, $content_type, "$name content type";

        my $http_content = $res->content;

        my $actual_data   = deparse_api($http_content);
        my $expected_data = deparse_api($expected_content);

        is_deeply $actual_data, $expected_data, "$name content"
            or diag explain "actual:\n",   $actual_data,
                            "expected:\n", $expected_data;
    };

    test_psgi app => $test_app, client => $test_client;
};

done_testing;
