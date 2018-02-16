use strict; use warnings;

use Plack::Test;
use Plack::Builder;
use Test::More tests => 28;
use HTTP::Request::Common;
use Plack::Middleware::RedirectSSL ();

my $mw = Plack::Middleware::RedirectSSL->new( app => sub {
	return [ 204, [qw( Content-Type text/plain )], [ '' ] ];
} );

test_psgi app => $mw->to_app, client => sub {
	my $cb = shift;
	my $res;

	$res = $cb->( GET 'http://localhost/' );
	is $res->code, 301, 'The default is to redirect HTTP to HTTPS';

	$res = $cb->( GET 'https://localhost/' );
	is $res->code, 204, '... and not vice versa';

	for my $do_ssl ( 1, 0 ) {
		$mw->ssl( $do_ssl );

		my $abs_uri = '//localhost/foo/bar';
		my $coscheme     = $do_ssl ? 'https' : 'http';
		my $contrascheme = $do_ssl ? 'http' : 'https';
		my $onoff        = $do_ssl ? 'on' : 'off';

		$res = $cb->( GET "$contrascheme:$abs_uri" );
		is $res->code, 301, "Under RequireSSL $onoff, \U$contrascheme\E requests are redirected";
		is $res->header( 'Location' ), "$coscheme:$abs_uri", "... to the same host and path under the \U$coscheme\E scheme";

		$res = $cb->( HEAD "$contrascheme:$abs_uri" );
		is $res->code, 301, '... using GET and HEAD method';

		$res = $cb->( PUT "$contrascheme:$abs_uri" );
		is $res->code, 400, '... but not any other request method';

		$res = $cb->( GET "$coscheme:$abs_uri" );
		is $res->code, 204, "... whereas \U$coscheme\E requests proceed normally";

		$res = $cb->( PUT "$coscheme:$abs_uri" );
		is $res->code, 204, '... with any request method';

		$res = $cb->( GET 'https://localhost/' );
		my $hsts = $res->header( 'Strict-Transport-Security' );
		$do_ssl
			? ok  $hsts, '... and a given HSTS policy returned in SSL responses'
			: ok !$hsts, '... and no HSTS policy, neither in SSL responses';

		$res = $cb->( GET 'http://localhost/' );
		ok !$res->header( 'Strict-Transport-Security' ), $do_ssl
			? '... but not in plaintext responses'
			: '... nor in plaintext responses';
	}

	$mw->ssl( undef );
	$mw->prepare_app;
	my $hsts_age = Plack::Middleware::RedirectSSL::DEFAULT_STS_MAXAGE;

	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age, 'HSTS is enabled by default';

	$mw->hsts( $hsts_age = 60 * 60 );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age, '... but can be changed';

	$mw->hsts( $hsts_age = 0 );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age, '... and also set to zero';

	$mw->hsts( '' );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), undef, '... or completely disabled';

	$mw->hsts( $hsts_age = 31536000 );

	$mw->hsts_include_sub_domains( 1 );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age.'; includeSubDomains', 'HSTS includeSubDomains can be enabled';

	$mw->hsts_include_sub_domains( 0 );
	$mw->hsts_preload( 1 );
	my $warning;
	{
		local $SIG{__WARN__} = sub { $warning = shift };
		$res = $cb->( GET 'https://localhost/' );
	}
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age.'; preload', 'HSTS preload can be enabled';
	like $warning => qr/ requires .+ includeSubDomains /x, "... but warns that includeSubDomains is required";

	$mw->hsts_include_sub_domains( 1 );
	$mw->hsts_preload( 1 );
	$res = $cb->( GET 'https://localhost/' );
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age.'; includeSubDomains; preload', 'HSTS includeSubDomains and preload can be enabled together';

	$mw->hsts( $hsts_age = 31536000 - 1 );
	$warning = undef;
	{
		local $SIG{__WARN__} = sub { $warning = shift };
		$res = $cb->( GET 'https://localhost/' );
	}
	is $res->header( 'Strict-Transport-Security' ), 'max-age='.$hsts_age.'; includeSubDomains; preload', 'HSTS header is as configured lower than 31536000';
	like $warning => qr/ 31536000 /x, "... but warns that that max_age must be 1 year or more";
};
