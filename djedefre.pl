#!/usr/bin/perl
use strict;

use Tk;
use Tk::PNG;
use Tk::Photo;
use Image::Magick;
use Tk::JBrowseEntry;
use Data::Dumper;
use DBI;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;

use FindBin;
use lib $FindBin::Bin;
require multilist;
require selector;
require nwdrawing;
require standard;

my $topdir='.';						# Top directory; base for finding files
my $image_directory="$topdir/images";	 		# image-files. like logo's
my $scan_directory ="$topdir/scan_scripts";		# Scab scripts for networ discovery and status
my $dbfile="$topdir/database/djedefre.db";		# Database file where the network is stored
my $configfilename="djedefre.conf";			# File for configuration options
my $canvas_xsize=1500;					# default x-size of the network drawning; configurable
my $canvas_ysize=1200;					# default y-size of the network drawning; configurable
my @subnets;
my $dragid=0;
my $dragindex=0;
my $Message='';
my $last_message='Welcome';
my $page='none';						# name of the page to display
my $nw_tmpx=100;
my $nw_tmpy=100;

my $main_window;
my $main_window_height=500;
my $main_window_width=500;
my $main_frame;
my $subframe;
my $button_frame;

my $managepg_pagename;

my $DEB_FRAME=1;
my $DEBUG=1;

sub debug {
	(my $level, my $message)=@_;
	if (($level & $DEBUG) > 0){
		print "$level	$message\n";
	}
}

my $ConfigFileSpec;

sub nxttmploc {
	$nw_tmpx=$nw_tmpx+100;
	if ($nw_tmpx > ($canvas_xsize-200)){
		$nw_tmpy=$nw_tmpy+100;
		$nw_tmpx=100;
	}
}

#      _       _	_
#   __| | __ _| |_ __ _| |__   __ _ ___  ___
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
#

my $db;

sub connect_db {
	$db = DBI->connect("dbi:SQLite:dbname=".$dbfile)
		or die $DBI::errstr;
	return $db;
}

sub dosql{
	(my $statement)=@_;
        my $sql = $statement;
        my $sth = $db->prepare($sql);
        $sth->execute();
	return $sth;
}

#  _			     _____ 
# | | __ _ _   _  ___ _ __  |___ / 
# | |/ _` | | | |/ _ \ '__|   |_ \ 
# | | (_| | |_| |  __/ |     ___) |
# |_|\__,_|\__, |\___|_|    |____/ 
#	    |___/		   
#	     _		             _
#  _ __   ___| |___      _____  _ __| | __
# | '_ \ / _ \ __\ \ /\ / / _ \| '__| |/ /
# | | | |  __/ |_ \ V  V / (_) | |  |   <
# |_| |_|\___|\__| \_/\_/ \___/|_|  |_|\_\
#
#      _		    _
#   __| |_ __ __ ___      _(_)_ __   __ _
#  / _` | '__/ _` \ \ /\ / / | '_ \ / _` |
# | (_| | | | (_| |\ V  V /| | | | | (_| |
#  \__,_|_|  \__,_| \_/\_/ |_|_| |_|\__, |
#                                    |__/

my @l3_obj;
my $l3_showpage='top';

