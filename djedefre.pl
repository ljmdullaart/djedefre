#!/usr/bin/perl
use strict;
use Tk;
use Tk::PNG;
use Tk::Photo;
use Image::Magick;
use Tk::JBrowseEntry;
use DBI;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;

my $topdir='.';
my $image_directory="$topdir/images";
my $scan_directory ="$topdir/scan_scripts";
my $dbfile="$topdir/database/djedefre.db";
my $configfilename="djedefre.conf";
my $canvas_xsize=1500;
my $canvas_ysize=1200;
my $subframe;
my $main_frame;
my $last_message='Welcome';
my @subnets;
my $dragid=0;
my $dragindex=0;
my $Message='';
my $page='top';

my $ConfigFileSpec;

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub parseconfig {
	my ($ConfigFileSpec)=@_;
	if ( -e $ConfigFileSpec ) {
		if (open (my $CONFIG, "<", $ConfigFileSpec )){
			while (<$CONFIG>){
				s/ //g;
				s/#.*//;
				if (/topdir=(.*)/) {$topdir=$1;}
				elsif (/dbfile=(.*)/) {$dbfile=$1;}
				elsif (/image_directory=(.*)/) {$image_directory=$1;}
				elsif (/last_message=(.*)/) {$last_message=$1;}
				elsif (/canvas_xsize=([0-9][0-9]*)/) {$canvas_xsize=$1;}
				elsif (/canvas_ysize=([0-9][0-9]*)/) {$canvas_ysize=$1;}
				elsif (/print/){
					print "dbfile=$dbfile\n";
					print "image_directory=$image_directory\n";
					print "last_message=$last_message\n";
					print "x=$canvas_xsize\n";
					print "y=$canvas_ysize\n";
				}
			}
			close $CONFIG;
		}
	}
}

parseconfig('/etc/djedefre.conf');
parseconfig('/opt/djedefre/etc/djedefre.conf');
parseconfig('/var/local/etc/djedefre.conf');
$ConfigFileSpec = File::HomeDir->my_home . "/.$configfilename";
parseconfig($ConfigFileSpec);
parseconfig('djedefre.conf');

sub clear_subframe {
	$subframe->destroy();
	$subframe=$main_frame->Frame(-borderwidth => 3, -height => 1000, -width => 1500)->pack(-side=>'top');;
	$subframe->Label(-textvariable=>\$last_message, -width=>1500)->pack(-side=>'top');
	$last_message='';
}

my $main_window = MainWindow->new;
$main_window->title("djedefre");
$main_window->FullScreen;

