#INSTALL@ /opt/djedefre/l3drawing.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;
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
our $l3_showpage;
$l3_showpage='top';
our $repeat_sub;
our $Message;


my $nw_tmpx=100;
my $nw_tmpy=100;
sub nxttmploc {
	$nw_tmpx=$nw_tmpx+100;
	if ($nw_tmpx > 1000){
		$nw_tmpy=$nw_tmpy+100;
		$nw_tmpx=100;
	}
	if ($nw_tmpy>1000){
		$nw_tmpy=100;
	}
}
my $qobjtypes=4;
my $objtsubnet=0;
my $objtserver=1;
my $objtswitch=2;
my $objtcloud=3;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;


# connect_db($config{'dbfile'});

sub l3_objects {
	debug($DEB_SUB,"l3_objects");
	splice @l3_obj;
	my @hostnames;
	db_dosql("SELECT interfaces.id,server.name FROM interfaces INNER JOIN server WHERE interfaces.host=server.id");
	while ((my $id,my $name)=db_getrow()){
		$hostnames[$id]=$name;
	}
	db_close();
	db_get_interfaces;
	put_netinobj($l3_showpage,\@l3_obj);
	put_serverinobj($l3_showpage,\@l3_obj,3);
	put_cloudinobj($l3_showpage,\@l3_obj);
}

my @l3_line;
sub l3_lines {
	debug($DEB_SUB,"l3_lines");
	my @interfacelist;
	splice @l3_line;

	my @ifserver;
	my %colorization;
	db_dosql("SELECT item,value FROM config WHERE attribute='line:color'");
	while ((my $item,my $value)=db_getrow()){
		$colorization{$item}=$value;
	}
	db_close();
	db_dosql("SELECT id,host FROM interfaces");
	while ((my $id, my $host)=db_getrow()){
		$ifserver[$id]=$host;
	}
	db_close();
	db_dosql("SELECT id,options FROM subnet WHERE nwaddress='Internet'");
	(my $Internet,my $Internetoptions)=db_getrow();
	while (db_getrow()){};db_close();
	my $Internetcolor='black';
	if ($Internetoptions=~/color=([^;]+);/){
		$Internetcolor=$1;
	}
	my $newInternet=$Internet*$qobjtypes+$objtsubnet;
	for my $i ( 0 .. $#l3_obj){
		if ($l3_obj[$i]->{'table'} eq 'server'){
			my $orig_id=$l3_obj[$i]->{'id'};
			my $obj_id=$l3_obj[$i]->{'newid'};
			splice my @interfacelist;
			my $sql = "SELECT ip FROM interfaces WHERE host='$orig_id'";
			my $sth = db_dosql($sql);
			while((my $ip) = db_getrow()){
				push @interfacelist,$ip;
			}
			db_close();
			for my $j ( 0 .. $#l3_obj){
				if ($l3_obj[$j]->{'table'} eq 'subnet'){
					my $netw_id=$l3_obj[$j]->{'newid'};
					my $netw=$l3_obj[$j]->{'nwaddress'};
					my $cidr=$l3_obj[$j]->{'cidr'};
					my $color=$l3_obj[$j]->{'color'};
					$cidr=24 unless defined $cidr;
					$color='black' unless defined $color;
					for (@interfacelist){
						my $lastbyte=$_; $lastbyte=~s/.*\.//;
						if (($_ eq 'Internet') && ($l3_obj[$j]->{'nwaddress'} eq 'Internet')){
							push @l3_line, {
								from	=> $netw_id,
								to	=> $obj_id,
								fromlabel=> '',
								tolabel	=> '',
								type	=> $color
							};
						}
						elsif (ipisinsubnet($_,"$netw/$cidr")==1){
							push @l3_line, {
								from	=> $netw_id,
								to	=> $obj_id,
								fromlabel=> '',
								tolabel	=> $lastbyte,
								type	=> $color
							};
						}
					}
				}
			}
			my $options=$l3_obj[$i]->{'options'};
			$options='' unless defined $options;
			if ($options=~/vboxhost:([0-9]*),/ ){
				my $hostid=$1;
				my $host=$hostid*$qobjtypes+$objtserver;
				for my $j ( 0 .. $#l3_obj){
					if (($hostid == $l3_obj[$j]->{'id'}) && ($l3_obj[$j]->{'table'} eq 'server')){
						push @l3_line, {
							from	=> $obj_id,
							to	=> $host,
							type	=> 'vbox'
						}
					}
				}
			}

		}
		if ($l3_obj[$i]->{'table'} eq 'cloud'){
			my $obj_id=$l3_obj[$i]->{'newid'};
			push @l3_line, {
				from	=> $newInternet,
				to	=> $obj_id,
				type	=> $Internetcolor
			};
			
		}

	}
}
					
my $l3_plot_frame;

