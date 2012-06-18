use 5.008000;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    NAME              => 'Plack::Middleware::ExtDirect',
    VERSION_FROM      => 'lib/Plack/Middleware/ExtDirect.pm', # finds $VERSION
    BUILD_REQUIRES    => {
        'Test::More'  => 0,
    },
    PREREQ_PM         => {
        'Plack'          => '0.9988',
        'RPC::ExtDirect' => '2.00',
    },
    ABSTRACT => 'RPC::ExtDirect gateway for Plack environment',
    AUTHOR   => 'Alexander Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',
    META_MERGE => {
        resources   => {
            bugtracker  => 'http://github.com/nohuhu/Plack-Middleware-ExtDirect/issues',
            repository  => 'http://github.com/nohuhu/Plack-Middleware-ExtDirect',
        },
    },
);

