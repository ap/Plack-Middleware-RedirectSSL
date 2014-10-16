package Plack::Middleware::RedirectSSL;
use 5.010;
use strict;
use parent 'Plack::Middleware';

# ABSTRACT: force all requests to use in-/secure connections

use Plack::Util ();
use Plack::Util::Accessor qw( ssl hsts );
use Plack::Request ();

#                           seconds minutes hours days weeks
sub DEFAULT_STS_MAXAGE () { 60    * 60    * 24  * 7  * 26 }

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

	my $res = $self->app->( $env );

	if ( $is_ssl and $self->hsts // 1 ) {
		my $max_age = 0 + ( $self->hsts // DEFAULT_STS_MAXAGE );
		$res = Plack::Util::response_cb( $res, sub {
			my $res = shift;
			Plack::Util::header_set( $res->[1], 'Strict-Transport-Security', "max-age=$max_age" );
		} );
	}

	return $res;
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

=item C<hsts>

Specifies the C<max-age> value for the C<Strict-Transport-Security> header.
(Cf. L<RFCE<nbsp>6797, I<HTTP Strict Transport Security>|http://tools.ietf.org/html/rfc6797>.)
If not specified, it defaults to 6 weeks. If 0, no C<Strict-Transport-Security>
header will be sent.

=back

=cut
