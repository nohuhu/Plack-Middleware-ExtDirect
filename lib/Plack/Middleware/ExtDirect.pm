package Plack::Middleware::ExtDirect;

use parent 'Plack::Middleware';

# ABSTRACT: Ext.Direct gateway implementation for Plack

use strict;
use warnings;
no  warnings 'uninitialized';       ## no critic

use Carp;
use IO::File;

use Plack::Request;
use Plack::Util;

use RPC::ExtDirect::Util::Accessor;
use RPC::ExtDirect::Config;
use RPC::ExtDirect::API;
use RPC::ExtDirect;

#
# This module is not compatible with RPC::ExtDirect < 3.0
#

croak __PACKAGE__." requires RPC::ExtDirect 3.0+"
    if $RPC::ExtDirect::VERSION lt 3.0;

### PACKAGE GLOBAL VARIABLE ###
#
# Version of the module
#

our $VERSION = '3.00_01';

### PUBLIC INSTANCE METHOD (CONSTRUCTOR) ###
#
# Instantiates a new Plack::Middleware::ExtDirect object
#

sub new {
    my $class = shift;
    
    my %params = @_ == 1 && 'HASH' eq ref($_[0]) ? %{ $_[0] } : @_;
    
    my $api    = delete $params{api}    || RPC::ExtDirect->get_api();
    my $config = delete $params{config} || $api->config;
    
    # These two are not method calls, they need to do their stuff *before*
    # we have found $self
    _decorate_config($config);
    _process_params($api, $config, \%params);
    
    my $self = $class->SUPER::new(%params);
    
    $self->config($config);
    $self->api($api);
    
    return $self;
}

### PUBLIC INSTANCE METHOD ###
#
# Dispatch calls to Ext.Direct handlers
#

sub call {
    my ($self, $env) = @_;
    
    my $config = $self->config;

    # Run the relevant handler
    for ( $env->{PATH_INFO} ) {
        return $self->_handle_api($env)    if $_ =~ $config->api_path;
        return $self->_handle_router($env) if $_ =~ $config->router_path;
        return $self->_handle_events($env) if $_ =~ $config->poll_path;
    };

    # Not our URI, fall through
    return $self->app->($env);
}

### PUBLIC INSTANCE METHODS ###
#
# Read-write accessors
#

RPC::ExtDirect::Util::Accessor->mk_accessors(
    simple => [qw/ api config /],
);

############## PRIVATE METHODS BELOW ##############

### PRIVATE PACKAGE SUBROUTINE ###
#
# Decorate a Config object with __PACKAGE__-specific accessors
#

sub _decorate_config {
    my ($config) = @_;
    
    $config->add_accessors(
        overwrite => 1,
        complex   => [{
            accessor => 'router_class_plack',
            fallback => 'router_class',
        }, {
            accessor => 'eventprovider_class_plack',
            fallback => 'eventprovider_class',
        }],
    );
}

### PRIVATE PACKAGE SUBROUTINE ###
#
# Process parameters directly passed to the constructor
# and set the Config/API options accordingly
#

sub _process_params {
    my ($api, $config, $params) = @_;
    
    # We used to accept these parameters directly in the constructor;
    # this behavior is not recommended now but it doesn't make much sense
    # to deprecate it either
    my @compat_params = qw/
        api_path router_path poll_path namespace remoting_var polling_var
        auto_connect debug no_polling
    /;
    
    for my $var ( @compat_params ) {
        $config->$var( delete $params->{$var} ) if exists $params->{$var};
    }
    
    $config->router_class_plack( delete $params->{router} )
        if exists $params->{router};
    
    $config->eventprovider_class_plack( delete $params->{event_provider} )
        if exists $params->{event_provider};
    
    for my $type ( $api->HOOK_TYPES ) {
        my $code = delete $params->{ $type } if exists $params->{ $type };
        
        $api->add_hook( type => $type, code => $code ) if defined $code;
    }
}

### PRIVATE INSTANCE METHOD ###
#
# Handles Ext.Direct API calls
#

sub _handle_api {
    my ($self, $env) = @_;

    # Get the API JavaScript chunk
    my $js = eval {
        $self->api->get_remoting_api( config => $self->config )
    };

    # If JS API call failed, return error
    return $self->_error_response if $@;

    # We need content length, in octets
    my $content_length = do { use bytes; my $len = length $js };

    return [
                200,
                [
                    'Content-Type'   => 'application/javascript',
                    'Content-Length' => $content_length,
                ],
                [ $js ],
           ];
}

