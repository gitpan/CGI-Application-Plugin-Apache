package ApachePlugin::Test;
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
    $self->run_modes(
        header                  => 'header',
        redirect                => 'redirect',
        redirect2               => 'redirect2',
        add_header              => 'add_header',
        cgi_cookie              => 'cgi_cookie',
        apache_cookie           => 'apache_cookie',
        baking_apache_cookie    => 'baking_apache_cookie',
        cgi_and_apache_cookies  => 'cgi_and_apache_cookies',
        cgi_and_baked_cookies   => 'cgi_and_baked_cookies',
    );
}

sub header {
    my $self = shift;
    $self->header_type('header');
    return "<h1>HELLO THERE</h1>"
        . "<h3>Im in runmode header</h3>";
}

sub redirect {
    my $self = shift;
    $self->header_type('redirect');
    $self->header_props(
        -uri => '/test1?rm=redirect2',
    );
    return "<h1>HELLO THERE</h1>"
        . "<h3>Im in runmode redirect (should never see me)</h3>";
}

sub redirect2 {
    my $self = shift;
    $self->header_type('header');
    return "<h1>HELLO THERE</h1>"
        . "<h3>Im in runmode redirect2</h3>";
}

sub add_header {
    my $self = shift;
    $self->header_type('header');
    $self->header_add(
        -me => 'Myself and I', 
    );
    return "<h1>HELLO THERE</h1>"
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
    return "<h1>HELLO THERE</h1>"
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
    return "<h1>HELLO THERE</h1>"
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
    return "<h1>HELLO THERE</h1>"
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
    return "<h1>HELLO THERE</h1>"
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
    return "<h1>HELLO THERE</h1>"
        . "<h3>Im in runmode cgi_and_baked_cookies</h3>";
}

1;

