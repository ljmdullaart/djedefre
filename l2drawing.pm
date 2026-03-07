#INSTALL@ /opt/djedefre/l2drawing.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);

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

our $l2_showpage;
our $repeat_sub;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;
our $Message;

my @l2_obj;
my $nw_tmpx=100;
my $nw_tmpy=100;
my $qobjtypes=4;
my $objtsubnet=0;
my $objtserver=1;
my $objtswitch=2;
my $objtcloud=3;




sub l2_objects {
	debug($DEB_SUB,"l2_objects");
	splice @l2_obj;
	put_netinobj($l2_showpage,\@l2_obj);
	put_serverinobj($l2_showpage,\@l2_obj,2);
	put_cloudinobj($l2_showpage,\@l2_obj);
	put_switchinobj($l2_showpage,\@l2_obj);

}

my @l2_line;
sub l2_lines {
	debug($DEB_SUB,"l2_lines");
	my @interfacelist;
	splice @l2_line;

	my @ifserver;
	my @serverif;
	my %colorization;
	query_config();
	while (my $r=sql_getrow()){
		if ($r->{attribute} eq 'line:color'){
			$colorization{$r->{item}}=$r->{value};
		}
	}
	query_interfaces();
	while (my $r=sql_getrow()){
		$ifserver[$r->{id}]=$r->{host};
		$serverif[$r->{host}]=$r->{id};
	}
	my $Internet=q_subnet_id_by('nwaddress','Internet');
	my $Internetoptions=q_subnet('options',$Internet);
	my $Internetcolor='black';
	if ($Internetoptions=~/color=([^;]+);/){
		$Internetcolor=$1;
	}
	my $newInternet=$Internet*$qobjtypes+$objtsubnet;
	my $linefrom=0;
	my $lineto=0;
	query_l2();
	while (my $r=sql_getrow()){
		(my$id,my $vlan,my $from_tbl,my $from_id,my $from_port,my $to_tbl,my $to_id,my $to_port)=
		    ($r->{id},$r->{vlan},$r->{from_tbl},$r->{from_id},$r->{from_port},$r->{to_tbl},$r->{to_id},$r->{to_port});
		$vlan=0 unless defined $vlan;
		$to_port = ( defined($to_port) && $to_port ne "" && looks_like_number($to_port) && $to_port <= 1000 ) ? $to_port : "";
		$from_port = ( defined($from_port) && $from_port ne "" && looks_like_number($from_port) && $from_port <= 1000 ) ? $from_port : "";
		if ($from_tbl eq 'interfaces'){
			my $host=$ifserver[$from_id];
			$linefrom=$host*$qobjtypes+$objtserver
		}
		elsif ($from_tbl eq 'server'){
			$linefrom=$from_id*$qobjtypes+$objtserver
		}
		elsif ($from_tbl eq 'switch'){
			$linefrom=$from_id*$qobjtypes+$objtswitch
		}
		if ($to_tbl eq 'interfaces'){
			my $host=$ifserver[$to_id];
			$lineto=$host*$qobjtypes+$objtserver
		}
		elsif ($to_tbl eq 'switch'){
			$lineto=$to_id*$qobjtypes+$objtswitch
		}
		elsif ($to_tbl eq 'server'){
			$lineto=$to_id*$qobjtypes+$objtserver
		}
		if ($linefrom*$lineto>0){
			if ($vlan>1){
				push @l2_line,{
					from    => $linefrom,
					to      => $lineto,
					fromlabel=>"$from_port:vlan $vlan",
					tolabel	=> "$to_port:vlan $vlan",
					type    => 'black',
				}
			}
			else {
				push @l2_line,{
					from    => $linefrom,
					to      => $lineto,
					fromlabel=>$from_port,
					tolabel	=> $to_port,
					type    => 'black',
				}
			}
		}
	}
}
					
my $l2_plot_frame;

