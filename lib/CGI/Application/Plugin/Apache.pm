package CGI::Application::Plugin::Apache;
use strict;
use base 'Exporter';
use Apache;
use Apache::Request;
use Apache::Reload;
use Apache::Constants qw(:common :response);
use Carp;

$CGI::Application::Plugin::Apache::VERSION = 0.09;

use vars qw(@EXPORT_OK %EXPORT_TAGS);

BEGIN {
    # only do stuff if we are running under mod_perl
    if( $ENV{MOD_PERL} ) {
        @EXPORT_OK      = qw(handler cgiapp_get_query _send_headers);
        %EXPORT_TAGS    = (all => \@EXPORT_OK);
    } else {
        @EXPORT_OK      = ();
        %EXPORT_TAGS    = (all => []);
    }
}

sub handler ($$) {
    my ($self, $r) = @_;
    $self->new()->run();
    return $r->status() || OK;
}

sub cgiapp_get_query {
    my $self = shift;
    my $apr = Apache::Request->new( Apache->request() );
    return $apr;
}

sub _send_headers {
    my $self = shift;
    my $q = $self->query();
    my $header_type = $self->header_type();
    my %props = $self->header_props();
                                                                                                                                       
    # if we are redirecting try and do it with header_out
    if ( $header_type eq 'redirect' || $header_type eq 'header' ) {
        $q->status(REDIRECT)
            if($header_type eq 'redirect');
        # if we have any header props then use our CGI compat to handle them
        if( scalar(%props) ) {
            _handle_cgi_header_props($q, %props);
        } else {
            # else use to Apache send the header
            $q->send_http_header('text/html');
        }
    } elsif( $header_type eq 'none' ) {
        # don't do anything here either...
    } else {
        # croak() if we have an unknown header type
        croak ("Invalid header_type '$header_type'");
    }
    # Don't return anything so headers aren't sent twice
    return "";
}

###################################################################
#THE FOLLOWING SUBS ARE ADAPTED FROM Lincoln Stein's CGI.pm module
###################################################################
sub _handle_cgi_header_props {
    my($q,@p) = @_;
                                                                                                                                           
    my($type,$status,$cookie,$target,$expires,$charset,$attachment,$p3p,$uri,$other) =
        _rearrange_props(
            [
                ['TYPE','CONTENT_TYPE','CONTENT-TYPE'],
                'STATUS',
                ['COOKIE','COOKIES'],
                'TARGET',
                'EXPIRES',
                'CHARSET',
                'ATTACHMENT',
                'P3P',
                'URI',
            ],
            @p
        );

    $type ||= 'text/html';
    $type .= "; charset=$charset" 
        if( $type =~ m!^text/! and $type !~ /\bcharset\b/ and $charset );

    $q->content_type($type);
    $q->status($status) if($status);
    if( $target ) {
        $q->header_out('Window-Target' => $target);
    }
    if ( $p3p ) {
        $p3p = join ' ',@$p3p if ref($p3p) eq 'ARRAY';
        $q->header_out('P3P' => qq(policyref="/w3c/p3p.xml")); 
        $q->header_out('CP' => $p3p); 
    }
    # send all the cookies -- there may be several
    if ( $cookie ) {
        my(@cookie) = ref($cookie) && ref($cookie) eq 'ARRAY' ? @{$cookie} : $cookie;
        foreach (@cookie) {
            my $cs = '';
            if( UNIVERSAL::isa($_,'CGI::Cookie') || UNIVERSAL::isa($_,'Apache::Cookie') ) {
                $cs = $_->as_string;
            } else {
                $cs = $_;
            }
            $q->headers_out->add('Set-Cookie'  => $cs);
        }
    }
    # if the user indicates an expiration time, then we need an Expires
    if( $expires ) {
        $q->header_out('Expires' => _expires($expires,'http'));
    }
    # if there's a location...this is generally done for redirects but there may be other reasons
    if( $uri ) {
        $q->header_out('Location' => $uri);
    }
    if( $attachment ) {
        $q->header_out('Content-Disposition' => qq(attachment; filename="$attachment"));
    }
    foreach my $key (keys %$other) {
        $q->header_out(ucfirst($key) => $other->{$key});
    }
    $q->send_http_header();
    return '';
}

sub _rearrange_props {
    my($order,@param) = @_;
    # map parameters into positional indices
    my ($i,%pos);
    $i = 0;
    foreach (@$order) {
        foreach (ref($_) eq 'ARRAY' ? @$_ : $_) { $pos{lc($_)} = $i; }
        $i++;
    }
                                                                                                                                           
    my (@result,%leftover);
    $#result = $#$order;  # preextend
    while (@param) {
        my $key = lc(shift(@param));
        $key =~ s/^\-//;
        if (exists $pos{$key}) {
            $result[$pos{$key}] = shift(@param);
        } else {
            $leftover{$key} = shift(@param);
        }
    }
                                                                                                                                           
    push (@result,\%leftover) if %leftover;
    return @result;
}

