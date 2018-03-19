use strict; use warnings;

use Plack::Test;
use Plack::Builder;
use Test::More tests => 5;
use HTTP::Request::Common;
use Plack::Middleware::RedirectSSL ();

my $app = sub { [ 204, [], [] ] };
my $mw = Plack::Middleware::RedirectSSL->new( app => $app );

test_psgi app => $mw->to_app, client => sub {
	my $cb = shift;
	my $res;

	my $hsts_age = Plack::Middleware::RedirectSSL::DEFAULT_STS_MAXAGE;

	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age, 'HSTS is enabled by default';

	is +Plack::Middleware::RedirectSSL->new( app => $app, hsts => 0 )->hsts, 0, '... unless overridden during construction';

	$mw->hsts( $hsts_age = 60 * 60 );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age, '... but can be changed';

	$mw->hsts( '0 but true' );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age=0', '... or even set to zero';

	$mw->hsts( 0 );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), undef, '... or completely disabled';
};