sub ipisinsubnet {
	(my $ip, my $subnet)=@_;
	my @octets=split ('\.',$ip);
	my $ipbin=256*(256*(256*$octets[0]+$octets[1])+$octets[2])+$octets[3];
	my $net; my $cidr;
	if ($subnet=~/([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)\/([0-9]*)/){
		$net=256*(256*(256*$1+$2)+$3)+$4;
		$cidr=$5;
		my $a=0xffffffff;
		my $b=$a<<(32-$cidr);
		my $c=$b&0xffffffff;
		if (($net & $c)==($ipbin & $c)){
			return 1;
		}
		else {
			return 0;
		}
	}
	elsif ($subnet=~/Internet/){
		if ($ip=~/Internet/){
			return 1;
		}
		else { return 0;}
	}
	else {
		print "subnet $subnet is not recognized\n";
		$Message= "subnet $subnet is not recognized\n";

	}
	return 0;
}

		

#      _       _        _
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
 
sub init_db {
	connect_db();
	my $schema='';
	$schema="
	create table if not exists interfaces (
  	  id        integer primary key autoincrement,
  	  macid     string,
  	  ip        string,
  	  hostname  string,
	  host      integer,
	  subnet    integer,
	  access    string
	);
	";
	$db->do($schema) or die $db->errstr;
	$schema="
	create table if not exists subnet (
  	  id         integer primary key autoincrement,
  	  nwaddress  string,
  	  cidr       integer,
	  xcoord     integer,
	  ycoord     integer,
	  name       string,
	  options    string,
	  access     string
	);
	";
	$db->do($schema) or die $db->errstr;
	$schema="
	create table if not exists server (
  	  id         integer primary key autoincrement,
  	  name       string,
  	  xcoord     integer,
  	  ycoord     integer,
	  type       string,
  	  interfaces string,
	  access     string,
	  status     string,
	  last_up    integer,
	  options    string
	);
	";
	$db->do($schema) or die $db->errstr;
	$schema="
	create table if not exists command (
  	  id         integer primary key autoincrement,
  	  host       string,
	  button     string,
	  command    string
	);
	";
	$db->do($schema) or die $db->errstr;
	$schema="
	create table if not exists pages (
	  id         integer primary key autoincrement,
	  page       string,
          tbl        string,
          item       integer,
          xcoord     integer,
          ycoord     integer
	);
	";
	$db->do($schema) or die $db->errstr;
	$schema="
	create table if not exists config (
  	  id         integer primary key autoincrement,
  	  attribute  string,
	  item       string,
	  value      string
	);
	";
	$db->do($schema) or die $db->errstr;
}

sub db_insert_subnet {
	(my $nwaddress,my $cidr,my $arpcmd)=@_;
	$arpcmd='' unless defined $arpcmd;
	$cidr='24' unless defined $cidr;
	$nwaddress='192.168.178.0' unless defined $nwaddress;
	
	my $sql='insert into subnet (nwaddress,cidr) values (?,?)';
	my $sth = $db->prepare($sql);
	$sth->execute($nwaddress,$cidr);
}

my @subnets;
sub db_list_subnets {
	undef @subnets;
	my $sql = 'SELECT id,nwaddress,cidr FROM subnet';
	my $sth = $db->prepare($sql);
	$sth->execute();
	undef @subnets;
	while((my $id,my $nwaddress, my $cidr) = $sth->fetchrow()){
		push @subnets,"$id:$nwaddress/$cidr";

	}
}

sub db_delete_subnet {
	(my $id)=@_;
	my $sql = 'DELETE FROM subnet WHERE id=?';
	my $sth = $db->prepare($sql);
	$sth->execute($id);
}

#             _                      _
#  _ __   ___| |___      _____  _ __| | __
# | '_ \ / _ \ __\ \ /\ / / _ \| '__| |/ /
# | | | |  __/ |_ \ V  V / (_) | |  |   <
# |_| |_|\___|\__| \_/\_/ \___/|_|  |_|\_\
#
#      _                    _
#   __| |_ __ __ ___      _(_)_ __   __ _
#  / _` | '__/ _` \ \ /\ / / | '_ \ / _` |
# | (_| | | | (_| |\ V  V /| | | | | (_| |
#  \__,_|_|  \__,_| \_/\_/ |_|_| |_|\__, |
#                                   |___/

# prefix: nw_

my $nw_tmpx=10; my $nw_tmpy=10;
my $nw_nxtfree=0;
my @nw_xcoord; my @nw_ycoord;
my @nw_type;
my @nw_text;
my @nw_status;
my @nw_ipaddress;
my @nw_cidr;
my @nw_options;
my @nw_recordid;
my @nw_objectid;
my @nw_textid;
my @nw_statusid;
my %draginfo;
my $nw_canvas;
my %nw_logos;
my @nw_vbline;
my @nw_vblinefrom;
my @nw_vblineto;
my $nw_qvbline=0;
my @nw_line;
my @nw_linefrom;
my @nw_lineto;
my $nw_qline=0;
my $nw_info_frame;
my $nw_button_frame;

my $linetest;

sub nw_dellines {
	for (my $i=0; $i<$nw_qline;$i++){
		$nw_canvas->delete($nw_line[$i]);
	}
	for (my $i=0; $i<$nw_qvbline;$i++){
		$nw_canvas->delete($nw_vbline[$i]);
	}
}
sub nw_drawlines {
	nw_dellines();
	for (my $i=0; $i<$nw_qvbline;$i++){
		my $src=$nw_vblinefrom[$i];
		my $dest=$nw_vblineto[$i];
		$nw_vbline[$i]=$nw_canvas->createLine(
			$nw_xcoord[$src],
			$nw_ycoord[$src],
			$nw_xcoord[$dest],
			$nw_ycoord[$dest],
			-fill => 'LightGrey',
			-width => 10,
			-tags=>['scalable']
		);
	}
	for (my $i=0; $i<$nw_qline;$i++){
		my $src=$nw_linefrom[$i];
		my $dest=$nw_lineto[$i];
		$nw_line[$i]=$nw_canvas->createLine($nw_xcoord[$src],$nw_ycoord[$src],$nw_xcoord[$dest],$nw_ycoord[$dest],-tags=>['scalable']);
	}
}

sub nw_drawall {
	nw_drawlines();
	for (my $i=0; $i<$nw_nxtfree;$i++){
		if ($nw_text[$i] eq 'Internet'){
			$nw_objectid[$i]=$nw_canvas->createImage($nw_xcoord[$i],$nw_ycoord[$i],-image=>$nw_logos{'internet'},-tags=>['draggable','scalable',"item$i"]);
		}
		else {
			$nw_objectid[$i]=$nw_canvas->createImage($nw_xcoord[$i],$nw_ycoord[$i],-image=>$nw_logos{$nw_type[$i]},-tags=>['draggable','scalable',"item$i"]);
		}
		$nw_textid[$i]=$nw_canvas->createText($nw_xcoord[$i],$nw_ycoord[$i]+25,-text=>$nw_text[$i],-tags=>['scalable']);
		if ($nw_status[$i] eq 'up' ){
			$nw_statusid[$i]=$nw_canvas->createOval($nw_xcoord[$i]+10,$nw_ycoord[$i]-10,$nw_xcoord[$i]+15,$nw_ycoord[$i]-5,-fill=>'green');
		}
		elsif ($nw_status[$i] eq 'down' ){
			$nw_statusid[$i]=$nw_canvas->createOval($nw_xcoord[$i]+10,$nw_ycoord[$i]-10,$nw_xcoord[$i]+15,$nw_ycoord[$i]-5,-fill=>'red');
		}
		else {
			$nw_statusid[$i]=$nw_canvas->createOval($nw_xcoord[$i]+10,$nw_ycoord[$i]-10,$nw_xcoord[$i]+15,$nw_ycoord[$i]-5,-fill=>'grey');
		}
	}
}

sub nw_clearall {
	for (my $i=0; $i<$nw_qline;$i++){
		$nw_canvas->delete($nw_line[$i]);
	}
	for (my $i=0; $i<$nw_nxtfree;$i++){
		$nw_canvas->delete($nw_objectid[$i]);
		$nw_canvas->delete($nw_textid[$i]);
		$nw_canvas->delete($nw_statusid[$i]);
	}
}

my @typeslist;
sub read_logos {
	# Get the logo-types in a hash
	my @logo_files=read_dir($image_directory);
	for (@logo_files){
		if (/logo_(.*).png/){
			$nw_logos{$1} = $subframe->Photo(-file=>"$image_directory/$_");
		}
	}
	@typeslist=sort  keys(%nw_logos);
}

sub nw_set_objarray {
	$nw_nxtfree=0;
	$nw_qline=0;
	$nw_qvbline=0;
	$nw_tmpx=20;
	$nw_tmpy=20;
	# Setup arrays for the objects
	my $sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name FROM subnet';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $nwaddress, my $cidr,my $x,my $y,my $name) = $sth->fetchrow()){
		$nw_tmpx=$nw_tmpx+50;
		if ($nw_tmpx > ($canvas_xsize-50)){
			$nw_tmpy=$nw_tmpy+50;
			$nw_tmpx=20;
		}
		$x=$nw_tmpx unless defined $x;
		$y=$nw_tmpy unless defined $y;
		$name='' unless defined $name;
		$nw_xcoord[$nw_nxtfree]=$x;
		$nw_ycoord[$nw_nxtfree]=$y;
		$nw_type[$nw_nxtfree]='subnet';
		$nw_ipaddress[$nw_nxtfree]=$nwaddress;
		$nw_cidr[$nw_nxtfree]=$cidr;
		$nw_options[$nw_nxtfree]='';
		if ($name eq '' ){
			$nw_text[$nw_nxtfree]="$nwaddress/$cidr";
		}
		else {
			$nw_text[$nw_nxtfree]=$name;
		}
		$nw_recordid[$nw_nxtfree]=$id;
		$nw_nxtfree++;
	}
	my $sql = 'SELECT id,name,xcoord,ycoord,type,interfaces,status,options FROM server';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $name, my $x,my $y,my $type,my $interfaces,my $status,my $options) = $sth->fetchrow()){
		$nw_tmpx=$nw_tmpx+50;
		if ($nw_tmpx > ($canvas_xsize-50)){
			$nw_tmpy=$nw_tmpy+50;
			$nw_tmpx=20;
		}
		$x=$nw_tmpx unless defined $x;
		$y=$nw_tmpy unless defined $y;
		$type='server' unless defined $type;
		$status='' unless defined $status;
		$nw_xcoord[$nw_nxtfree]=$x;
		$nw_ycoord[$nw_nxtfree]=$y;
		$nw_type[$nw_nxtfree]=$type;
		$nw_text[$nw_nxtfree]=$name;
		$nw_status[$nw_nxtfree]=$status;
		$nw_recordid[$nw_nxtfree]=$id;
		$nw_ipaddress[$nw_nxtfree]=$interfaces;
		$nw_options[$nw_nxtfree]=$options;
		$nw_nxtfree++;
	}
}