# This internal routine creates date strings suitable for use in
# cookies and HTTP headers.  (They differ, unfortunately.)
# Thanks to Mark Fisher for this.
sub _expires {
    my($time,$format) = @_;
    $format ||= 'http';
                                                                                                                                           
    my(@MON)=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
    my(@WDAY) = qw/Sun Mon Tue Wed Thu Fri Sat/;
                                                                                                                                           
    # pass through preformatted dates for the sake of _expire_calc()
    $time = _expire_calc($time);
    return $time unless $time =~ /^\d+$/;
                                                                                                                                           
    # make HTTP/cookie date string from GMT'ed time
    # (cookies use '-' as date separator, HTTP uses ' ')
    my($sc) = ' ';
    $sc = '-' if $format eq "cookie";
    my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime($time);
    $year += 1900;
    return sprintf("%s, %02d$sc%s$sc%04d %02d:%02d:%02d GMT",
                   $WDAY[$wday],$mday,$MON[$mon],$year,$hour,$min,$sec);
}

# This internal routine creates an expires time exactly some number of
# hours from the current time.  It incorporates modifications from
# Mark Fisher.
sub _expire_calc {
    my($time) = @_;
    my(%mult) = ('s'=>1,
                 'm'=>60,
                 'h'=>60*60,
                 'd'=>60*60*24,
                 'M'=>60*60*24*30,
                 'y'=>60*60*24*365);
    # format for time can be in any of the forms...
    # "now" -- expire immediately
    # "+180s" -- in 180 seconds
    # "+2m" -- in 2 minutes
    # "+12h" -- in 12 hours
    # "+1d"  -- in 1 day
    # "+3M"  -- in 3 months
    # "+2y"  -- in 2 years
    # "-3m"  -- 3 minutes ago(!)
    # If you don't supply one of these forms, we assume you are
    # specifying the date yourself
    my($offset);
    if (!$time || (lc($time) eq 'now')) {
        $offset = 0;
    } elsif ($time=~/^\d+/) {
        return $time;
    } elsif ($time=~/^([+-]?(?:\d+|\d*\.\d*))([mhdMy]?)/) {
        $offset = ($mult{$2} || 1)*$1;
    } else {
        return $time;
    }
    return (time+$offset);
}

sub _unescapeHTML {
    my ($string, $charset) = @_;
    return undef unless defined($string);
    my $latin = defined $charset ? $charset =~ /^(ISO-8859-1|WINDOWS-1252)$/i : 1;
    # thanks to Randal Schwartz for the correct solution to this one
    $string=~ s[&(.*?);]{
    local $_ = $1;
    /^amp$/i    ? "&" :
    /^quot$/i   ? '"' :
        /^gt$/i     ? ">" :
    /^lt$/i     ? "<" :
    /^#(\d+)$/ && $latin         ? chr($1) :
    /^#x([0-9a-f]+)$/i && $latin ? chr(hex($1)) :
    $_
    }gex;
    return $string;
}



1;

__END__

=pod

=head1 NAME

CGI::Application::Plugin::Apache - Allow CGI::Application to use Apache::* modules without interference

=head1 SYNOPSIS

    use base 'CGI::Application';
    use CGI::Application::Plugin::Apache qw(:all);
    
    # then later we join our hero in a run mode...
    sub mode1 {
        my $self = shift;
        my $q = $self->query(); # $q is an Apache::Request obj not a CGI.pm obj

        # do some stuff
        
        # now we can bake a cookie using Apache::Cookie without interference  
        $cookie = Apache::Cookie->new(
                $q,
                -name       => 'foo',
                -value      => 'bar',
                -expires    => '+2h',
        );
        $cookie->bake;

        # now let's play with the content_type and other headers
        $q->content_type('text/plain');
        $q->header_out('MyHeader' => 'MyValue');

        # do other stuff and then ...
        return $content;
    }

    1;

=head1 DESCRIPTION

This plugin helps to try and fix some of the annoyances of using L<CGI::Application> in
a pure mod_perl environment. L<CGI::Application> assumes that you use L<CGI.pm|CGI>, but I wanted
to avoid it's bloat and have access to the performance of the Apache::* modules so along
came this plugin. At the current moment it only does three things:

=over

=item 1

Provide a very simple C<< handler() >> method that will create and instance of your application
class and C<< run() >> it.

=item 2

Use Apache::Request as the C<< $self->query >> object thus avoiding the creation
of the CGI.pm object.

=item 3

Override the way L<CGI::Application> creates and prints it's HTTP headers. Since it was using
L<CGI.pm|CGI>'s C<< header() >> and C<< redirect() >> method's we needed an alternative. So now we
use the C<< Apache->send_http_header() >> method. This has a few additional benefits other
than just not using L<CGI.pm|CGI>. It means that we can use other Apache::* modules that might
also create outgoing headers (e.g. L<Apache::Cookie>) without L<CGI::Application> clobbering
them. 

And if any other headers have been added using L<CGI::Application>'s C<< header_add() >> or
C<< header_props >> methods then those are also dealt with in the proper manner so that they
will also be sent to the client.