### PRIVATE INSTANCE METHOD ###
#
# Dispatches Ext.Direct method requests
#

sub _handle_router {
    my ($self, $env) = @_;
    
    # Throw an error if any method but POST is used
    return $self->_error_response
        unless $env->{REQUEST_METHOD} eq 'POST';
    
    my $config = $self->config;
    my $api    = $self->api;

    # Now we need a Request object
    my $req = Plack::Request->new($env);

    # Try to distinguish between raw POST and form call
    my $router_input = $self->_extract_post_data($req);

    # When extraction fails, undef is returned by method above
    return $self->_error_response unless defined $router_input;

    # Rebless request as our environment object for compatibility
    bless $req, __PACKAGE__.'::Env';
    
    my $router_class = $config->router_class_plack;
    
    eval "require $router_class";
    
    my $router = $router_class->new(
        config => $config,
        api    => $api,
    );
    
    # Routing requests is safe (Router won't croak under torture)
    my $result = $router->route($router_input, $req);

    return $result;
}

### PRIVATE INSTANCE METHOD ###
#
# Polls Event handlers for events, returning serialized stream
#

sub _handle_events {
    my ($self, $env) = @_;
    
    # Only GET and POST methods are supported for polling
    return $self->_error_response
        if $env->{REQUEST_METHOD} !~ / \A (GET|POST) \z /xms;

    my $req = Plack::Middleware::ExtDirect::Env->new($env);
    
    my $config = $self->config;
    my $api    = $self->api;
    
    my $provider_class = $config->eventprovider_class_plack;
    
    eval "require $provider_class";
    
    my $provider = $provider_class->new(
        config => $config,
        api    => $api,
    );

    # Polling for Events is safe
    my $http_body = $provider->poll($req);

    # We need content length, in octets
    my $content_length
        = do { no warnings 'void'; use bytes; length $http_body };

    return [
                200,
                [
                    'Content-Type'   => 'application/json; charset=utf8',
                    'Content-Length' => $content_length,
                ],
                [ $http_body ],
           ];
}

### PRIVATE INSTANCE METHOD ###
#
# Deals with intricacies of POST-fu and returns something suitable to
# feed to Router (string or hashref, really). Or undef if something
# goes too wrong to recover.
#

sub _extract_post_data {
    my ($self, $req) = @_;

    # The smartest way to tell if a form was submitted that *I* know of
    # is to look for 'extAction' and 'extMethod' keywords in form params.
    my $is_form = $req->param('extAction') && $req->param('extMethod');

    # If form is not involved, it's easy: just return raw POST (or undef)
    if ( !$is_form ) {
        my $postdata = $req->content;
        return $postdata ne '' ? $postdata
               :                 undef
               ;
    };

    # If any files are attached, extUpload field will be set to 'true'
    my $has_uploads = $req->param('extUpload') eq 'true';

    # Outgoing hash
    my %keyword;

    # Pluck all parameters from Plack::Request
    for my $param ( $req->param ) {
        my @values = $req->param($param);
        $keyword{ $param } = @values == 0 ? undef
                           : @values == 1 ? $values[0]
                           :                [ @values ]
                           ;
    };

    # Find all file uploads
    if ( $has_uploads ) {
        my $uploads = $req->uploads;    # Hash::MultiValue

        # We need files as plain list (keys %$uploads is by design)
        my @field_uploads
            = map { $self->_format_uploads( $uploads->get_all($_) ) }
                  keys %$uploads;

        # Now remove fields that contained files
        delete @keyword{ $uploads->keys };

        $keyword{ '_uploads' } = \@field_uploads if @field_uploads;
    };

    # Remove extType because it's meaningless later on
    delete $keyword{ extType };

    # Fix TID so that it comes as number (JavaScript is picky)
    $keyword{ extTID } += 0 if exists $keyword{ extTID };

    return \%keyword;
}

### PRIVATE INSTANCE METHOD ###
#
# Takes info from Plack::Request::Upload and formats it as needed
#

sub _format_uploads {
    my ($self, @uploads) = @_;

    my @result = map {
                        {
                            filename => $_->filename,
                            basename => $_->basename,
                            type     => $_->content_type,
                            size     => $_->size,
                            path     => $_->path,
                            handle   => IO::File->new($_->path, 'r'),
                        }
                     }
                     @uploads;

    return @result;
}

### PRIVATE INSTANCE METHOD ###
#
# Returns error response in Plack format
#

sub _error_response { [ 500, [ 'Content-Type' => 'text/html' ], [] ] }