sub nw_set_linearray {
	for (my $i=0; $i<$nw_nxtfree;$i++){
		if($nw_type[$i] ne 'subnet'){
			my @interfacelist;
			undef @interfacelist;
			my $sql = "SELECT ip FROM interfaces WHERE host='$nw_recordid[$i]'";
			my $sth = $db->prepare($sql);
			$sth->execute();
			while((my $ip) = $sth->fetchrow()){
				push @interfacelist,$ip;
			}
			for (my $j=0; $j<$nw_nxtfree;$j++){
				if($nw_type[$j] eq 'subnet'){
					# Lines are drawn from subnet to server.
					for (@interfacelist){
						if (($_ eq 'Internet') && ($nw_ipaddress[$j] eq 'Internet')){
							$nw_linefrom[$nw_qline]=$j;
							$nw_lineto[$nw_qline]=$i;
							$nw_qline++;
						}
						elsif (ipisinsubnet($_,"$nw_ipaddress[$j]/$nw_cidr[$j]")==1){
							$nw_linefrom[$nw_qline]=$j;
							$nw_lineto[$nw_qline]=$i;
							$nw_qline++;
						}
					}
				}
			}
		}
	}
	for (my $i=0; $i<$nw_nxtfree;$i++){
		if($nw_type[$i] ne 'subnet'){
			if ($nw_options[$i]=~/vboxhost:([0-9]*),/){

				my $vboxhostid=$1;
				for (my $j=0; $j<$nw_nxtfree;$j++){
					if(($nw_recordid[$j] == $vboxhostid)&&($nw_type[$j] ne 'subnet')){
						$nw_vblinefrom[$nw_qvbline]=$j;
						$nw_vblineto[$nw_qvbline]=$i;
						$nw_qvbline++;
					}
				}
			}
		}
	}
}


sub network_frame {
	read_logos();
	nw_set_objarray();
	nw_set_linearray();
	$nw_info_frame = $subframe->Frame(
		-borderwidth => 3,
	)->pack(-side=>'right');
	$nw_button_frame = $subframe->Frame(
		-borderwidth => 3,
	)->pack(-side=>'top');
	$nw_button_frame->Button ( -width=>20,-text=>'Export canvas', -command=>sub {$Message='';nw_export();})->pack(-side=>'left');
	
	my $nw_frame = $subframe->Frame(
		-borderwidth => 3,
		-height      => 900,
		-relief      => 'raised',
		-width       => 1500
	)->pack(-side=>'left');
	$nw_canvas = $nw_frame->Canvas(
		-width      => $canvas_xsize,
		-height     => $canvas_ysize,
	)->pack;
	nw_drawall();

	my $update_plot=$nw_canvas->repeat(1000,sub{
		if ($dragid==0){
			nw_set_objarray();
			nw_set_linearray();
			nw_clearall();
			nw_drawall();
		}
	});
	$nw_canvas->bind( 'draggable', '<1>'                   => sub{ drag_start();});
	$nw_canvas->bind( 'draggable', '<3>'                   => sub{ $Message=''; nw_fill_info($nw_canvas,$Tk::event->x, $Tk::event->y )} );
	$nw_canvas->bind( 'draggable', '<B1-Motion>'           => sub{ drag_during ();});
	$nw_canvas->bind( 'draggable', '<Any-ButtonRelease-1>' => sub{ drag_end ();});

}

sub nw_export(){
	if (defined $nw_canvas){
		$nw_canvas->postscript(-file => "djedefre_network.ps");
	}
}

sub nw_merge_servers{
	my ($id,$target)=@_;
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
	elsif ($target=~/^(\d)$/){
		$targetid=$1;
	}
	if ($targetid == $id){
		print "No valid target for merge\n";
	}
	else {
		print "Merge $id to $targetid\n";
		my $sql = "SELECT id FROM interfaces WHERE host=$id";
		my $sth = $db->prepare($sql);
		$sth->execute();
		my @iflist;
		while((my $ifid) = $sth->fetchrow()){
			push @iflist,$ifid;
		}
		foreach(@iflist){
			print "    Interface $_ to $targetid\n";
			my $sql = "UPDATE interfaces SET host=$targetid WHERE id=$_";
			my $sth = $db->prepare($sql);
			$sth->execute();
		}
		print "    Delete server $id\n";
		my $sql = "DELETE FROM server WHERE id=$id";
		my $sth = $db->prepare($sql);
		$sth->execute();
	}
		
}