sub l3_objects {
	splice @l3_obj;
	my $sql;
	if ($l3_showpage eq 'top'){
		$sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name FROM subnet';
	}
	else {
		$sql="	SELECT subnet.id,nwaddress,cidr,pages.xcoord,pages.ycoord,name
			FROM   subnet
			INNER JOIN pages ON pages.item = subnet.id
			WHERE  pages.page='$l3_showpage' AND pages.tbl='subnet'
		";
	}
	my $sth = dosql($sql);
	while((my $id,my $nwaddress, my $cidr,my $x,my $y,my $name) = $sth->fetchrow()){
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y
		}
		$name="$nwaddress/$cidr" unless defined $name;
		push @l3_obj, {
			newid	=> $id*2,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> 'subnet',
			name	=> $name,
			nwaddress=> $nwaddress,
			cidr	=> $cidr,
			table	=> 'subnet'
		}
	}
		
		
	if ($l3_showpage eq 'top'){
		$sql = 'SELECT id,name,xcoord,ycoord,type,interfaces,status,options,ostype,os,processor,memory FROM server';
	}
	else {
		$sql="	SELECT  server.id,name,pages.xcoord,pages.ycoord,type,interfaces,status,options,ostype,os,processor,memory
			FROM   server
			INNER JOIN pages ON pages.item = server.id
			WHERE  pages.page='$l3_showpage' AND pages.tbl='server'
		";
	}
	my $sth = dosql($sql);
	while((my $id,my $name, my $x,my $y,my $type,my $interfaces,my $status,my $options,my $ostype,my $os,my $processor,my $memory) = $sth->fetchrow()){
		$type='server' unless defined $type;
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y;
		}
		$name='' unless defined $name;
		push @l3_obj, {
			newid	=> $id*2+1,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> $type,
			name	=> $name,
			table	=> 'server',
			status	=> $status,
			options	=> $options,
			ostype	=> $ostype,
			os	=> $os,
			processor => $processor,
			memory	=> $memory
		};
		my $max=$#l3_obj;
		push @{$l3_obj[$max]{pages}},' ';
		
	}
	

	for my $i (0 .. $#l3_obj){
		# Separate to prevent database locks
		my $id=$l3_obj[$i]->{'id'};
		my $table=$l3_obj[$i]->{'table'};
		if ($table eq 'server'){
			my $sql = "SELECT ip FROM interfaces WHERE host=$id";
			my $sth = dosql($sql);
			while((my $ip) = $sth->fetchrow()){
				push @{$l3_obj[$i]{interfaces}}, $ip;
			}
			splice @{$l3_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='server' AND item=$id";
			my $sth = dosql($sql);
			while ((my $item) = $sth->fetchrow()){
				push @{$l3_obj[$i]{pages}}, $item
			}
			
		}
		elsif($table eq 'subnet'){
			push @{$l3_obj[$i]{pages}},' ';
			splice @{$l3_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='subnet' AND item=$id";
			my $sth = dosql($sql);
			while ((my $item) = $sth->fetchrow()){
				push @{$l3_obj[$i]{pages}}, $item
			}
		}
	}
}

my @l3_line;
sub l3_lines {
	my @interfacelist;
	splice @l3_line;
	for my $i ( 0 .. $#l3_obj){
		if ($l3_obj[$i]->{'table'} ne 'subnet'){
			my $orig_id=$l3_obj[$i]->{'id'};
			my $obj_id=$l3_obj[$i]->{'newid'};
			splice my @interfacelist;
			my $sql = "SELECT ip FROM interfaces WHERE host='$orig_id'";
			my $sth = dosql($sql);
			while((my $ip) = $sth->fetchrow()){
				push @interfacelist,$ip;
			}
			for my $j ( 0 .. $#l3_obj){
				if ($l3_obj[$j]->{'table'} eq 'subnet'){
					my $netw_id=$l3_obj[$j]->{'newid'};
					my $netw=$l3_obj[$j]->{'nwaddress'};
					my $cidr=$l3_obj[$j]->{'cidr'};
					for (@interfacelist){
						if (($_ eq 'Internet') && ($l3_obj[$j]->{'nwaddress'} eq 'Internet')){
							push @l3_line, {
								from	=> $netw_id,
								to	=> $obj_id,
								type	=> 1
							};
						}
						elsif (ipisinsubnet($_,"$netw/$cidr")==1){
							push @l3_line, {
								from	=> $netw_id,
								to	=> $obj_id,
								type	=> 1
							};
						}
					}
				}
			}
			my $options=$l3_obj[$i]->{'options'};
			if ($options=~/vboxhost:([0-9]*),/ ){
				my $hostid=$1;
				my $host=$hostid*2+1;
				for my $j ( 0 .. $#l3_obj){
					if (($hostid == $l3_obj[$j]->{'id'}) && ($l3_obj[$j]->{'table'} eq 'server')){
						push @l3_line, {
							from	=> $obj_id,
							to	=> $host,
							type	=> 2
						}
					}
				}
			}
		}
	}
}
					
my $l3_plot_frame;

sub l3_renew_content {
	l3_objects('top');
	l3_lines();
	nw_del_objects(@l3_obj);
	nw_del_lines(@l3_line);
	nw_objects(@l3_obj);
	nw_lines(@l3_line);
}
sub make_l3_plot {
	(my $parent)=@_;
	$l3_plot_frame->destroy if Tk::Exists($l3_plot_frame);
	debug ($DEB_FRAME,"1 Create l3_plot_frame");
	$l3_plot_frame=$parent->Frame()->pack(-side=>'left');
	l3_renew_content();
	nw_frame($l3_plot_frame);
	nw_callback ('move',\&l3_move);
	nw_callback ('name',\&l3_name);
	nw_callback ('type',\&l3_type);
	nw_callback ('delete',\&l3_delete);
	nw_callback ('merge',\&l3_merge);
	nw_callback ('page',\&l3_page);
	#nw_drawall();
}
sub cbdump {
	print "----Djedefre2-callback-dumper-----\n";
	print Dumper @_;
	print "----------------------------------\n";
}
sub l3_page {
	(my $table,my $id,my $name,my $action,my $page)=@_;
	my $arg="$table:$id:$name";
	$managepg_pagename=$page;
	mgpg_selector_callback ($action,$arg);
	l3_renew_content();
}

sub l3_type {
	(my $table, my $id, my $type)=@_;
	if ($table eq 'server'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		dosql("UPDATE $table SET type='$type' WHERE id=$id");
	}
	l3_renew_content();
}
sub l3_name {
	(my $table, my $id, my $name)=@_;
	my $sql = "UPDATE $table SET name='$name' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
	l3_renew_content();
}
sub l3_delete {
	(my $table, my $id, my $name)=@_;
	my $sql = "DELETE FROM $table WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
	l3_renew_content();
}
sub l3_move {
	(my $table, my $id, my $x, my $y)=@_;
	my $sql;
	if ( $l3_showpage eq 'top'){
		$sql = "UPDATE $table SET xcoord=$x WHERE id=$id"; dosql($sql);
		$sql = "UPDATE $table SET ycoord=$y WHERE id=$id"; dosql($sql);
	}
	else {
		$sql = "UPDATE pages SET xcoord=$x WHERE item=$id AND tbl='$table' AND page='$l3_showpage'"; dosql($sql);
		$sql = "UPDATE pages SET ycoord=$y WHERE item=$id AND tbl='$table' AND page='$l3_showpage'"; dosql($sql);
	}
}

sub l3_merge {
	(my $table, my $id, my $name, my $target)=@_;
	if ($table eq "server"){
		my $targetid=$id;
		if ($target =~/^(\d+\.\d+\.\d+\.\d+)/){
			my $sql = "SELECT host FROM interfaces WHERE ip='$1'";
			my $sth = $db->prepare($sql);
			$sth->execute();
			while((my $host) = $sth->fetchrow()){
				$targetid=$host;
			}
		}
		elsif ($target=~/^([A-Za-z]\w*)/){
			my $sql = "SELECT id FROM server WHERE name='$1'";
			my $sth = $db->prepare($sql);
			$sth->execute();
			while((my $host) = $sth->fetchrow()){
				$targetid=$host;
			}
		}
		if ($targetid == $id){
			$Message="No valid target for merge\n";
		}
		else {
			my $sql = "SELECT id FROM interfaces WHERE host=$id";
			my $sth=dosql($sql);
			my @iflist;
			splice @iflist;
			while((my $ifid) = $sth->fetchrow()){
				push @iflist,$ifid;
			}
			foreach(@iflist){
				my $sql = "UPDATE interfaces SET host=$targetid WHERE id=$_";
				dosql($sql);
			}
			dosql("DELETE FROM server WHERE id=$id");
			dosql("DELETE FROM pages  WHERE item=$id AND tbl='server'");
		}
	}
	l3_renew_content();
}
		
		

#  _ _     _   _                 
# | (_)___| |_(_)_ __   __ _ ___ 
# | | / __| __| | '_ \ / _` / __|
# | | \__ \ |_| | | | | (_| \__ \
# |_|_|___/\__|_|_| |_|\__, |___/
#                      |___/ 

my $listing_frame;
my $listing_button_frame;
my $listing_listing_frame;
sub make_listing {
	(my $parent)=@_;
	$listing_frame->destroy if Tk::Exists($listing_frame);
	debug ($DEB_FRAME,"2 Create listing_frame");
	$listing_frame=$parent->Frame()->pack(-side=>'left');
	debug ($DEB_FRAME,"3 Create listing_button_frame");
	$listing_button_frame=$listing_frame->Frame(
		-height      => 0.1*$main_window_height,
		-width       => $main_window_width
	)->pack(-side=>'top');
	debug ($DEB_FRAME,"4 Create listing_listing_frame");
	$listing_listing_frame=$listing_frame->Frame(
		-height      => $main_window_height-200,
		-width       => $main_window_width
	)->pack(-side=>'top');

	$listing_button_frame->Button(-text => "Servers",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		debug ($DEB_FRAME,"5 Create listing_listing_frame");
		$listing_listing_frame=$listing_frame->Frame(
			-height      => $main_window_height-200,
			-width       => $main_window_width
		)->pack(-side =>'bottom');
		listing_servers($listing_listing_frame);
	})->pack(-side=>'left');
	$listing_button_frame->Button(-text => "Subnets",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		debug ($DEB_FRAME,"6 Create listing_listing_frame");
		$listing_listing_frame=$listing_frame->Frame(
			-height      => $main_window_height-200,
			-width       => $main_window_width
		)->pack(-side =>'bottom');
		listing_subnets($listing_listing_frame);
	})->pack(-side=>'left');
	$listing_button_frame->Button(-text => "Interfaces",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		debug ($DEB_FRAME,"7 Create listing_listing_frame");
		$listing_listing_frame=$listing_frame->Frame(
			-height      => $main_window_height-200,
			-width       => $main_window_width
		)->pack(-side =>'bottom');
		listing_interfaces($listing_listing_frame);
	})->pack(-side=>'left');
}