# Small utility class
package Plack::Middleware::ExtDirect::Env;

use parent 'Plack::Request';

sub http {
    my ($self, $name) = @_;

    my $hdr = $self->headers;

    return $name ? $hdr->header($name)
         :         $hdr->header_field_names
         ;
}

sub param {
    my ($self, $name) = @_;

    return $name eq 'POSTDATA' ?   $self->content
         : $name eq ''         ? ( $self->SUPER::param(), 'POSTDATA' )
         :                         $self->SUPER::param($name)
         ;
}

sub cookie {
    my ($self, $name) = @_;

    return $name ? $self->cookies()->{ $name }
         :         keys %{ $self->cookies() }
         ;
}

1;

__END__

=pod

=head1 NAME

Plack::Middleware::ExtDirect - RPC::ExtDirect gateway for Plack

=head1 SYNOPSIS

In your plackup, before C<Plack::Runner-E<gt>run()>:

 use My::Server::Side::Class;
 use My::Server::Side::Class2;

In your app.psgi:

 my $app = sub { ... };
 
 builder {
    enable 'ExtDirect', api_path     => '/extdirect_api',
                        router_path  => '/extdirect_router',
                        poll_path    => '/extdirect_events',
                        remoting_var => 'Ext.app.REMOTING_API',
                        polling_var  => 'Ext.app.POLLING_API',
                        namespace    => 'myApp',    # Defaults to empty
                        auto_connect => 0,
                        no_polling   => 0,
                        debug        => 0,
                        before       => \&global_before_hook,
                        after        => \&global_after_hook,
                        ;
    $app;
 }

=head1 DESCRIPTION

This module provides RPC::ExtDirect gateway implementation for Plack
environment. It is packaged as standard Plack middleware component
suitable for use with Plack::Builder.

You can change some default configuration options by passing
corresponding parameters like shown above. For the meaning of parameters,
see L<RPC::ExtDirect::API> documentation.

Note that Ext.Direct specification requires server side implementation
to return diagnostic messages only when debugging is explicitly turned
on. This is why C<debug> flag defaults to 'off' and RPC::ExtDirect
returns generic error messages that do not contain any details as to
where and what error has happened.

=head1 CAVEATS

=head2 Attribute handlers

For RPC::ExtDirect attribute handlers to work properly, modules that
expose ExtDirect Methods should be loaded at compile time. On the other
hand, Plack::Runner loads and compiles code in *.psgi at runtime, and
that breaks attribute magic dust. To avoid this, make sure you load
all modules that provide Ext.Direct functionality - including Event
providers - before Plack::Runner starts. The easiest way to do this
is to copy plackup script and modify it a little to C<use>
all relevant modules in it.

See included code examples to see how it works.

=head2 Environment object

For Plack Ext.Direct gateway, the environment object is based on
Plack::Request. While it does provide the same methods described
in L<RPC::ExtDirect/ENVIRONMENT OBJECTS>, behavior of these methods
can be slightly different from CGI environment. For example,
C<$env-E<gt>http()> in CGI will return the list of both environment
variables and HTTP headers in upper case, while the same
C<$env-E<gt>http()> in Plack application will return only HTTP headers
as they were defined in HTTP spec. To avoid problems, always find
the actual header name first and then use it:

    my ($header) = grep { /^Content[-_]Type$/i } $env->http();
    my $value    = $env->http($header) if $header;
    
    ...

=head1 DEPENDENCIES

Plack::Middleware::ExtDirect is dependent on the following modules:
L<Plack>, L<RPC::ExtDirect>, L<JSON>, L<Attribute::Handlers>.

=head1 SEE ALSO

For more information on core functionality see L<RPC::ExtDirect>.

For more information on Ext.Direct API see specification:
L<http://www.sencha.com/products/extjs/extdirect/> and documentation:
L<http://docs.sencha.com/ext-js/4-0/#!/api/Ext.direct.Manager>.

See included ExtJS examples for ideas on what Ext.Direct is and how to
use it.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module. To report bugs, use github RT
(the best way) or just drop me an e-mail. Patches are welcome.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 ACKNOWLEDGEMENTS

I would like to thank IntelliSurvey, Inc for sponsoring my work
on version 2.0 of RPC::ExtDirect suite of modules.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

Included ExtJS examples are copyright (c) 2011, Sencha Inc. Example code is
used and distributed under GPL 3.0 license as provided by Sencha Inc. See
L<http://www.sencha.com/license>

=cut

