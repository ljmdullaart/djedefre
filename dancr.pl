#!/usr/bin/perl
use strict;
use warnings;
use Dancer2;
use DBI;
use Dancer2::Plugin::Database;
use File::Spec;
use File::Basename;
use File::Spec;
use File::Slurper qw/ read_text /;
use Template;
use FindBin;
use lib $FindBin::Bin;
use Data::Dumper;

our %config;

require "dje_db.pm";
require "common_functions.pm";
require "drawing.pm";
use api_routes;

 
set 'dbfile'       => "database/djedefre.db";
set 'database'     => File::Spec->catfile(File::Spec->tmpdir(), 'dancr.db');
set 'session'      => 'Simple';
set 'template'     => 'template_toolkit';
set 'logger'       => 'console';
set 'log'          => 'debug';
set 'show_errors'  => 1;
set 'startup_info' => 1;
set 'username'     => 'admin';
set 'password'     => 'password';
set 'layout'       => 'main';
set 'images'       => 'images';


$config{'topdir'}='.';
$config{'image_directory'}="$config{'topdir'}/images";                  # image-files. like logo's
$config{'scan_directory'} ="$config{'topdir'}/scan_scripts";            # Scan scripts for networ discovery and status
$config{'dbfile'}="$config{'topdir'}/database/djedefre.db";             # Database file where the network is stored
 
sub set_flash {
	my $message = shift;
 
	session flash => $message;
}
 
sub get_flash {
	my $msg = session('flash');
	session->delete('flash');
 
	return $msg;
}
 
hook before_template_render => sub {
	my $tokens = shift;
 
	$tokens->{'css_url'}    = request->base . '/css/style.css';
	$tokens->{'login_url'}  = uri_for('/login');
	$tokens->{'logout_url'} = uri_for('/logout');
	$tokens->{'top_url'} = uri_for('/');
};
 
get '/' => sub {
	set_flash('');
	template 'show_entries.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};

get '/cloudlist' => sub {
	set_flash('');
	template 'cloudlist.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};

get '/nfslist' => sub {
	set_flash('');
	template 'nfslist.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};

get '/interfacelist' => sub {
	set_flash('');
	template 'interfacelist.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};
get '/subnetlist' => sub {
	set_flash('');
	template 'subnetlist.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};
get '/serverlist' => sub {
	set_flash('');
	template 'serverlist.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};
get '/status' => sub {
	set_flash('');
	template 'status.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};

get '/tutorial' => sub {
	set_flash('');
	template 'tutorial.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};

get '/nwdrawing' => sub {
	set_flash('');
	template 'nwdrawing' => {
		title => 'Netwerk Tekening',
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};



get '/nwdrawing/:param' => sub {
	set_flash('');
	my $param=route_parameters->get('param');
	set_flash($param);
	template 'nwdrawing.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
		drawing       => $param,
	};
};

get '/test' => sub {
	set_flash('test');
	template 'test.tt', {
		msg           => get_flash(),
		uri_top       => uri_for('/'),
	};
};

start;

