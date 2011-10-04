use 5.008000;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    NAME              => 'Plack::Middleware::ExtDirect',
    VERSION_FROM      => 'lib/Plack/Middleware/ExtDirect.pm', # finds $VERSION
    PREREQ_PM         => {
        'Plack'          => '0.9982',
        'RPC::ExtDirect' => '1.20',
        'Test::More'     => 0,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT => 'RPC::ExtDirect gateway for Plack environment',
       AUTHOR   => 'Alexander Tokarev <nohuhu@apple.com>',
       LICENSE  => 'perl',
      ) : ()),
);
