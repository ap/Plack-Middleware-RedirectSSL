use strict; use warnings;

use Plack::Test;
use Plack::Builder;
use Test::More tests => 10;
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

	$mw->hsts_header( 'nonsense' );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'nonsense', '... or overridden with an arbitrary header value';

	is $mw->hsts, '0 but true', '... while remembering the previous max-age value';

	$mw->hsts( 0 );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), undef, '... or completely disabled';

	$hsts_age = Plack::Middleware::RedirectSSL::DEFAULT_STS_MAXAGE;
	$mw->hsts( undef );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age, '... or reset to default';
};

$mw = Plack::Middleware::RedirectSSL->new( app => $app, hsts_header => 'nonsense' );
is $mw->hsts_header, 'nonsense', 'Arbitrary header values at construction time are preserved';

$mw = Plack::Middleware::RedirectSSL->new( app => $app, hsts_header => 'nonsense', hsts => 1 );
is $mw->hsts_header, 'max-age=1', '... but a hsts option takes precedence';
