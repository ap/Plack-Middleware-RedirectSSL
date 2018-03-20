use 5.006; use strict; use warnings;

package Plack::Middleware::RedirectSSL;

# ABSTRACT: force all requests to use in-/secure connections

use parent 'Plack::Middleware';

use Plack::Util ();
use Plack::Util::Accessor qw( ssl hsts_header );
use Plack::Request ();

#                           seconds minutes hours days weeks
sub DEFAULT_STS_MAXAGE () { 60    * 60    * 24  * 7  * 26 }

sub call {
	my ( $self, $env ) = ( shift, @_ );

	my $do_ssl = $self->ssl ? 1 : 0;
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

	return $res unless $is_ssl and my $hsts = $self->hsts_header;

	Plack::Util::response_cb( $res, sub {
		Plack::Util::header_set( $_[0][1], 'Strict-Transport-Security', $hsts );
	} );
}

sub hsts {
	my ( $self, $value ) = ( shift, @_ );
	return $self->{'hsts'} unless @_;
	my $max_age = $value ? 0 + $value : defined $value ? undef : DEFAULT_STS_MAXAGE;
	$self->hsts_header( defined $max_age ? 'max-age=' . $max_age : undef );
	$self->{'hsts'} = $value;
}

sub new {
	my $self = shift->SUPER::new( @_ );
	$self->ssl(1) if not defined $self->ssl;
	if    ( exists $self->{'hsts'} ) { $self->hsts( $self->{'hsts'} ) }
	elsif ( not $self->hsts_header ) { $self->hsts( undef ) }
	$self;
}

1;

__END__

=pod

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

=item C<hsts_header>

Specifies an arbitrary string value for the C<Strict-Transport-Security> header.
If false, no such header will be sent.

=item C<hsts>

Specifies a C<max-age> value for an HSTS policy with no other directives
and updates the C<hsts_header> option to reflect it.
If undef, sets a C<hsts_header> to a C<max-age> of 26E<nbsp>weeks.
If otherwise false, sets C<hsts_header> to C<undef>.
(If you really want a C<max-age> value of 0, use C<'00'>, C<'0E0'> or C<'0 but true'>.)

=back

=head1 SEE ALSO

=over 4

=item *

L<RFCE<nbsp>6797, I<HTTP Strict Transport Security>|http://tools.ietf.org/html/rfc6797>

=back

=cut
