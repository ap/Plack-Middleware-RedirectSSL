package Plack::Middleware::RedirectSSL;
use 5.010;
use strict;
use parent 'Plack::Middleware';

# ABSTRACT:

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
     $app;
 };

=head1 DESCRIPTION
