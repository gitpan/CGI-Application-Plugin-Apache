package ApachePlugin::MP;
use base 'CGI::Application';
use strict;
use warnings;
use Apache::Reload;
use CGI::Cookie;
use CGI::Application::Plugin::Apache qw(:all);
use Apache::Cookie;

my $content = "<h1>HELLO THERE</h1>";

sub setup {
    my $self = shift;
    $self->start_mode('header');
    $self->run_modes([qw(
        query_obj
        header
        redirect
        redirected_to
        redirect_cookie
        add_header
        cgi_cookie
        apache_cookie
        baking_apache_cookie
        cgi_and_apache_cookies
        cgi_and_baked_cookies
        cookies
    )]);
}

sub query_obj {
    my $self = shift;
    return $content
        . "<h3>Im in runmode query_obj</h3>"
        . "obj is " . ref($self->query);
}

sub header {
    my $self = shift;
    $self->header_type('header');
    return $content
        . "<h3>Im in runmode header</h3>";
}

sub redirect {
    my $self = shift;
    $self->header_type('redirect');
    $self->header_props(
        -uri => '/mp?rm=redirected_to',
    );
    return $content
        . "<h3>Im in runmode redirect (should never see me)</h3>";
}

sub redirected_to {
    my $self = shift;
    $self->header_type('header');
    my %cookies = Apache::Cookie->fetch();
    if($cookies{redirect_cookie}) {
        my $value = $cookies{redirect_cookie}->value;
        $content .= " cookie value = '$value'";
    }
    return $content
        . "<h3>Im in runmode redirect2</h3>";
}

sub redirect_cookie {
    my $self = shift;
    $self->header_type('redirect');
    $self->header_props(
        -uri => '/mp?rm=redirected_to',
    );
    my $cookie = Apache::Cookie->new(
        $self->query,
        -name    => 'redirect_cookie',
        -value   => 'mmmm',
    );
    $cookie->bake;
    return $content 
        . "<h3>Im in runmode redirect_cookie</h3>";
}

sub add_header {
    my $self = shift;
    $self->header_type('header');
    $self->header_add(
        -me => 'Myself and I', 
    );
    return $content
        . "<h3>Im in runmode add_header</h3>";
}

sub cgi_cookie {
    my $self = shift;
    $self->header_type('header');
    my $cookie = CGI::Cookie->new(
        -name    => 'cgi_cookie',
        -value   => 'yum',
    );
    $self->header_add(
        -cookie => $cookie,
    );
    return $content
        . "<h3>Im in runmode cgi_cookie</h3>";
}

sub apache_cookie {
    my $self = shift;
    $self->header_type('header');
    my $cookie = Apache::Cookie->new(
        $self->query,
        -name    => 'apache_cookie',
        -value   => 'yummier',
    );
    $self->header_add(
        -cookie => $cookie,
    );
    return $content
        . "<h3>Im in runmode apache_cookie</h3>";
}

sub baking_apache_cookie {
    my $self = shift;
    $self->header_type('header');
    my $cookie = Apache::Cookie->new(
        $self->query,
        -name    => 'baked_cookie',
        -value   => 'yummiest',
    );
    $cookie->bake;
    return $content
        . "<h3>Im in runmode baking_apache_cookie</h3>";
}

sub cgi_and_apache_cookies {
    my $self = shift;
    $self->header_type('header');
    my $cookie1 = CGI::Cookie->new(
        -name    => 'cgi_cookie',
        -value   => 'yum:both',
    );
    my $cookie2 = Apache::Cookie->new(
        $self->query,
        -name    => 'apache_cookie',
        -value   => 'yummier:both',
    );
    $self->header_props(
        -cookie => [$cookie2, $cookie1],
    );
    return $content
        . "<h3>Im in runmode cgi_and_apache_cookies</h3>";
}

sub cgi_and_baked_cookies {
    my $self = shift;
    $self->header_type('header');
    my $cookie1 = CGI::Cookie->new(
        -name    => 'cgi_cookie',
        -value   => 'yum:both',
    );
    my $cookie2 = Apache::Cookie->new(
        $self->query,
        -name    => 'baked_cookie',
        -value   => 'yummiest:both',
    );
    $self->header_props(
        -cookie => $cookie1,
    );
    $cookie2->bake;
    return $content
        . "<h3>Im in runmode cgi_and_baked_cookies</h3>";
}

sub cookies {
    my $self = shift;
    $self->header_type('header');
    my $cookie1 = CGI::Cookie->new(
        -name    => 'cookie1',
        -value   => 'mmmm',
    );
    my $cookie2 = CGI::Cookie->new(
        -name    => 'cookie2',
        -value   => 'tasty',
    );
    $self->header_props( -cookie => [ $cookie1, $cookie2 ]);
    return $content
        . "<h3>Im in runmode cookies</h3>";
}

1;

