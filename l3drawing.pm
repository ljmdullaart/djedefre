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
	put_netinobj($l3_showpage,\@l3_obj);
	put_serverinobj($l3_showpage,\@l3_obj,3);
	put_cloudinobj($l3_showpage,\@l3_obj);
}

my @l3_line;
sub l3_lines {
	debug($DEB_SUB,"l3_lines");
	my @interfacelist;
	splice @l3_line;

	my $Internet=q_subnet_id_by('nwaddress','Internet');
	my $Internetoptions=q_subnet('options',$Internet);
	my $Internetcolor='black';
	if ($Internetoptions=~/color=([^;]+);/){
		$Internetcolor=$1;
	}
	my $newInternet=$Internet*$qobjtypes+$objtsubnet;
	for my $i ( 0 .. $#l3_obj){
		if ($l3_obj[$i]->{'table'} eq 'server'){
			my $orig_id=$l3_obj[$i]->{'id'};
			my $obj_id=$l3_obj[$i]->{'newid'};
			@interfacelist=query_if_ip_by_host($orig_id);
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
	mgpg_selector_callback ($action,$arg,$page);
	l3_renew_content();
}

sub l3_color {
	(my $table, my $id, my $color)=@_;
	debug($DEB_SUB,"l3_color");
	if ($table eq 'subnet'){
		my $opts=q_subnet('options',$id);
		while ($opts=~/color=[^;]*;/){
			$opts=~s/color=[^;]*;//;
		}
		$opts="color=$color;$opts";
		q_subnet_update($id,'options',$opts);
	}
	l3_renew_content();
}
sub l3_devicetype {
	(my $table, my $id, my $type)=@_;
	debug($DEB_SUB,"l3_devicetype");
	if ($table eq 'server'){
		q_server_update($id,'devicetype',$type);
	}
	l3_renew_content();
}

#-----------------------------------------------------------------------
# Name        : l3_type
# Purpose     : Update the type of a server or cloud
# Arguments   : table - server or cloud
#		id
#               type
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub l3_type {
	(my $table, my $id, my $type)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_SUB,"l3_type $package, $filename, line number $line");
	if ($table eq 'server'){
		q_server_update($id,'type',$type);
	}
	elsif ($table eq 'cloud'){
		q_cloud_update($id,'type',$type);
	}
	l3_renew_content();
}
sub l3_name {
	(my $table, my $id, my $name)=@_;
	if ($table eq 'subnet'){ q_subnet_update($id,'name',$name);}
	if ($table eq 'server'){ q_server_update($id,'name',$name);}
	if ($table eq 'cloud' ){ q_cloud_update ($id,'name',$name);}
	l3_renew_content();
}
sub l3_delete {
	(my $table, my $id, my $name)=@_;
	debug($DEB_SUB,"l3_delete");
	if ($table eq 'server'){ query_delete_server($id) }
	elsif ($table eq 'subnet'){ query_delete_subnet($id) }
	elsif ($table eq 'cloud'){ query_delete_cloud($id) }
	elsif ($table eq 'switch'){ query_delete_switch($id) }
	else {
		print "ERROR: Delete for $table ($id, $name) is not implemented\n";
	}
	l3_renew_content();
}
sub l3_move {
	(my $table, my $id, my $x, my $y)=@_;
	debug($DEB_SUB,"l3_move");
	my $sql;
	if ((defined($id)) && (defined($x)) && (defined ($y))){
		if ( $l3_showpage eq 'top'){
			if ($table eq 'server'){ q_server_update ($id,'xcoord',$x,'ycoord',$y) }
			elsif ($table eq 'subnet'){ q_subnet_update($id,'xcoord',$x,'ycoord',$y) }
			elsif ($table eq 'cloud'){ q_cloud_update($id,'xcoord',$x,'ycoord',$y) }
			elsif ($table eq 'switch'){ q_switch_update($id,'xcoord',$x,'ycoord',$y) }
			else {
				print "ERROR: top move for $table ($id, $x,$y) is not implemented\n";
			}
		}
		else {
			my $pgid=q_page_id('tbl',$table,'item',$id,'page',$l3_showpage);
			q_page_update($pgid,'xcoord',$x,'ycoord',$y);
		}
	}
}

sub l3_merge {
	(my $table, my $id, my $name, my $target)=@_;
	debug($DEB_SUB,"l3_merge");
	if ($table eq "server"){
		my $targetid=$id;
		if ($target =~/^(\d+\.\d+\.\d+\.\d+)/){
			$targetid=query_if_id_by('ip',$1);
		}
		elsif ($target=~/^([A-Za-z]\w*)/){
			$targetid=q_server_id_by('name',$1);
		}
		if ($targetid == $id){
			$Message="No valid target for merge\n";
		}
		else {
			query_if_from_host($id);
			my @iflist;
			while (my $r=sql_getrow()){
				push @iflist,$r->{id};
			}
			foreach(@iflist){
				q_if_update($_,'host',$targetid);
			}
			query_delete_server($id);
		}
	}
	l3_renew_content();
}


1;