my $listing_server_frame;
sub listing_servers{
	(my $parent)=@_;
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	debug ($DEB_FRAME,"8 Create listing_server_frame");
	$listing_server_frame=$parent->Frame(
	)->pack();
	$listing_server_frame->Label(-text=>"Servers")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;	# $id;
	$ar[1]=20;	# $name;
	$ar[2]=20;	# $type;
	$ar[3]=20;	# $ostype;
	$ar[4]=40;	# $os;
	$ar[5]=35;	# $processor;
	$ar[6]=15;	# $memory;
	ml_colwidth(@ar);
	splice @ar;
	@ar=('ID','Name','Type','OS Type','OS','Processor','Memory');
	ml_colhead(@ar);
	ml_create();
	my $sql = 'SELECT id,name,type,ostype,os,processor,memory FROM server ORDER BY id';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $name,my $type,my $ostype,my $os,my $processor,my $memory) = $sth->fetchrow()){
		$type='server' unless defined $type;
		$ostype='' unless defined $ostype;
		$os='' unless defined $os;
		$os=~s/ADVENTERPRISE/ADVENTPR/;
		$processor='' unless defined $processor;
		$memory='' unless defined $memory;
		$ar[0]= $id;
		$ar[1]= $name;
		$ar[2]= $type;
		$ar[3]= $ostype;
		$ar[4]= $os;
		$ar[5]= $processor;
		$ar[6]= $memory;
		ml_insert(@ar);
	}
		
}

