use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use RPC::ExtDirect::Test::Pkg::Foo;
use RPC::ExtDirect::Test::Pkg::Bar;
use RPC::ExtDirect::Test::Pkg::Qux;
use RPC::ExtDirect::Test::Pkg::PollProvider;

use lib 't/lib';
use RPC::ExtDirect::Test::Util::Plack;
use RPC::ExtDirect::Test::Data::API;

use Plack::Middleware::ExtDirect;

my $tests = RPC::ExtDirect::Test::Data::API::get_tests;

run_tests($tests, @ARGV);
