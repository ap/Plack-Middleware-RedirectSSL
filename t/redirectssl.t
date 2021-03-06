use strict; use warnings;

use Plack::Test;
use Plack::Builder;
use Test::More tests => 19;
use HTTP::Request::Common;
use Plack::Middleware::RedirectSSL ();

my $app = sub { [ 204, [], [] ] };
my $mw = Plack::Middleware::RedirectSSL->new( app => $app );

test_psgi app => $mw->to_app, client => sub {
	my $cb = shift;
	my $res;

	$res = $cb->( GET 'http://localhost/' );
	is $res->code, 301, 'The default is to redirect HTTP to HTTPS';

	$res = $cb->( GET 'https://localhost/' );
	is $res->code, 204, '... and not vice versa';

	is +Plack::Middleware::RedirectSSL->new( app => $app, ssl => 0 )->ssl, 0, '... unless overridden during construction';

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
};
