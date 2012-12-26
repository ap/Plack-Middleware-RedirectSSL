use strict;
no warnings;
use Plack::Test;
use Plack::Builder;
use Test::More;
use HTTP::Request::Common;

my $app = sub { return [ 204, [qw( Content-Type text/plain )], [ '' ] ] };

for my $do_ssl ( 1, 0 ) {
	test_psgi app => builder { enable 'RedirectSSL', ssl => $do_ssl; $app }, client => sub {
		my $cb = shift;
		my $res;

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
	};
}

test_psgi app => builder { enable 'RedirectSSL'; $app }, client => sub {
	my $cb = shift;
	my $res;

	$res = $cb->( GET 'http://localhost/' );
	is $res->code, 301, 'The default is to redirect to HTTPS';

	$res = $cb->( GET 'https://localhost/' );
	is $res->code, 204, '... and not vice versa';
};

done_testing;