my $nw_frame_for_info;
my $nw_frame_for_info_counter=1;
my $nw_this_status;
my $nw_through_host=-1;
my $nw_through_text='No ping-through';
my $typechoice;
my $nw_frame_name_value='';
my $nw_frame_merge_value='-';
my $nw_frame_nmap;
	
	


sub nw_fill_info {
	my ( $c, $x, $y ) = @_;
	$nw_frame_for_info->destroy if Tk::Exists($nw_frame_for_info);
	$nw_frame_for_info=$nw_info_frame->Frame(-borderwidth => 3,-height=>1000)->pack(-side=>'top' );
	my $id = -1;
	$c->addtag( qw/current closest/, $x, $y );
	my @tags = grep {$_ ne 'current'} $c->gettags(qw/current/);
	$c->dtag(qw/current current/);
	for(@tags){
		if (/item([0-9]+)/){ $id=$1;}
	}
	my $local_frame;
	if ($id>=0){
		if ($nw_type[$id] eq 'subnet'){
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Type')->pack(-side=>'left');
			$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$nw_type[$id])->pack(-side=>'right');
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
			$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$nw_recordid[$id])->pack(-side=>'right');
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {$Message='';nw_change_name($id,$nw_frame_name_value,'subnet');})->pack(-side=>'left');
			$nw_frame_name_value=$nw_text[$id];
			$local_frame->Entry ( -width=>30,-textvariable=>\$nw_frame_name_value)->pack(-side=>'right');
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Subnet')->pack(-side=>'left');
			$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$nw_ipaddress[$id])->pack(-side=>'right');
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'CIDR')->pack(-side=>'left');
			$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$nw_cidr[$id])->pack(-side=>'right');
		}
		else {
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Type')->pack(-side=>'left');
			$typechoice=$nw_type[$id];
			#$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$nw_type[$id])->pack(-side=>'right');
			#$local_frame->Optionmenu(-variable => \$typechoice, -width=>25, -options => \@typeslist, -command => sub { set_type($typechoice,$id) } )->pack();
			$local_frame->JBrowseEntry(-variable => \$typechoice, -width=>25, -choices => \@typeslist, -height=>10, -browsecmd => sub { set_type($typechoice,$id) } )->pack();
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
			$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$nw_recordid[$id])->pack(-side=>'right');
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {$Message='';nw_change_name($id,$nw_frame_name_value,'server');})->pack(-side=>'left');
			$nw_frame_name_value=$nw_text[$id];
			$local_frame->Entry ( -width=>30,-textvariable=>\$nw_frame_name_value)->pack(-side=>'right');
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Button(-text => "Merge",-width=>10, -command =>sub {$Message=''; nw_merge_servers($nw_recordid[$id],$nw_frame_merge_value);$nw_frame_merge_value='-';})->pack(-side=>'left');
			$nw_frame_merge_value='-';
			$local_frame->Entry ( -width=>30,-textvariable=>\$nw_frame_merge_value)->pack(-side=>'right');
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Interfaces')->pack(-side=>'left');
			my $ifs='';
			my $sql = "SELECT ip FROM interfaces WHERE host='$nw_recordid[$id]'";
			my $sth = $db->prepare($sql);
			$sth->execute();
			while((my $ip) = $sth->fetchrow()){
				$ifs="$ifs,$ip";
			}
			$ifs=~s/^,//; $ifs=~s/,$//;
			my @ifarray=split(',',$ifs);
			$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$ifarray[0])->pack(-side=>'right');
			for (my $i=1; $i<=$#ifarray; $i++){
				$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
				$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'  ')->pack(-side=>'left');
				$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$ifarray[$i])->pack(-side=>'right');
			}
			$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Status')->pack(-side=>'left');
			$nw_this_status=$nw_status[$id];
			$local_frame->Label ( -anchor => 'w',-width=>30,-textvariable=>\$nw_this_status)->pack(-side=>'right');


		}
		#$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
		#$local_frame->Button(-text => "Direct ping",-width=>20, -command =>sub {$Message='';nw_ping_a_host($id);})->pack(-side=>'left');
		#$local_frame->Button(-text => "ARPping",-width=>20, -command =>sub {$Message='';nw_arping_a_host($id);})->pack(-side=>'left');
		#$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
		#$local_frame->Button(-text => "Set as through",-width=>20, -command =>sub {$Message='';nw_set_through($id);})->pack(-side=>'left');
		#$local_frame->Button(-textvariable => \$nw_through_text,-width=>20, -command =>sub {$Message='';nw_ping_via($id);})->pack(-side=>'left');
		$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
		if ($nw_type[$id] eq 'subnet'){
			$local_frame->Button(-text => "Networkscan",-width=>20, -command =>sub {$Message='';nw_nmap($id);})->pack(-side=>'left');
		}
		else {
			$local_frame->Button(-text => "Portscan",-width=>20, -command =>sub {$Message='';nw_nmap($id);})->pack(-side=>'left');
		}
		$local_frame->Button(-text => "Status",-width=>20, -command =>sub {$Message='';nw_status($id);})->pack(-side=>'left');
		$nw_frame_nmap=$nw_frame_for_info->Frame(-height=>200)->pack(-side=>'top');
		$local_frame=$nw_frame_for_info->Frame()->pack(-side=>'top');
		$local_frame->Button(-text => "Delete",-width=>20, -command =>sub {$Message='';nw_delete_server($id);})->pack(-side=>'left');
	}
	$nw_frame_for_info_counter++;
}
sub nw_change_name{
	(my $id,my $val,my $table)=@_;
	if ( $nw_frame_name_value ne $nw_text[$id]){
		$nw_text[$id]=$nw_frame_name_value;
		my $sql = "UPDATE $table SET name='$nw_frame_name_value' WHERE id=$nw_recordid[$id]";
		my $sth = $db->prepare($sql);
		$sth->execute();
	}
}
sub nw_status{
	(my $idx)=@_;
}

