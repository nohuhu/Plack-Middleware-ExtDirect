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

# Finally, write Makefile
WriteMakefile(
    NAME              => 'Plack::Middleware::ExtDirect',
    VERSION_FROM      => 'lib/Plack/Middleware/ExtDirect.pm',
    BUILD_REQUIRES    => {
        'Test::More'  => 0,
    },
    PREREQ_PM         => {
        'Plack'          => '1.0',
        'RPC::ExtDirect' => '3.0',
    },
    ABSTRACT => 'RPC::ExtDirect gateway for Plack',
    AUTHOR   => 'Alex Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',
    META_MERGE => {
        resources   => {
            bugtracker  => 'http://github.com/nohuhu/Plack-Middleware-ExtDirect/issues',
            repository  => 'http://github.com/nohuhu/Plack-Middleware-ExtDirect',
        },
    },
);