sub l3_renew_content {
	debug($DEB_SUB,"l3_renew_content");
	l3_objects('top');
	l3_lines();
	nw_del_objects(@l3_obj);
	nw_del_lines(@l3_line);
	nw_objects(@l3_obj);
	nw_lines(@l3_line);
}
our $drawingname;
sub make_l3_plot {
	(my $parent)=@_;
	$drawingname='ipv4plot';
	debug($DEB_SUB,"make_l3_plot");
	$l3_plot_frame->destroy if Tk::Exists($l3_plot_frame);
	debug ($DEB_FRAME,"1 Create l3_plot_frame");
	$l3_plot_frame=$parent->Frame()->pack(-side=>'left');
	l3_renew_content();
	nw_frame($l3_plot_frame);
	nw_callback ('color',\&l3_color);
	nw_callback ('delete',\&l3_delete);
	nw_callback ('devicetype',\&l3_devicetype);
	nw_callback ('merge',\&l3_merge);
	nw_callback ('move',\&l3_move);
	nw_callback ('name',\&l3_name);
	nw_callback ('page',\&l3_page);
	nw_callback ('type',\&l3_type);
	#nw_drawall();
}
sub cbdump {
	debug($DEB_SUB,"cbdump");
	print "----Djedefre2-callback-dumper-----\n";
	print Dumper @_;
	print "----------------------------------\n";
}
sub l3_page {
	(my $table,my $id,my $name,my $action,my $page)=@_;
	debug($DEB_SUB,"l3_page");
	my $arg="$table:$id:$name";
	#$managepg_pagename=$page;
	mgpg_selector_callback ($action,$arg,$page);
	l3_renew_content();
}

sub l3_color {
	(my $table, my $id, my $color)=@_;
	debug($DEB_SUB,"l3_color");
	if ($table eq 'subnet'){
		db_dosql("SELECT options FROM $table WHERE id=$id");
		(my $opts)=db_getrow();
		while (db_getrow()){}; db_close();
		while ($opts=~/color=[^;]*;/){
			$opts=~s/color=[^;]*;//;
		}
		$opts="color=$color;$opts";
		db_dosql("UPDATE $table SET options='$opts' WHERE id=$id");
		db_close();
	}
	l3_renew_content();
}
sub l3_devicetype {
	(my $table, my $id, my $type)=@_;
	debug($DEB_SUB,"l3_devicetype");
	if ($table eq 'server'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET devicetype='$type' WHERE id=$id");
		db_close();
	}
	l3_renew_content();
}
sub l3_type {
	(my $table, my $id, my $type)=@_;
	debug($DEB_SUB,"l3_type");
	if ($table eq 'server'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET type='$type' WHERE id=$id");
		db_close();
	}
	elsif ($table eq 'cloud'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET type='$type' WHERE id=$id");
		db_close();
	}
	l3_renew_content();
}
sub l3_name {
	(my $table, my $id, my $name)=@_;
	debug($DEB_SUB,"l3_name");
	my $sql = "UPDATE $table SET name='$name' WHERE id=$id"; db_dosql($sql); db_close();
	l3_renew_content();
}
sub l3_delete {
	(my $table, my $id, my $name)=@_;
	debug($DEB_SUB,"l3_delete");
	if ($table eq 'server'){
		db_dosql("SELECT id FROM interfaces WHERE host=$id");
		my @ifids; splice @ifids;
		while ((my $ifid)=db_getrow()){ push @ifids,$ifid; }
		db_close();
		for my $ifid (@ifids){
			db_dosql("DELETE FROM l2connect WHERE to_tbl='interfaces' and to_id=$ifid");
			db_close();
		}
		db_dosql("DELETE FROM interfaces WHERE host=$id");
		db_close();
	}
	my $sql = "DELETE FROM $table WHERE id=$id";  db_dosql($sql);
	db_close();
	l3_renew_content();
}
sub l3_move {
	(my $table, my $id, my $x, my $y)=@_;
	debug($DEB_SUB,"l3_move");
	my $sql;
	if ((defined($id)) && (defined($x)) && (defined ($y))){
		if ( $l3_showpage eq 'top'){
			$sql = "UPDATE $table SET xcoord=$x WHERE id=$id"; db_dosql($sql);db_close();
			$sql = "UPDATE $table SET ycoord=$y WHERE id=$id"; db_dosql($sql);db_close();
		}
		else {
			$sql = "UPDATE pages SET xcoord=$x WHERE item=$id AND tbl='$table' AND page='$l3_showpage'"; db_dosql($sql);db_close();
			$sql = "UPDATE pages SET ycoord=$y WHERE item=$id AND tbl='$table' AND page='$l3_showpage'"; db_dosql($sql);db_close();
		}
	}
}

sub l3_merge {
	(my $table, my $id, my $name, my $target)=@_;
	debug($DEB_SUB,"l3_merge");
	if ($table eq "server"){
		my $targetid=$id;
		if ($target =~/^(\d+\.\d+\.\d+\.\d+)/){
			my $sql = "SELECT host FROM interfaces WHERE ip='$1'";
			my $sth=db_dosql($sql);
			while((my $host) = db_getrow()){
				$targetid=$host;
			}
			db_close();
		}
		elsif ($target=~/^([A-Za-z]\w*)/){
			my $sql = "SELECT id FROM server WHERE name='$1'";
			my $sth =  db_dosql($sql);
			while((my $host) = db_getrow()){
				$targetid=$host;
			}
			db_close();
		}
		if ($targetid == $id){
			$Message="No valid target for merge\n";
		}
		else {
			my $sql = "SELECT id FROM interfaces WHERE host=$id";
			my $sth=db_dosql($sql);
			my @iflist;
			splice @iflist;
			while((my $ifid) = db_getrow()){
				push @iflist,$ifid;
			}
			db_close();
			foreach(@iflist){
				my $sql = "UPDATE interfaces SET host=$targetid WHERE id=$_";
				db_dosql($sql);
				db_close();
			}
			db_dosql("DELETE FROM server WHERE id=$id");db_close();
			db_dosql("DELETE FROM pages  WHERE item=$id AND tbl='server'");db_close();
		}
	}
	l3_renew_content();
}


1;