sub nw_nmap {
	(my $idx)=@_;
	if ($nw_type[$idx] ne 'subnet'){
		nw_portscan_server($idx);
	}
	else {
		nw_scan_subnet($idx);
	}
}

my $nw_frame_nmap_i;
sub nw_portscan_server {
	(my $idx)=@_;
	my @interfacelist;
	undef @interfacelist;
	my @ports;
	if ($nw_type[$idx] ne 'subnet'){
		my $sql = "SELECT ip FROM interfaces WHERE host='$nw_recordid[$idx]'";
		my $sth = $db->prepare($sql);
		$sth->execute();
		while((my $ip) = $sth->fetchrow()){
			push @interfacelist,$ip;
		}
		for (@interfacelist){
			if (open (my $PORTS,"sudo nmap $_ |")){
				while (<$PORTS>){
					if (/(\d+)\/(..p)\s*(\w+)\s+(\w+)/){
						push @ports, "$1 $2 $3 $4";
					}
				}
			}
			else {
				print "ERROR: Cannot run nmap\n";
			}
		}
		$nw_frame_nmap_i->destroy if Tk::Exists($nw_frame_nmap_i);
		$nw_frame_nmap_i=$nw_frame_nmap->Frame(-height=>190)->pack(-side=>'top');
		my $scroll = $nw_frame_nmap_i->Scrollbar( );
		my $columns=[
			$nw_frame_nmap_i->Listbox(-height=> 10,-width=>10,-font=>"arial 14"),
			$nw_frame_nmap_i->Listbox(-height=> 10,-width=>10,-font=>"arial 14"),
			$nw_frame_nmap_i->Listbox(-height=> 10,-width=>10,-font=>"arial 14")
		];
		foreach my $lstbx (@$columns){
			$lstbx->configure(-yscrollcommand => [ \&scroll_listboxes, $scroll,$lstbx, $columns ]);
		}
		$scroll->configure(-command => sub {
			foreach my $list (@$columns) {
				$list->yview(@_);
			}
		}); 
		$scroll->pack(-side => 'right', -fill => 'y');
		foreach my $list (@$columns) {
			$list->pack(-side => 'left'); 
		}
		my @uports=uniq(@ports);
		@ports=sort { $a <=> $b }  @uports;
		for (@ports){
			if (/(\w+) (\w+) (\w+) (\w+)/){
				${$columns}[0]->insert('end',"$1/$2");
				${$columns}[1]->insert('end',$3);
				${$columns}[2]->insert('end',$4);
			}
		}
	}
}

sub nw_scan_subnet {
	(my $idx)=@_;
	my @interfacelist;
	undef @interfacelist;
	my @up;
	if ($nw_type[$idx] eq 'subnet'){
		my $sql = "SELECT nwaddress,cidr FROM subnet WHERE id=$nw_recordid[$idx]";
		my $sth = $db->prepare($sql);
		$sth->execute();
		while((my $ip,my $cidr) = $sth->fetchrow()){
			push @interfacelist,"$ip/$cidr";
		}
		$nw_frame_nmap_i->destroy if Tk::Exists($nw_frame_nmap_i);
		$nw_frame_nmap_i=$nw_frame_nmap->Frame(-height=>190)->pack(-side=>'top');
		my $scroll = $nw_frame_nmap_i->Scrollbar( );
		my $columns=[
			$nw_frame_nmap_i->Listbox(-height=> 10,-width=>15,-font=>"arial 14"),
			$nw_frame_nmap_i->Listbox(-height=> 10,-width=>20,-font=>"arial 14"),
		];
		foreach my $lstbx (@$columns){
			$lstbx->configure(-yscrollcommand => [ \&scroll_listboxes, $scroll,$lstbx, $columns ]);
		}
		$scroll->configure(-command => sub {
			foreach my $list (@$columns) {
				$list->yview(@_);
			}
		}); 
		$scroll->pack(-side => 'right', -fill => 'y');
		foreach my $list (@$columns) {
			$list->pack(-side => 'left'); 
		}
		for (@interfacelist){
			if (open (my $PORTS,"sudo nmap -n -sn -T5  $_ -oG - |")){
				while (<$PORTS>){
					if (/Host: ([0-9\.]+) .*Up/){
						${$columns}[0]->insert('end',"$1");
						my $sql = "SELECT hostname FROM interfaces WHERE ip='$1'";
						my $sth = $db->prepare($sql);
						$sth->execute();
						while((my $hostname) = $sth->fetchrow()){
							${$columns}[1]->insert('end',"$hostname");
						}
					}
				}
			}
			else {
				print "ERROR: Cannot run nmap\n";
			}
		}
	}
}

sub nw_delete_server {
	(my $idx)=@_;
	if ($nw_type[$idx] eq 'subnet'){
		my $sql = "DELETE FROM subnet WHERE id=$nw_recordid[$idx]";
		my $sth = $db->prepare($sql);
		$sth->execute();
	}
	else {
		my $sql = "DELETE FROM server WHERE id=$nw_recordid[$idx]";
		my $sth = $db->prepare($sql);
		$sth->execute();
	}
	$nw_frame_for_info->destroy if Tk::Exists($nw_frame_for_info);
}

sub set_type {
	(my $tpchoice,my $id)=@_;
	if ($typechoice ne 'subnet'){
		$nw_type[$id]=$typechoice;
		my $sql = "UPDATE server SET type='$typechoice' WHERE id=$nw_recordid[$id]";
		my $sth = $db->prepare($sql);
		$sth->execute();
	}

}

