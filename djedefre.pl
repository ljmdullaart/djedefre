#!/usr/bin/perl
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
#INSTALL@ /opt/djedefre/djedefre
use strict;

use Tk;
use Tk::PNG;
use Tk::Photo;
use Image::Magick;
use Tk::JBrowseEntry;
use Tk::Pane;
use Data::Dumper;
use DBI;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;
use Module::Refresh;

use FindBin;
use lib $FindBin::Bin;
use List::MoreUtils qw(first_index);
require config;
require cloud;
require dje_db;
require l2input;
require l3drawing;
require listings;
require logopage;
require managepages;
require multilist;
require nwdrawing;
require options;
require selector;
require standard;

our %config;
our @colors =    qw/Black  DarkGreen Blue   SlateBlue4 tan4 cyan4   firebrick4 Orange Green NavyBlue lightgrey red gray Yellow Cyan Magenta White Brown DarkSeaGreen DarkViolet/;
our @devicetypes=qw/server nas      network    pc     phone printer tablet/;
$config{'topdir'}='.';
$config{'image_directory'}="$config{'topdir'}/images";	 		# image-files. like logo's
$config{'scan_directory'} ="$config{'topdir'}/scan_scripts";		# Scan scripts for networ discovery and status
$config{'dbfile'}="$config{'topdir'}/djedefre/djedefre.db";		# Database file where the network is stored
my $canvas_xsize=1500;					# default x-size of the network drawning; configurable
my $canvas_ysize=1200;					# default y-size of the network drawning; configurable
our $Message='';
our $locked=0;
my $last_message='Welcome';

our $main_window;
our $main_window_height=500;
our $main_window_width=500;
our $main_frame;
our $button_frame;




my $DEB_FRAME=1;
my $DEB_DB=2;
my $DEBUG=0;

sub debug {
	(my $level, my $message)=@_;
	if (($level & $DEBUG) > 0){
		print "$level	$message\n";
	}
}

my $ConfigFileSpec;
config_get();

sub norepeat {
	# do noting
}

our $repeat_sub=\&norepeat;

#  __  __       _       
# |  \/  | __ _(_)_ __  
# | |\/| |/ _` | | '_ \ 
# | |  | | (_| | | | | |
# |_|  |_|\__,_|_|_| |_|
#   


connect_db($config{'dbfile'});

db_dosql("SELECT value FROM config WHERE attribute='run:param' AND item='changed'");
if ((my $val)=db_getrow()){
	db_dosql("UPDATE config SET value='no' WHERE attribute='run:param' AND item='changed'");
}
else{
	db_dosql("INSERT INTO config (attribute,item,value) values('run:param','changed','no')");
}

options_read();

fill_pagelist();
#
#	Main Window
#
$main_window = MainWindow->new(
);
$main_window->FullScreen;
nw_read_logos($main_window,"$config{'image_directory'}");
$main_window->Label(-textvariable=>\$Message, -width=>1500)->pack(-side=>'top');
debug ($DEB_FRAME,"19 Create button_frame");
$button_frame=$main_window->Frame(
	-height      => 0.05*$main_window_height,
	-width       => $main_window_width
)->pack(-side=>'top');
debug ($DEB_FRAME,"20 Create main_frame");
$main_frame=$main_window->Frame(
	-height      => 0.95*$main_window_height,
	-width       => $main_window_width
)->pack(-side =>'top');
$button_frame->Button(-text => "Listings",-width=>20, -command =>sub {
	$Message='';
	$repeat_sub=\&norepeat;
	make_listing($main_frame);
})->pack(-side=>'left');
$button_frame->Button(-text => "Manage pages",-width=>20, -command =>sub {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"21 Create main_frame");
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
	$repeat_sub=\&norepeat;
	manage_pages()
})->pack(-side=>'left');
$button_frame->Button(-text => "Layer 2 input",-width=>20, -command =>sub {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
	$repeat_sub=\&norepeat;
	l2input()
})->pack(-side=>'left');
$button_frame->Button(-text => "Cloud input",-width=>20, -command =>sub {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
	$repeat_sub=\&norepeat;
	cloud_input()
})->pack(-side=>'left');
$button_frame->Button(-text => "Options",-width=>20, -command =>sub {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
	$repeat_sub=\&norepeat;
	options_window()
})->pack(-side=>'left');
my $button_frame_pgsel=$button_frame->Frame()->pack(-side=>'right');
make_pageselectframe($button_frame_pgsel);


my $image = $main_frame->Photo(-file => "$config{'image_directory'}/djedefre.gif");
logoframe();


sub repeat {
	if ($locked==0){
		$main_window->after(60000,\&repeat);
		$main_window_height=$main_window->height;
		$main_window_width=$main_window->width;
		&$repeat_sub;
	}
}
$main_window->after(60000,\&repeat);

MainLoop;
