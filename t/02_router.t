use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Test::More tests => 25;

BEGIN { use_ok 'Plack::Middleware::ExtDirect'; }

use Plack::Builder;
use Plack::Test;
use HTTP::Request::Common;

# Test modules
use lib 't/lib';
use RPC::ExtDirect::Test::Foo;
use RPC::ExtDirect::Test::Bar;
use RPC::ExtDirect::Test::JuiceBar;
use RPC::ExtDirect::Test::Qux;
use RPC::ExtDirect::Test::PollProvider;

# Set the cheat flag for file uploads
local $RPC::ExtDirect::Test::JuiceBar::CHEAT = 1;

my $dfile = 't/data/extdirect/route';
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

        my $req = $input_content;
        my $res = $cb->($req);

        ok   $res,                              "$name not empty";
        is   $res->code,   $http_status,        "$name http status";
        like $res->content_type, $content_type, "$name content type";

        my $http_content = $res->content;

        # Remove whitespace
        s/\s//g for $expected_content, $http_content;

        is $http_content, $expected_content, "$name content";
    };

    test_psgi app => $test_app, client => $test_client;
};

done_testing;

sub raw_post {
    my ($url, $post) = @_;

    return POST $url, Content => $post;
}

sub form_post {
    my ($url, @fields) = @_;

    return POST $url, Content => [ @fields ];
}

sub form_upload {
    my ($url, $files, @fields) = @_;

    my $type = 'application/octet-stream';

    return POST $url,
           Content_Type => 'form-data',
           Content      => [ @fields,
                             map {
                                    (   upload => [
                                            "t/data/cgi-data/$_",
                                            $_,
                                            'Content-Type' => $type,
                                        ]
                                    )
                                 } @$files
                           ]
    ;
}

