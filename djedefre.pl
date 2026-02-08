#!/usr/bin/perl
#INSTALL@ /opt/djedefre/djedefre
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
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
use FindBin;
use lib $FindBin::Bin;
use List::MoreUtils qw(first_index);
require config;
require connections;
require cloud;
require dje_db;
#require ifconnect;
require l2input;
require switchinput;
require l3drawing;
require l2drawing;
require listings;
require logopage;
require managepages;
require multilist;
require nwdrawing;
require options;
require overview;
require selector;
require standard;
require put_inobj;

our $dbfile;

our %config;
our @colors;
our @devicetypes;
@colors =    qw/Black  DarkGreen Blue   SlateBlue4 tan4 cyan4   firebrick4 Orange Green NavyBlue lightgrey red gray Yellow Cyan Magenta White Brown DarkSeaGreen DarkViolet/;
@devicetypes=qw/server nas      network    pc     phone printer tablet appliance/;
$config{'topdir'}='.';
$config{'image_directory'}="$config{'topdir'}/images";	 		# image-files. like logo's
$config{'scan_directory'} ="$config{'topdir'}/scan_scripts";		# Scan scripts for networ discovery and status
$config{'dbfile'}="$config{'topdir'}/djedefre/djedefre.db";		# Database file where the network is stored
my $canvas_xsize=1500;					# default x-size of the network drawning; configurable
my $canvas_ysize=1200;					# default y-size of the network drawning; configurable
our $Message;
$Message='';
our $locked;
$locked=0;
our $repeat_sub;
my $last_message='Welcome';

our $main_window;
our $main_window_height;
$main_window_height=500;
our $main_window_width;
$main_window_width=500;
our $main_frame;
our $button_frame;

our $showlabels=1;

our $drawingname='none';


our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;
$DEB_FRAME=1;
$DEB_DB=2;
$DEB_SUB=4;
$DEBUG=$DEB_DB;

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

our $repeat_sub;
$repeat_sub=\&norepeat;

my $inputselectframe;
my $selected_input='Input';

sub do_selected_input {
	debug($DEB_SUB,"do_selected_input");
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	$repeat_sub=\&norepeat;
	if ($selected_input eq 'Pages'){ manage_pages(); }
	#elsif ($selected_input eq 'Layer2'){ l2input(); }
	#elsif ($selected_input eq 'Interfaces'){ ifconnect(); }
	elsif ($selected_input eq 'Colors'){ options_window(); }
	elsif ($selected_input eq 'Cloud'){ cloud_input(); }
	elsif ($selected_input eq 'Switch'){ switch_input(); }
	elsif ($selected_input eq 'Connections'){ connections_input(); }
	$selected_input='Input';
	
}

sub make_inputselectframe{
	(my $parent)=@_;
	$inputselectframe->destroy if Tk::Exists( $inputselectframe);
	$inputselectframe=$parent->Frame()->pack(-side=>'right');
	my @options=qw/Input Pages Switch Cloud Colors Connections/;
	$inputselectframe->Optionmenu(
		-variable       => \$selected_input,
		-width          => 15,
		-options        => \@options,
		-command        => sub { do_selected_input();}
	)->pack();
}
	

#  __  __       _       
# |  \/  | __ _(_)_ __  
# | |\/| |/ _` | | '_ \ 
# | |  | | (_| | | | | |
# |_|  |_|\__,_|_|_| |_|
#   


connect_db($config{'dbfile'});

query_changed_no();
options_read();

fill_pagelist();
#
#	Main Window
#
$main_window = MainWindow->new();
$main_window->FullScreen;
nw_read_logos($main_window,"$config{'image_directory'}");
my $msgcolor='black';
$main_window->Label(-textvariable=>\$Message, -width=>1500, -foreground=>'red',-font=>"arial 14")->pack(-side=>'top');
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

my $button_frame_local=$button_frame->Frame()->pack(-side=>'left');
make_overviewselectframe($button_frame_local);
my $button_frame_local=$button_frame->Frame()->pack(-side=>'left');
make_pageselectframe($button_frame_local);
$button_frame_local=$button_frame->Frame()->pack(-side=>'left');
make_listingselectframe($button_frame_local);
my $button_frame_local=$button_frame->Frame()->pack(-side=>'left');
make_inputselectframe($button_frame_local);


my $image = $main_frame->Photo(-file => "$config{'image_directory'}/djedefre.gif");
logoframe($main_frame);


sub repeat {
	if ($locked==0){
		$main_window->after(300,\&repeat);
		$main_window_height=$main_window->height;
		$main_window_width=$main_window->width;
		&$repeat_sub;
	}
}
$main_window->after(300,\&repeat);

MainLoop;