#sub nw_ping_via {
#	(my $idx)=@_;
#	my $via='none';
#	my $viaifs=$nw_ipaddress[$nw_through_host];
#	$viaifs=~s/^,//; $viaifs=~s/,$//;
#	my @viaifarray=split(',',$viaifs);
#	for (my $i=0; $i<=$#viaifarray; $i++){
#		if ($ping->ping($viaifarray[$i])){
#			my $sql = "SELECT access FROM interfaces WHERE ip='$viaifarray[$i]'";
#			my $sth = $db->prepare($sql);
#			$sth->execute();
#			while((my $access) = $sth->fetchrow()){
#				if ($access eq 'ssh'){
#					$via=$viaifarray[$i];
#				}
#			}
#		}
#	}
#	if ($via eq 'none'){
#		$Message="Cannot access $nw_text[$nw_through_host] for pinging.";
#	}
#	else {
#		my $ifs=$nw_ipaddress[$idx];
#		$ifs=~s/^,//; $ifs=~s/,$//;
#		my @ifarray=split(',',$ifs);
#		$nw_this_status='down';
#		for (my $i=0; ($i<=$#ifarray) && ($nw_this_status eq 'down'); $i++){
#			system("ssh $via ping -c1 $ifarray[$i] | grep ' 0% packet loss'");
#			my $p=$?>>8;
#			if ($p==0){
#				$nw_this_status='up';
#			}
#	
#		}
#		my $sql = "UPDATE server SET status='$nw_this_status' WHERE id=$nw_recordid[$idx]";
#		my $sth = $db->prepare($sql);
#		$sth->execute();
#		$Message="Ping to $nw_text[$idx] via $nw_text[$nw_through_host] status $nw_this_status.";
#
#	}
#}
#


	
sub nw_set_through {
	(my $idx)=@_;
	$nw_through_host=$idx;
	$nw_through_text="Ping via $nw_text[$idx]";
}

