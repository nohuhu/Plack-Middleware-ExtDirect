use 5.008000;
use ExtUtils::MakeMaker;

# Add the `devtest` target to run regression and POD tests in one go
sub MY::postamble {
    return <<'END';
devtest :
	REGRESSION_TESTS=1 POD_TESTS=1 $(MAKE) test

END
}

# Override `disttest` so it would behave as `devtest`
sub MY::dist_test {
	return <<'END';
disttest : distdir
	cd $(DISTVNAME) && $(ABSPERLRUN) Makefile.PL
	cd $(DISTVNAME) && $(MAKE) $(PASTHRU)
	cd $(DISTVNAME) && $(MAKE) devtest $(PASTHRU)

END
}

my $MM_VERSION = $ExtUtils::MakeMaker::VERSION;
my $github_uri = 'https://github.com/nohuhu/Plack-Middleware-ExtDirect';

WriteMakefile(
    NAME              => 'Plack::Middleware::ExtDirect',
    VERSION_FROM      => 'lib/Plack/Middleware/ExtDirect.pm',
    
    ($MM_VERSION >= 6.5503
        ? (
            TEST_REQUIRES => {
                'Test::More'     => '0.82', # for explain()
            },
            PREREQ_PM => {
                'Plack'          => '1.0',
                'RPC::ExtDirect' => '3.02',
            },
        )
        :(
            BUILD_REQUIRES => {
                'Test::More'     => '0.82',
            },
            PREREQ_PM => {
                'Plack'          => '1.0',
                'RPC::ExtDirect' => '3.02',
            },
        )
    ),
    
    ABSTRACT => 'RPC::ExtDirect gateway for Plack',
    AUTHOR   => 'Alex Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',
    
    ($MM_VERSION >= 6.48
        ? ( MIN_PERL_VERSION => 5.008000 )
        : ()
    ),
    
    ($MM_VERSION >= 6.46
        ? (
            META_MERGE => {
                resources   => {
                    bugtracker  => "$github_uri/issues",
                    repository  => $github_uri,
                },
            },
        )
        : ()
    ),
);
