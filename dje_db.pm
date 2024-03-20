#!/usr/bin/perl

#INSTALL@ /opt/djedefre/dje_db.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
use DBI;

our $DEBUG;
our $DEB_DB;
our $DEB_FRAME;
our $DEB_SUB;
our $Message;
our $button_frame;
our $buttonframe;
our $l2_showpage;
our $l3_showpage;
our $locked;
our $main_frame;
our $main_window;
our $main_window_height;
our $main_window_width;
our $mainframe;
our $repeat_sub;
our %config;
our %nw_logos;
our %pagetypes;
our %srv_id;
our @colors;
our @devicetypes;
our @if_access;
our @if_host;
our @if_hostname;
our @if_name;
our @if_name;
our @if_id;
our @if_ip;
our @if_macid;
our @if_port;
our @if_subnet;
our @if_switch;
our @l2_from_id;
our @l2_from_port;
our @l2_from_tbl;
our @l2_to_id;
our @l2_to_port;
our @l2_to_tbl;
our @l2_vlan;
our @logolist;
our @net_access;
our @net_cidr;
our @net_name;
our @net_nwaddress;
our @net_options;
our @net_xcoord;
our @net_ycoord;
our @pagelist;
our @realpagelist;
our @srv_devicetype;
our @srv_interfaces;
our @srv_last_up;
our @srv_memory;
our @srv_name;
our @srv_options;
our @srv_os;
our @srv_ostype;
our @srv_processor;
our @srv_status;
our @srv_type;
our @srv_xcoord;
our @srv_ycoord;



#      _       _	_
#   __| | __ _| |_ __ _| |__   __ _ ___  ___
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
#

my $db;
my $db_sth;
my $db_error=0;

sub connect_db {
	(my $dbfile)=@_;
	debug($DEB_SUB,"connect_db");
	$db = DBI->connect("dbi:SQLite:dbname=".$dbfile)
		or die $DBI::errstr;
	$db_error=0;
	return $db;
}


sub db_dosql{
	(my $sql)=@_;
	debug($DEB_SUB,"db_dosql \"$sql\"");
	if ($db_sth = $db->prepare($sql)){
		$db_sth->execute();
		$db_error=0;
		return 0;
	}
	else { 
		print "Prepare failed for $sql\n";
		$db_error=1;
		return 1;
	}
}

my $NDB=0;
sub db_getrow {
	my @row;
	if ($db_error==1){
		return ();
	}
	elsif (@row = $db_sth->fetchrow()){
		return @row;
	}
	else {
		return ();
	}
}


sub db_get_interfaces {
	debug($DEB_SUB,"db_get_interfaces");
	splice @if_id;
	splice @if_macid;
	splice @if_ip;
	splice @if_hostname;
	splice @if_name;
	splice @if_host;
	splice @if_subnet;
	splice @if_access;
	splice @if_switch;
	splice @if_port;
	db_dosql("SELECT id,macid,ip,hostname,host,subnet,access,connect_if,port,ifname FROM interfaces");
	while (( my $id,my $macid,my $ip,my $hostname,my $host,my $subnet,my $access,my $switch,my $port,my $ifname)=db_getrow()){
		$if_id[$id]=$id;
		$if_macid[$id]=$macid;
		$if_ip[$id]=$ip;
		$if_hostname[$id]=$hostname;
		$if_name[$id]=$ifname;
		$if_host[$id]=$host;
		$if_subnet[$id]=$subnet;
		$if_access[$id]=$access;
		$if_switch[$id]=$switch;
		$if_port[$id]=$port;
	}
}

sub db_get_subnet {
	debug($DEB_SUB,"db_get_subnet");
	splice @net_nwaddress;
	splice @net_cidr;
	splice @net_xcoord;
	splice @net_ycoord;
	splice @net_name;
	splice @net_options;
	splice @net_access;
	db_dosql("SELECT id, nwaddress, cidr, xcoord, ycoord, name, options, access FROM subnet");
	while ((my $id,my $nwaddress,my $cidr,my $xcoord,my $ycoord,my $name,my $options,my $access)=db_getrow()){
		$net_nwaddress[$id]=$nwaddress;
		$net_cidr[$id]=$cidr;
		$net_xcoord[$id]=$xcoord;
		$net_ycoord[$id]=$ycoord;
		$net_name[$id]=$name;
		$net_options[$id]=$options;
		$net_access[$id]=$access;
	}
}
	

sub db_get_server {
	debug($DEB_SUB,"db_get_server");
	splice @srv_name;
	splice @srv_xcoord;
	splice @srv_ycoord;
	splice @srv_type;
	splice @srv_interfaces;
	splice @srv_devicetype;
	splice @srv_status;
	splice @srv_last_up;
	splice @srv_options;
	splice @srv_ostype;
	splice @srv_os;
	splice @srv_processor;
	splice @srv_memory;
	db_dosql("SELECT id, name, xcoord, ycoord, type, interfaces, devicetype, status, last_up, options, ostype, os, processor, memory FROM server");

	while ((my $id,my $name,my $xcoord,my $ycoord,my $type,my $interfaces,my $devicetype,my $status,my $last_up,my $options,my $ostype,my $os,my $processor,my $memory)=db_getrow()){
		$srv_name[$id]=$name;
		$srv_xcoord[$id]=$xcoord;
		$srv_ycoord[$id]=$ycoord;
		$srv_type[$id]=$type;
		$srv_interfaces[$id]=$interfaces;
		$srv_devicetype[$id]=$devicetype;
		$srv_status[$id]=$status;
		$srv_last_up[$id]=$last_up;
		$srv_options[$id]=$options;
		$srv_ostype[$id]=$ostype;
		$srv_os[$id]=$os;
		$srv_processor[$id]=$processor;
		$srv_memory[$id]=$memory;
		$srv_id{$name}=$id;
	}
}


sub db_get_l2 {
	debug($DEB_SUB,"db_get_l2");
	splice @l2_vlan;
	splice @l2_from_tbl;
	splice @l2_from_id;
	splice @l2_from_port;
	splice @l2_to_tbl;
	splice @l2_to_id;
	splice @l2_to_port;
	db_dosql("SELECT id,vlan,from_tbl,from_id,from_port,to_tbl,to_id,to_port FROM l2connect");
	while ((my $id,my $vlan,my $from_tbl,my $from_id,my $from_port,my $to_tbl,my $to_id,my $to_port)=db_getrow()){
		$l2_vlan[$id]=$vlan;
		$l2_from_tbl[$id]=$from_tbl;
		$l2_from_id[$id]=$from_id;
		$l2_from_port[$id]=$from_port;
		$l2_to_tbl[$id]=$to_tbl;
		$l2_to_id[$id]=$to_id;
		$l2_to_port[$id]=$to_port;
	}
}

1;