sub nw_arping_a_host {
	(my $idx)=@_;
	my $ifs=$nw_ipaddress[$idx];
	$nw_this_status='down';
	$ifs=~s/^,//; $ifs=~s/,$//;
	my @ifarray=split(',',$ifs);
	my $p;
	for (my $i=0; ($i<=$#ifarray) && ($nw_this_status eq 'down'); $i++){
		system("arping -c1 -w1 $ifarray[$i]");
		$p=$?>>8;
		if ($p==0){
			$nw_this_status='up';
		}
	}
	my $sql = "UPDATE server SET status='$nw_this_status' WHERE id=$nw_recordid[$idx]";
	my $sth = $db->prepare($sql);
	$sth->execute();
	$Message="Arping to $nw_text[$idx]  status=$nw_this_status.";

}

#sub nw_ping_a_host {
#	(my $idx)=@_;
#	my $ifs=$nw_ipaddress[$idx];
#	$ifs=~s/^,//; $ifs=~s/,$//;
#	my @ifarray=split(',',$ifs);
#	$nw_this_status='down';
#
#	for (my $i=0; ($i<=$#ifarray) && ($nw_this_status eq 'down'); $i++){
#		if ($ping->ping($ifarray[$i])){
#			$nw_this_status='up';
#		}
#	}
#	my $sql = "UPDATE server SET status='$nw_this_status' WHERE id=$nw_recordid[$idx]";
#	my $sth = $db->prepare($sql);
#	$sth->execute();
#	$Message="Ping to $nw_text[$idx]  status=$nw_this_status.";
#
#}


sub drag_start {
	$Message='';
	my $e = $nw_canvas->XEvent;
	# get the screen position of the initial button press...
	my ( $sx, $sy ) = ( $e->x, $e->y,,, );
	# get the canvas position...
	my ( $cx, $cy ) = ( $nw_canvas->canvasx($sx), $nw_canvas->canvasy($sy) );
	# get the clicked item...
	my $id = $nw_canvas->find( 'withtag', 'current' );
	my ( $x1, $y1, $x2, $y2 ) = $nw_canvas->bbox($id);
	# set up the draginfo...
	$draginfo{id}     = $id;
	my @idarr=@{$id};
	$dragid=$idarr[0];
	for ($dragindex=0; ($dragindex<$nw_nxtfree)&&($nw_objectid[$dragindex]!=$dragid);$dragindex++){};
	$draginfo{startx} = $draginfo{lastx} = $cx;
	$draginfo{starty} = $draginfo{lasty} = $cy;
}

sub drag_during {
	my $e = $nw_canvas->XEvent;
	# get the screen position of the move...
	my ( $sx, $sy ) = ( $e->x, $e->y,,, );
	# get the canvas position...
	my ( $cx, $cy ) = ( $nw_canvas->canvasx($sx), $nw_canvas->canvasy($sy) );
	# get the amount to move...
	my $dx; my $dy;
	( $dx, $dy ) = ( $cx - $draginfo{lastx}, $cy - $draginfo{lasty} );
	# move it...
	$nw_canvas->move( $draginfo{id}, $dx, $dy );
	$nw_canvas->move($nw_textid[$dragindex], $dx, $dy );
	$nw_canvas->move($nw_statusid[$dragindex], $dx, $dy );
	# update last position
	$draginfo{lastx} = $cx;
	$draginfo{lasty} = $cy;
	$nw_xcoord[$dragindex]=$cx;
	$nw_ycoord[$dragindex]=$cy;
	my ( $x1, $y1, $x2, $y2 ) = $nw_canvas->bbox( $draginfo{id} );
	for (my $i=0; $i<$nw_qline;$i++){
		$nw_canvas->delete($nw_line[$i]);
	}
	for (my $i=0; $i<$nw_qvbline;$i++){
		$nw_canvas->delete($nw_vbline[$i]);
	}
	nw_drawlines();
}

sub drag_end {
	# upon drag end, check for valid position and act accordingly...
	# was it the card?
	my @tags = $nw_canvas->gettags( $draginfo{id} );
	if ($nw_type[$dragindex] eq 'subnet'){
	my $sql = "UPDATE subnet SET xcoord=$draginfo{lastx} WHERE id=$nw_recordid[$dragindex]\n";
	my $sth = $db->prepare($sql);
	$sth->execute();
	my $sql = "UPDATE subnet SET ycoord=$draginfo{lasty} WHERE id=$nw_recordid[$dragindex]\n";
	my $sth = $db->prepare($sql);
	$sth->execute();
	}
	else {
	my $sql = "UPDATE server SET xcoord=$draginfo{lastx} WHERE id=$nw_recordid[$dragindex]\n";
	my $sth = $db->prepare($sql);
	$sth->execute();
	my $sql = "UPDATE server SET ycoord=$draginfo{lasty} WHERE id=$nw_recordid[$dragindex]\n";
	my $sth = $db->prepare($sql);
	$sth->execute();
	}
	nw_clearall();
	nw_drawall();
	%draginfo = ();
	$dragid=0;
}

#              _   _                 
#   ___  _ __ | |_(_) ___  _ __  ___ 
#  / _ \| '_ \| __| |/ _ \| '_ \/ __|
# | (_) | |_) | |_| | (_) | | | \__ \
#  \___/| .__/ \__|_|\___/|_| |_|___/
#       |_|                    

# prefix: opt_

my $opt_scan_frame;

my $cfg;
sub cfg_frame {
	$subframe->Label(-text=>'Options', -width=>1500)->pack(-side=>'top');
	$opt_scan_frame->destroy if Tk::Exists($opt_scan_frame);
	$opt_scan_frame=$subframe->Frame(
	)->pack(-side=>'left');
	if (opendir my $SCANDIR,$scan_directory ){
		my @files = readdir $SCANDIR;
		@files=sort @files;
		closedir $SCANDIR;
		$opt_scan_frame->Label(-text=>"Scan scripts",-width=>20)->pack(-side=>'top');
		for (@files){
			if (/scan_(.*).sh/){
				my $scan=$1;
				my $text=$1; $text=~s/^.._//; $text=~s/_/ /g;
				$opt_scan_frame->Button(-text => "$text",-width=>20, -command =>sub {$Message='';opt_scan($scan);})->pack(-side=>'top');
			}
		}

	}

}
my $lock=0;

sub opt_scan {
	(my $script)=@_;
	system ("xterm -e bash $scan_directory/scan_$script.sh $dbfile &");
}
#             _                      _
#  _ __   ___| |___      _____  _ __| | __
# | '_ \ / _ \ __\ \ /\ / / _ \| '__| |/ /
# | | | |  __/ |_ \ V  V / (_) | |  |   <
# |_| |_|\___|\__| \_/\_/ \___/|_|  |_|\_\
#
#  _ _     _
# | (_)___| |_
# | | / __| __|
# | | \__ \ |_
# |_|_|___/\__|
#
#
# prefix list_

my $list_main_frame;
my $list_button_frame;
my $list_output_frame;

sub scroll_listboxes {
	my ($sb, $scrolled, $lbs, @args) = @_;
	$sb->set(@args); # tell the Scrollbar what to display
	my ($top, $bottom) = $scrolled->yview( );
	foreach my $list (@$lbs) {
		$list->yviewMoveto($top); # adjust each lb
	}
}

sub list_frame {
	$list_main_frame->destroy if Tk::Exists($list_main_frame);
	$list_main_frame = $subframe->Frame(
		-borderwidth => 3,
		-height      => 1000,
		-width       => 1500
	)->pack(-side=>'left');
	$list_button_frame=$list_main_frame->Frame(
		-height      => 100,
		-width       => 1500
	)->pack(-side=>'top');
	$list_button_frame->Button(-text => "List servers",-width=>20, -command =>sub {$Message='';list_fill_output('servers');})->pack(-side=>'left');
	$list_button_frame->Button(-text => "List subnets",-width=>20, -command =>sub {$Message='';list_fill_output('subnets');})->pack(-side=>'left');
	$list_button_frame->Button(-text => "List interfaces",-width=>20, -command =>sub {$Message='';list_fill_output('interfaces');})->pack(-side=>'left');
}


sub list_fill_output {
	(my $content)=@_;
	$list_output_frame->destroy if Tk::Exists($list_output_frame);
	$list_output_frame=$list_main_frame->Frame(
		-height      => 700,
		-width       => 1000
	)->pack(-side=>'bottom');
	if ($content eq 'servers'){
		out_servers();
	}
	elsif ($content eq 'subnets'){
		out_subnets();
	}
	elsif ($content eq 'interfaces'){
		out_interfaces();
	}
}

	
	



sub out_servers {
	my $htmlstring='';
	my $sql = 'SELECT id,name,xcoord,ycoord,type,interfaces,status,options FROM server ORDER BY id';
	my $sth = $db->prepare($sql);
	my $list_servers_frame=$list_output_frame->Frame()->pack(-side=>'left');
	$sth->execute();
	my $column_headers=$list_servers_frame->Frame()->pack(-side=>'top');
	$column_headers->Label(-text=>"Servers",-width=>20,-font=>"arial 18",-anchor=>'w')->pack(-side=>'top');
	$column_headers->Label(-text=>"ID",-width=>5,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Name",-width=>15,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Type",-width=>15,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Status",-width=>10,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	my $column_boxes=$list_servers_frame->Frame()->pack(-side=>'bottom');
	my $scroll = $column_boxes->Scrollbar( );
	my $columns=[
		$column_boxes->Listbox(-height=> 500,-width=>5,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>15,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>15,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>10,-font=>"arial 14")
	];
	foreach my $lstbx (@$columns){
		$lstbx->configure(-yscrollcommand => [ \&scroll_listboxes, $scroll,$lstbx, $columns ]);
	}
	$scroll->configure(-command => sub {
		foreach my $list (@$columns) {
			$list->yview(@_);
			$list->bind('<<ListboxSelect>>' => sub {my $sel= $list->curselection;my $id=${$columns}[0]->get($sel);print "Selected $id\n";}); 
		}
	}); 
	$scroll->pack(-side => 'right', -fill => 'y');
	foreach my $list (@$columns) {
		$list->pack(-side => 'left'); 
	}
	while((my $id,my $name, my $x,my $y,my $type,my $interfaces,my $status,my $options) = $sth->fetchrow()){
		$type='server' unless defined $type;
		$status='' unless defined $status;
		
		${$columns}[0]->insert('end',$id);
		${$columns}[1]->insert('end',$name);
		${$columns}[2]->insert('end',$type);
		${$columns}[3]->insert('end',$status);
	}

}
	
sub out_subnets {
	my $htmlstring='';
	my $sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name FROM subnet ORDER BY id';
	my $sth = $db->prepare($sql);
	my $list_servers_frame=$list_output_frame->Frame()->pack(-side=>'left');
	$sth->execute();
	my $column_headers=$list_servers_frame->Frame()->pack(-side=>'top');
	$column_headers->Label(-text=>"Subnets",-width=>20,-font=>"arial 18",-anchor=>'w')->pack(-side=>'top');
	$column_headers->Label(-text=>"ID",-width=>5,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Name",-width=>20,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Network",-width=>20,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"CIDR",-width=>10,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	my $column_boxes=$list_servers_frame->Frame()->pack(-side=>'bottom');
	my $scroll = $column_boxes->Scrollbar( );
	my $columns=[
		$column_boxes->Listbox(-height=> 500,-width=>2,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>20,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>20,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>10,-font=>"arial 14")
	];
	foreach my $lstbx (@$columns){
		$lstbx->configure(-yscrollcommand => [ \&scroll_listboxes, $scroll,$lstbx, $columns ]);
	}
	$scroll->configure(-command => sub {
		foreach my $list (@$columns) {
			$list->yview(@_);
		}
	}); 
	$scroll->pack(-side => 'right', -fill => 'y');
	foreach my $list (@$columns) {
		$list->pack(-side => 'left'); 
	}
	while((my $id,my $nwaddress,my $cidr, my $x,my $y,my $name) = $sth->fetchrow()){
		$name="$nwaddress/$cidr" unless defined $name;
		
		${$columns}[0]->insert('end',$id);
		${$columns}[1]->insert('end',$name);
		${$columns}[2]->insert('end',$nwaddress);
		${$columns}[3]->insert('end',$cidr);
	}
}

sub out_interfaces {
	my $htmlstring='';
	my $list_servers_frame=$list_output_frame->Frame()->pack(-side=>'left');
	my $column_headers=$list_servers_frame->Frame()->pack(-side=>'top');
	$column_headers->Label(-text=>"Interfaces",-width=>20,-font=>"arial 18",-anchor=>'w')->pack(-side=>'top');
	$column_headers->Label(-text=>"ID",-width=>5,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Net",-width=>5,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Host",-width=>5,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Host",-width=>15,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"IP address",-width=>20,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"Hostname",-width=>20,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	$column_headers->Label(-text=>"MAC",-width=>20,-font=>"arial 14",-anchor=>'w')->pack(-side=>'left');
	my $column_boxes=$list_servers_frame->Frame()->pack(-side=>'bottom');
	my $scroll = $column_boxes->Scrollbar( );
	my $columns=[
		$column_boxes->Listbox(-height=> 500,-width=>5,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>5,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>5,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>15,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>20,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>20,-font=>"arial 14"),
		$column_boxes->Listbox(-height=> 500,-width=>20,-font=>"arial 14")
	];
	foreach my $lstbx (@$columns){
		$lstbx->configure(-yscrollcommand => [ \&scroll_listboxes, $scroll,$lstbx, $columns ]);
	}
	$scroll->configure(-command => sub {
		foreach my $list (@$columns) {
			$list->yview(@_);
		}
	}); 
	$scroll->pack(-side => 'right', -fill => 'y');
	foreach my $list (@$columns) {
		$list->pack(-side => 'left'); 
	}
	my @servers=[];
	my $sql = 'SELECT id,name FROM server';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $name) = $sth->fetchrow()){
		$servers[$id]=$name;
	}
	my $sql = 'SELECT id,macid,ip,hostname,host,subnet,access FROM interfaces ORDER BY id';
	my $sth = $db->prepare($sql);
	$sth->execute();
	while((my $id,my $macid,my $ip,my $hostname,my $host,my $subnet,my $access) = $sth->fetchrow()){
		my $name=$servers[$host];
		$name=$hostname unless defined $name;
		${$columns}[0]->insert('end',$id);
		${$columns}[1]->insert('end',$subnet);
		${$columns}[2]->insert('end',$host);
		${$columns}[3]->insert('end',$name);
		${$columns}[4]->insert('end',$ip);
		${$columns}[5]->insert('end',$hostname);
		${$columns}[6]->insert('end',$macid);
	}
}

#                  _
#  _ __ ___   __ _(_)_ __
# | '_ ` _ \ / _` | | '_ \
# | | | | | | (_| | | | | |
# |_| |_| |_|\__,_|_|_| |_|
#

sub repeat {
	print "repeat\n";
}


init_db();
my $button_frame=$main_window->Frame(
	-height      => 100,
	-width       => 1505
)->pack;
$main_window->Label(-textvariable=>\$Message, -width=>1500)->pack(-side=>'top');
$main_frame=$main_window->Frame(
	-height      => 1005,
	-width       => 1505
)->pack;
$button_frame->Button(-text => "List network",-width=>20, -command =>sub {$Message='';clear_subframe();list_frame()})->pack(-side=>'left');
$button_frame->Button(-text => "Plot network",-width=>20, -command =>sub {$Message='';clear_subframe();network_frame()})->pack(-side=>'left');
$button_frame->Button(-text => "Options",-width=>20, -command =>sub {$Message='';clear_subframe();cfg_frame()})->pack(-side=>'left');
$button_frame->Button(-text => "exit",-width=>20, -command => sub { $main_window->destroy; })->pack(-side=>'left');
$subframe=$main_frame->Frame(-borderwidth => 3, -height => 1000, -width => 1500)->pack;
$subframe->Label(-text=>'Djedefre', -width=>1500)->pack(-side=>'top');
my $image = $subframe->Photo(-file => "$image_directory/djedefre.gif");
$subframe->Label(-image => $image)->pack(-side=>'top');

$main_window->after(60000,\&repeat);

MainLoop;
print "ended\n";