sub l2_renew_content {
	debug($DEB_SUB,"l2_renew_content");
	l2_objects('top');
	l2_lines();
	nw_del_objects(@l2_obj);
	nw_del_lines(@l2_line);
	nw_objects(@l2_obj);
	nw_lines(@l2_line);
}
our $drawingname;
sub make_l2_plot {
	(my $parent)=@_;
	$drawingname='connections';
	debug($DEB_SUB,"make_l2_plot");
	$l2_plot_frame->destroy if Tk::Exists($l2_plot_frame);
	debug ($DEB_FRAME,"1 Create l2_plot_frame");
	$l2_plot_frame=$parent->Frame()->pack(-side=>'left');
	l2_renew_content();
	nw_frame($l2_plot_frame);
	nw_callback ('color',\&l2_color);
	nw_callback ('delete',\&l2_delete);
	nw_callback ('devicetype',\&l2_devicetype);
	nw_callback ('merge',\&l2_merge);
	nw_callback ('move',\&l2_move);
	nw_callback ('name',\&l2_name);
	nw_callback ('page',\&l2_page);
	nw_callback ('type',\&l2_type);
	#nw_drawall();
}
#sub cbdump {
#	print "----Djedefre2-callback-dumper-----\n";
#	print Dumper @_;
#	print "----------------------------------\n";
#}
sub l2_page {
	(my $table,my $id,my $name,my $action,my $page)=@_;
	debug($DEB_SUB,"l2_page");
	my $arg="$table:$id:$name";
	mgpg_selector_callback ($action,$arg,$page);
	l2_renew_content();
}

sub l2_color {
	(my $table, my $id, my $color)=@_;
	debug($DEB_SUB,"l2_color");
	if ($table eq 'subnet'){
		my $opts=q_subnet('options',$id); 
		while ($opts=~/color=[^;]*;/){
			$opts=~s/color=[^;]*;//;
		}
		$opts="color=$color;$opts";
		q_subnet_update ($id,'options',$opts);
	}
	l2_renew_content();
}
sub l2_devicetype {
	(my $table, my $id, my $type)=@_;
	debug($DEB_SUB,"l2_devicetype");
	if ($table eq 'server'){
		q_server_update($id,'devicetype',$type);
	}
	l2_renew_content();
}
sub l2_type {
	(my $table, my $id, my $type)=@_;
	debug($DEB_SUB,"l2_type");
	if ($table eq 'server'){
		q_server_update($id,'type',$type);
	}
	elsif ($table eq 'cloud'){
		q_cloud_update ($id,'type',$type);
	}
	l2_renew_content();
}
sub l2_name {
	(my $table, my $id, my $name)=@_;
	debug($DEB_SUB,"l2_name");
	if ($table eq 'server'){ q_server_update($id,'name',$name);}
	elsif ($table eq 'subnet'){ q_subnet_update($id,'name',$name);}
	elsif ($table eq 'cloud'){ q_cloud_update($id,'name',$name);}
	else { print "ERROR l2_name $table unsupported\n";}
	l2_renew_content();
}
sub l2_delete {
	(my $table, my $id, my $name)=@_;
	debug($DEB_SUB,"l2_delete");
	if ($table eq 'server'){
		query_delete_server($id);
	}
	else { print "ERROR l2_delete table unsupported\n";}
	l2_renew_content();
}
sub l2_move {
	(my $table, my $id, my $x, my $y)=@_;
	debug($DEB_SUB,"l2_move");
	my $sql;
	if ((defined($id)) && (defined($x)) && (defined ($y))) {
		my $idonpg=q_page_id('item',$id,'tbl',$table,'page',$l2_showpage);
		q_page_update($idonpg,'xcoord',$x,'ycoord',$y);
	}
}

sub l2_merge {
	(my $table, my $id, my $name, my $target)=@_;
	debug($DEB_SUB,"l2_merge");
	if ($table eq "server"){
		my $targetid=$id;
		if ($target =~/^(\d+\.\d+\.\d+\.\d+)/){
			my $ifid=query_if_id_by('ip',$1);
			$targetid=q_interfaces('host',$ifid);
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
	l2_renew_content();
}


1;