=back

=head1 EXPORTED METHODS

This module uses L<Exporter> to provide methods to your application module. Most of the time
you will never actually use these methods since they are used by L<CGI::Application> itself,
but I figured you'd like to know what's going on.

No methods are exported by default. It is up to you to pick and choose, but please choose
wisely. You can import all of the methods by using:
    
    use CGI::Application::Plugin::Apache qw(:all);

It is recommended that you import all of them since some methods will require others. but
the choice is yours. For instance, if you want to override any method then you may not want
to import it from here.

=head2 handler()

This method gives your application the ability to run as a straight mod_perl handler. It simply
creates an instance of you application and then runs it (using C<< $app->new() >> and 
C<< $app->run() >>). It does not pass any arguments into either method. It then returns an
C<< Apache::Constants::OK >> value. If you need anything more than this, please feel free to 
not import this method and write your own. You could do it like this:

    package MyApp;
    use base 'CGI::Application';
    use CGI::Application::Plugin::Apache qw(:all !handler);

    sub handler {
        # do what every you want here
    }

=head2 cgiapp_get_query()

This overrides CGI:App's method for retrieving the query object. This is the standard way
of using something other than CGI.pm so it's no surprise that we use it here. It simply
creates and returns a new L<Apache::Request> object from C<< Apache->request >>.

=head2 _send_headers()

I didn't like the idea of exporting this private method (I'd rather think it was a 'protected'
not 'private) but right now it's the only way to control how the HTTP headers are created.
Please see L<"HTTP Headers"> for more details.

=head1  HTTP Headers

We encourage you to learn the mod_perl way of manipulating headers and cookies. It's really not
that hard we promise. But incase you're easing your way into it, we try and provide as much
backward compatibility as possible.

=head2 Cookies

HTTP cookies should now be created using L<Apache::Cookie> and it's C<< bake() >> method not with 
C<< header_add() >> or C<< header_props() >>.

You can still do this to create a cookie

    my $cookie = CGI::Cookie->new(
        -name  => 'foo',
        -value => 'bar',
    );
    $self->header_add(-cookie => $cookie);

But now we encourage you to do the following

    my $cookie = Apache::Cookie->new(
        $self->query,
        -name  => 'foo',
        -value => 'bar',
    );
    $cookie->bake();

=head2 Redirects 

You can still do this to perform an HTTP redirect

    $self->header_props( uri => $some_url);
    $self->header_type('redirect');
    return '';

But now we encourage you to do the following

    $self->query->header_out(Location => $some_url);
    $self->query->status(REDIRECT);
    return '';

But it's really up to you.

=head1 COMPATIBILITY

Upon using this module you completely leave behind the world of L<CGI.pm|CGI>. Don't look back or
you might turn into a pillar of salt. You will have to look at and read the docs of the Apache::* 
modules. But don't worry, they are really easy to use and were designed to mimic the interface
of L<CGI.pm|CGI> and family.

If you are trying to use this module but don't want to have to change your previous code that
uses C<< header_props() >> or C<< header_add() >> then we try to help you out by being as CGI
compatible as we can, but it is always better to use the mod_perl api. If you still want to use
C<< header_props() >> or C<< header_add() >> remember that it will cause a performance hit because
it will use helper routines that try and emulate L<CGI.pm|CGI>.

If you wish to write code that performs well in both environments, you can check the $ENV{MOD_PERL}
environment setting and branch accordingly. For example, to set a cookie:

  if ($ENV{MOD_PERL}) {
    require Apache::Cookie;
    $cookie = Apache::Cookie->new(
      $q,
      -name       => 'favorite',
      -value      => 'chocolate chip',
      -expires    => '+2h',
    );
    $cookie->bake;
  }
  else {
    $cookie = $self->query->cookie(
      -name    => 'favorite',
      -value   => 'chocolate chip',
      -expires => '+2h',
    );
    $webapp->header_add(-cookie => [$cookie]);
  }

If for some reason you are using this plugin in a non-mod_perl environment, it will try to 
do the right thing by simply doing nothing :)

=head1 AUTHOR
                                                                                                                                           
Michael Peters <mpeters@plusthree.com>

Thanks to Plus Three, LLC (http://www.plusthree.com) for sponsoring my work on this module

=head1 CONTRIBUTORS

The following people have contributed to this module either through docs, code, or ideas

=over

=item William McKee <william@knowmad.com>

=item Cees Hek <ceeshek@gmail.com>

=item Drew Taylor <drew@drewtaylor.com>

=item Ron Savage <ron@savage.net.au>

=back

=head1 SEE ALSO
                                                                                                                                           
=over 8
                                                                                                                                           
=item * L<CGI::Application>
                                                                                                                                           
=item * L<Apache>

=item * L<Apache::Request>

=item * L<Apache::Cookie>
                                                                                                                                           
=back
                                                                                                                                           
=head1 LICENSE
                                                                                                                                           
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
                                                                                                                                           
=cut
