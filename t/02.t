use strict;
use warnings FATAL => 'all';
use Apache::Test qw(plan ok have_lwp);
use Apache::TestRequest qw(GET);
use Apache::TestUtil qw(t_cmp);

plan( tests => 32, have_lwp() );

my $response;
my $content;

# 1..3
{
    $response = GET '/test1?rm=header';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode header/);
    ok($response->header('Content-Type') =~ /text\/html/); 
}

# 4..6
{
    $response = GET '/test1?rm=redirect';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode redirect2/);
    ok($response->header('Content-Type') =~ /text\/html/);
}

# 7..10
{
    $response = GET '/test1?rm=add_header';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode add_header/);
    ok($response->header('Content-Type') =~ /text\/html/);
    ok($response->header('Me') eq 'Myself and I');
}

# 11..14
{
    $response = GET '/test1?rm=cgi_cookie';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode cgi_cookie/);
    ok($response->header('Content-Type') =~ /text\/html/);
    ok($response->header('Set-Cookie') =~ /cgi_cookie=yum/);
}

# 15..18
{
    $response = GET '/test1?rm=apache_cookie';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode apache_cookie/);
    ok($response->header('Content-Type') =~ /text\/html/);
    ok($response->header('Set-Cookie') =~ /apache_cookie=yummier/);
}

# 19..22
{
    $response = GET '/test1?rm=baking_apache_cookie';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode baking_apache_cookie/);
    ok($response->header('Content-Type') =~ /text\/html/);
    ok($response->header('Set-Cookie') =~ /baked_cookie=yummiest/);
}

# 23..27
{
    $response = GET '/test1?rm=cgi_and_apache_cookies';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode cgi_and_apache_cookies/);
    ok($response->header('Content-Type') =~ /text\/html/);
    my @cookies = $response->header('Set-Cookie');
    ok($response->header('Set-Cookie') =~ /cgi_cookie=yum(:|%3A)both/);
    ok($response->header('Set-Cookie') =~ /apache_cookie=yummier(:|%3A)both/);
}

# 28..32
{
    $response = GET '/test1?rm=cgi_and_baked_cookies';
    ok($response->is_success);
    $content = $response->content();
    ok($content =~ /in runmode cgi_and_baked_cookies/);
    ok($response->header('Content-Type') =~ /text\/html/);
    my @cookies = $response->header('Set-Cookie');
    ok($response->header('Set-Cookie') =~ /cgi_cookie=yum(:|%3A)both/);
    ok($response->header('Set-Cookie') =~ /baked_cookie=yummiest(:|%3A)both/);
}