my $listing_subnet_frame;
sub listing_subnets {
	(my $parent)=@_;
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	debug ($DEB_FRAME,"9 Create listing_server_frame");
	$listing_server_frame=$parent->Frame(
	)->pack();
	$listing_server_frame->Label(-text=>"Subnets")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;	# $id;
	$ar[1]=20;	# $name;
	$ar[2]=20;	# $nwaddress;
	$ar[3]= 5;	# $cidr;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='Name';
	$ar[2]='Network';
	$ar[3]='CIDR';
	ml_colhead(@ar);
	ml_create();
	my $sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name FROM subnet ORDER BY id';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $nwaddress,my $cidr, my $x,my $y,my $name) = $sth->fetchrow()){
		$name="$nwaddress/$cidr" unless defined $name;
		$name="$nwaddress/$cidr" if ($name eq '');
		$ar[0]=$id;
		$ar[1]=$name;
		$ar[2]=$nwaddress;
		$ar[3]=$cidr;
		ml_insert(@ar);
	}
}
		
my $listing_interfaces_frame;
sub listing_interfaces {
	(my $parent)=@_;
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	debug ($DEB_FRAME,"10 Create listing_server_frame");
	$listing_server_frame=$parent->Frame(
	)->pack();
	$listing_server_frame->Label(-text=>"Interfaces")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;	# $id;
	$ar[1]=20;	# $net;
	$ar[2]=20;	# $host;
	$ar[3]=20;	# $ip;
	$ar[4]=20;	# $hostname;
	$ar[5]=20;	# $mac;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='MAC';
	$ar[2]='IP';
	$ar[3]='Name';
	$ar[4]='Net';
	$ar[5]='Host';
	ml_colhead(@ar);
	ml_create();
	my @servers=[];
	my $sql = 'SELECT id,name FROM server';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $name) = $sth->fetchrow()){
		$servers[$id]=$name;
	}
	my @subnets=[];
	my $sql = 'SELECT id,nwaddress,cidr FROM subnet';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $nwaddress,my $cidr) = $sth->fetchrow()){
		$subnets[$id]="$nwaddress/$cidr";
	}
	my $sql = 'SELECT id,macid,ip,hostname,host,subnet,access FROM interfaces ORDER BY id';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $macid,my $ip,my $hostname,my $host,my $subnet,my $access) = $sth->fetchrow()){
		my $name=$servers[$host];
		$name=$hostname unless defined $name;
		my $snet;
		if (defined $subnets[$subnet]){
			$snet=$subnets[$subnet];
		}
		else {
			$snet='';
		}
		$ar[0]=$id;
		$ar[1]=$macid;
		$ar[2]=$ip;
		$ar[3]=$name;
		$ar[4]=$snet;
		$ar[5]=$hostname;
		ml_insert(@ar);
	}
}
		
