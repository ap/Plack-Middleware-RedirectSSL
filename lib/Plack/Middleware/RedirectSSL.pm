package Plack::Middleware::RedirectSSL;
use 5.010;
use strict;
use parent 'Plack::Middleware';

# ABSTRACT: force all requests to use in-/secure connections

use Plack::Util ();
use Plack::Util::Accessor qw( ssl );
use Plack::Request ();

sub call {
	my $self = shift;
	my $env  = shift;

	my $do_ssl = ( $self->ssl // 1 )                      ? 1 : 0;
	my $is_ssl = ( 'https' eq $env->{'psgi.url_scheme'} ) ? 1 : 0;

	if ( $is_ssl xor $do_ssl ) {
		my $m = $env->{'REQUEST_METHOD'};
		return [ 400, [qw( Content-Type text/plain )], [ 'Bad Request' ] ]
			if 'GET' ne $m and 'HEAD' ne $m;
		my $uri = Plack::Request->new( $env )->uri;
		$uri->scheme( $do_ssl ? 'https' : 'http' );
		return [ 301, [ Location => $uri ], [] ];
	}

	$self->app->( $env );
}

1;

__END__

=head1 SYNOPSIS

 # in app.psgi
 use Plack::Builder;
 
 builder {
     enable 'RedirectSSL';
     $app;
 };

=head1 DESCRIPTION

This middleware intercepts requests using either the C<http> or C<https> scheme
and redirects them to the same URI under respective other scheme.

=head1 CONFIGURATION OPTIONS

=over 4

=item C<ssl>

Specifies the direction of redirects. If true or not specified, requests using
C<http> will be redirected to C<https>. If false, requests using C<https> will
be redirected to plain C<http>.

=back

=head1 BUGS

Probably that it does not (yet?) support
RFCE<nbsp>6797 (HTTP Strict Transport Security (HSTS)).

=cut
