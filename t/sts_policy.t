use strict; use warnings;

use Test::More tests => 18;
use Plack::Middleware::RedirectSSL ();

BEGIN { *render_policy      = \&Plack::Middleware::RedirectSSL::render_sts_policy      }
BEGIN { *DEFAULT_MAXAGE     = \&Plack::Middleware::RedirectSSL::DEFAULT_STS_MAXAGE     }

ok defined &render_policy,      'Function found';
ok defined &DEFAULT_MAXAGE,     '... as well as the STS max-age default';

my $bad = 'HSTS policy must be a single undef value or hash ref at ';
is scalar( eval { render_policy 1        }, $@ ), $bad.__FILE__.' line '.__LINE__.".\n", 'A normal scalar is rejected';
is scalar( eval { render_policy []       }, $@ ), $bad.__FILE__.' line '.__LINE__.".\n", '... as are unexpected kinds of ref';
is scalar( eval { render_policy undef, 1 }, $@ ), $bad.__FILE__.' line '.__LINE__.".\n", '... as well as too many arguments';
is scalar( eval { render_policy 1, undef }, $@ ), $bad.__FILE__.' line '.__LINE__.".\n", '... hopefully regardless of order';

is scalar( eval { Plack::Middleware::RedirectSSL->new( hsts_policy => 1 ) }, $@ ), $bad.__FILE__.' line '.__LINE__.".\n", 'Own call frames are ignored in error messages';

is scalar( eval { render_policy undef }, $@ ), '', 'An undef is accepted';
is scalar( eval { render_policy {}    }, $@ ), '', '... as is a hash';

my $unknown = q[HSTS policy contains unknown directive(s) 'unknown' at ];
is scalar( eval { render_policy { ('unknown') x 2 } }, $@ ), $unknown.__FILE__.' line '.__LINE__.".\n",, 'Unknown directives are rejected';

is render_policy( undef ), undef, 'Passing undef yields undef';
is render_policy( {} ), 'max-age='.DEFAULT_MAXAGE, '... while a hash yields the default policy';

my $conflict = 'HSTS max_age 0 conflicts with setting other directives at ';
is render_policy( { max_age => 0 } ), 'max-age=0', 'A zero max-age is possible';
is scalar( eval { render_policy { max_age => 0, include_subdomains => 1 } }, $@ ), $conflict.__FILE__.' line '.__LINE__.".\n", '... but not together with other directives';
is scalar( eval { render_policy { max_age => 0, include_subdomains => 0 } }, $@ ), '', '... except if they are turned off anyway';

is render_policy( { max_age => undef } ), 'max-age='.DEFAULT_MAXAGE, 'An undef max-age yields the default';
is render_policy( { max_age => 'a' } ), 'max-age=0', '... while a non-numeric max-age becomes 0';

render_policy my $policy = {};
is_deeply $policy, { max_age => DEFAULT_MAXAGE, include_subdomains => !1 }, 'Defaults are materialised';