#                              
#  _ __   __ _  __ _  ___  ___ 
# | '_ \ / _` |/ _` |/ _ \/ __|
# | |_) | (_| | (_| |  __/\__ \
# | .__/ \__,_|\__, |\___||___/
# |_|          |___/    
#

our @pagelist;
our @realpagelist;
my $currentpage='none';
my $selectedpage='none';
my $selectedrealpage='none';
my $pageselectframe;
my $realpageselectframe;

sub fill_pagelist {
	splice @pagelist;
	splice @realpagelist;
	push @pagelist,'none';
	push @pagelist,'top';
        my $sql = "SELECT DISTINCT item FROM config WHERE attribute LIKE 'page:%'";
        my $sth = $db->prepare($sql);
        $sth->execute();
        while((my $p) = $sth->fetchrow()){
                push @pagelist,$p;
                push @realpagelist,$p;

        }
}

sub display_top_page {		# Top-page is L3 drawing of all servers and subnets
	$Message='';
	$l3_showpage='top';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"11 Create main_frame");
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
	make_l3_plot($main_frame);
}

sub display_other_page {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"11 Create main_frame");
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
	make_l3_plot($main_frame);
}

my $manage_pages_change_frame;
my @managepagesgrid;
my $selected_type='l3';
my @managepg_selection;
my @managepg_options;
sub manage_pages {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"12 Create main_frame for manage pages");
	$main_frame=$main_window->Frame(
		-height      => 0.8*$main_window_height,
		-width       => $main_window_width
	)->pack(-side =>'top');
	for my $i (0 .. 5){
		for my $j (0 .. 4){
			$managepagesgrid[$i][$j]=$main_frame->Frame();
		}
	}
	for my $i (0 .. 5){
		Tk::grid(@{$managepagesgrid[$i]});
	}
	my @pagetypes;
	$pagetypes[0]='l3';
	$pagetypes[1]='l2';
	my $pagename;
	$managepagesgrid[1][0]->Entry ( -width=>32,-textvariable=>\$pagename)->pack(-side=>'left');
	$managepagesgrid[1][1]->Button ( -width=>10,-text=>'Add page', -command=>sub {$Message='';manage_pages_add_action($pagename);})->pack(-side=>'left');
	make_realpageselectframe($managepagesgrid[1][2]);
	$managepagesgrid[1][3]->Label(-text=>'Select a page')->pack();
	$managepagesgrid[2][2]->JBrowseEntry(
		-variable => \$selected_type, 
		-width=>30, 
		-choices => \@pagetypes, 
		-height=>10
	)->pack();
	$managepagesgrid[2][3]->Button ( -width=>10,-text=>'Change Type', -command=>sub {
		dosql("UPDATE config SET value='$selected_type' WHERE attribute='page:type' AND item='$selectedrealpage'");
		print "UPDATE config SET value='$selected_type' WHERE attribute='page:type' AND item='$selectedrealpage'\n";
	})->pack();
	$managepagesgrid[4][3]->Button ( -width=>10,-text=>'Delete page', -command=>sub {
		$Message='';
		manage_pages_del_action($selectedrealpage);
		$selectedrealpage='none';
	})->pack(-side=>'right');
}

