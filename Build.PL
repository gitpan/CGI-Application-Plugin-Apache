#!/usr/bin/perl -w
use Module::Build;
my $build_pkg = eval { require Apache::TestMB }
      ? 'Apache::TestMB' : 'Module::Build';

my $build = $build_pkg->new(
	module_name         => 'CGI::Application::Plugin::Apache',
	license             => 'perl',
	requires            => {
		    'CGI::Application'  => 3.22,
		    'Exporter'          => 0,
#            'Apache'            => 0,
            'Test::More'        => 0,
            'Apache::Request'   => 0,
            'Apache::Cookie'    => 0,
#            'Apache::Constants' => 0,
            'Apache::URI'       => 0,
            'HTML::GenerateUtil'=> 0,
		    },
    build_requires      => {
            'CGI::Cookie'       => 0,
            
            },
	create_makefile_pl  => 'passthrough',
	create_readme       => 1,
	);
$build->create_build_script();