sub mgpg_selector_callback {
	(my $func, my $arg)=@_;
	(my $table, my $id, my $name)=split(':',$arg);
	if ($func eq 'del'){
		dosql("DELETE FROM pages WHERE tbl='$table' AND item=$id AND page='$managepg_pagename'");
	}
	elsif ($func eq 'add'){
		dosql("DELETE FROM pages WHERE tbl='$table' AND item=$id AND page='$managepg_pagename'");
		dosql("INSERT INTO pages (page,tbl,item) VALUES ('$managepg_pagename','$table',$id)");
	}
}

sub manage_pages_change_action {
	(my $pgname)=@_;
	$managepg_pagename=$pgname;
	my @servers;
	my @subnets;
	splice @servers;
	splice @managepg_options;
	my $sth=dosql("SELECT id,name FROM server");
	while((my $id,my $name) = $sth->fetchrow()){
		$servers[$id]=$name;
		push @managepg_options,"server:$id:$name";
	}
	splice @subnets;
	my $sth=dosql("SELECT id,name,nwaddress,cidr FROM subnet");
	while((my $id,my $name,my $nwaddress,my $cidr) = $sth->fetchrow()){
		$name="$nwaddress/$cidr" unless defined $name;
		$subnets[$id]=$name;
		push @managepg_options,"subnet:$id:$name";
	}
	splice @managepg_selection;
	my $sth=dosql("SELECT tbl,item FROM pages WHERE page='$pgname'");
	while((my $tbl,my $item) = $sth->fetchrow()){
		my $sname='';
		if ($tbl eq 'subnet'){
			$sname=$subnets[$item] if defined $subnets[$item];
		}
		elsif ($tbl eq 'server'){
			$sname=$servers[$item] if defined $servers[$item];
		}
		push @managepg_selection, "$tbl:$item:$sname";
	}
	my $cbfunc=\&mgpg_selector_callback;
	selector({
		options		=> \@managepg_options,
		selected	=> \@managepg_selection,
		parent		=> $manage_pages_change_frame,
		callback	=> $cbfunc
	});
		
}

sub manage_pages_del_action {
	(my $pgname)=@_;
	dosql("DELETE FROM config WHERE item='$pgname'");
	dosql("DELETE FROM pages  WHERE page='$pgname'");
	fill_pagelist();
	make_pageselectframe( $button_frame);
	manage_pages();
}


sub manage_pages_add_action {
	(my $pageadd)=@_;
	fill_pagelist();
	my $flag=0;
	for (@pagelist){ 
		if ($_ eq $pageadd) { $flag=1; }
	}
	if ($flag==0){
        	my $sql = "INSERT INTO config (attribute,item,value) VALUES ('page:type','$pageadd','l3')";
        	my $sth = $db->prepare($sql);
        	$sth->execute();
	}
	else {
		$Message="Page $pageadd already exists";
	}
	fill_pagelist();
	make_pageselectframe( $button_frame);
	manage_pages();
}
		

sub display_selected_page {	# What to do if a page was selected from the menubar
	(my $pagename)=@_;
	if ($pagename eq 'none'){ logoframe() ; }
	elsif ($pagename eq 'top'){ display_top_page ; }
	else {
		$l3_showpage=$pagename;
		display_other_page();
	}
}

sub make_realpageselectframe {	# drop-down in the menu-bar
	(my $parent)=@_;
	$realpageselectframe->destroy if Tk::Exists($realpageselectframe);
	fill_pagelist();
	debug ($DEB_FRAME,"18 Create pageselectframe");
	$realpageselectframe=$parent->Frame()->pack(-side=>'right');
	$realpageselectframe->JBrowseEntry(-variable => \$selectedrealpage, -width=>30, -choices => \@realpagelist, -height=>10)->pack();
	
}
sub make_pageselectframe {	# drop-down in the menu-bar
	(my $parent)=@_;
	$pageselectframe->destroy if Tk::Exists($pageselectframe);
	fill_pagelist();
	debug ($DEB_FRAME,"18 Create pageselectframe");
	$pageselectframe=$parent->Frame()->pack(-side=>'right');
	$pageselectframe->Label ( -anchor => 'w',-width=>10,-text=>'Page')->pack(-side=>'left');
	$pageselectframe->JBrowseEntry(-variable => \$selectedpage, -width=>25, -choices => \@pagelist, -height=>10, -browsecmd => sub { display_selected_page ($selectedpage);} )->pack();
	
}

	
#  __  __       _       
# |  \/  | __ _(_)_ __  
# | |\/| |/ _` | | '_ \ 
# | |  | | (_| | | | | |
# |_|  |_|\__,_|_|_| |_|
#   


connect_db();

fill_pagelist();
#
#	Main Window
#
$main_window = MainWindow->new(
);
$main_window->FullScreen;
nw_read_logos($main_window,"/home/ljm/src/djedefre/images");
$main_window->Label(-textvariable=>\$Message, -width=>1500)->pack(-side=>'top');
my $image = $main_window->Photo(-file => "$image_directory/djedefre.gif");
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
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"21 Create main_frame");
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
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
	manage_pages()
})->pack(-side=>'left');
debug ($DEB_FRAME,"22 Create button_frame_pgsel");
my $button_frame_pgsel=$button_frame->Frame()->pack(-side=>'right');
make_pageselectframe($button_frame_pgsel);


my $image = $main_frame->Photo(-file => "$image_directory/djedefre.gif");
logoframe();

sub repeat {
	$main_window->after(1000,\&repeat);
	$main_window_height=$main_window->height;
	$main_window_width=$main_window->width;
}
$main_window->after(1000,\&repeat);

MainLoop;
# print "$_\n" for keys %INC;

sub logoframe {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"23 Create main_frame");
	$main_frame=$main_window->Frame(
		-height      => 0.8*$main_window_height,
		-width       => $main_window_width
	)->pack(-side =>'top');
	$main_frame->Label(-text=>'Djedefre', -width=>1500)->pack(-side=>'top');
	$main_frame->Label(-image => $image)->pack(-side=>'top');
}
