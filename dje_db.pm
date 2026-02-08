#!/usr/bin/perl

#INSTALL@ /opt/djedefre/dje_db.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
use DBI;
use strict;
use warnings;



#      _       _        _                                          
#   __| | __ _| |_ __ _| |__   __ _ ___  ___   _ __   _____      __
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \ | '_ \ / _ \ \ /\ / /
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/ | | | |  __/\ V  V / 
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___| |_| |_|\___| \_/\_/  
#    
our $DEBUG;
our $DEB_DB;
our $DEB_FRAME;
our $DEB_SUB;

our $Message;

our %config;

my @lastresult;

#-----------------------------------------------------------------------
# Name        : sql_query
# Purpose     : Execute an SQL query on the SQLite database and return
#               all result rows as an arrayref of hashrefs.
# Arguments   : ($query, @bind_values)
#               $query        - SQL statement with placeholders
#               @bind_values  - values to bind to the placeholders
# Returns     : Arrayref of hashrefs (one hashref per row)
# Globals     : $dbfile (database filename)
#               @lastresult (overwritten with new results)
# Side-effects: Opens and closes the database connection.
#               Replaces contents of @lastresult.
# Notes       : Uses prepared statements. Dies on DB errors.
#-----------------------------------------------------------------------
sub sql_query {
	my ($query, @bind_values) = @_;
	my $dbfile=$config{'dbfile'};
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"sql_query  $package, $filename, line number $line using $dbfile");
	my $db = DBI->connect(
		"dbi:SQLite:dbname=$dbfile",
		"",
		"",
		{ RaiseError => 1, AutoCommit => 1 }
	) or die "Cannot open database $dbfile: $DBI::errstr";

	my $sth = $db->prepare($query);
	$sth->execute(@bind_values);
	my $rows = $sth->fetchall_arrayref({});
	@lastresult = @$rows;
	$sth->finish;
	$db->disconnect;
	return \@lastresult;
}

#-----------------------------------------------------------------------
# Name        : sql_getrow
# Purpose     : Return the next row from @lastresult and remove it.
# Arguments   : none
# Returns     : Hashref representing one row, or undef if no rows left.
# Globals     : @lastresult
# Side-effects: Removes one row from @lastresult (FIFO).
# Notes       : Intended to be used after db_query has populated results.
#-----------------------------------------------------------------------
sub sql_getrow {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"sql_getrow $package, $filename, line number $line");
	return undef unless @lastresult;
	my $row = shift @lastresult;
	return $row;
}

#-----------------------------------------------------------------------
# Name        : sql_getvalue
# Purpose     : Return a single value from the next row in @lastresult.
# Arguments   : none
# Returns     : Scalar value from the row, or undef if no rows left.
# Globals     : @lastresult
# Side‑effects: Removes one row from @lastresult.
# Notes       : If multiple columns exist, any column may be returned.
#-----------------------------------------------------------------------

sub sql_getvalue {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"sql_getvalue  $package, $filename, line number $line");
	return undef unless @lastresult;
	my $row = shift @lastresult;
	return undef unless $row && %$row;
	my ($value) = values %$row;
	return $value;
}

#   __ _              _                         _           
#  / _(_)_  _____  __| |   __ _ _   _  ___ _ __(_) ___  ___ 
# | |_| \ \/ / _ \/ _` |  / _` | | | |/ _ \ '__| |/ _ \/ __|
# |  _| |>  <  __/ (_| | | (_| | |_| |  __/ |  | |  __/\__ \
# |_| |_/_/\_\___|\__,_|  \__, |\__,_|\___|_|  |_|\___||___/
#                            |_|   

# All queries are centralised here below. This is to facilitate 
# a possible change of database.

#         _
# _ _  __|_. _  _|_ _ |_ | _  
#(_(_)| || |(_|  |_(_||_)|(/_ 
#            _|               
#

#-----------------------------------------------------------------------
# Name        : query_changed_no
# Purpose     : Sets the value of changed to no in the config table
# Arguments   : none
# Returns     : 'no'
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------

sub query_changed_no {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_changed_no $package, $filename, line number $line");
	sql_query ("SELECT value FROM config WHERE attribute='run:param' AND item='changed'");
	if (sql_getvalue()){
		sql_query ("UPDATE config SET value='no' WHERE attribute='run:param' AND item='changed'");
	}
	else {
		sql_query("INSERT INTO config (attribute,item,value) values('run:param','changed','no')");
	}
	return 'no';
}


#-----------------------------------------------------------------------
# Name        : query_line_color
# Purpose     : Copies the line colors from the database to the config hash
# Arguments   : none
# Returns     : 
# Globals     : @lastresult, %config
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_line_color {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_line_color $package, $filename, line number $line");
	sql_query ("SELECT item,value FROM config WHERE attribute='line:color'");
	while (my $row = sql_getrow()) {
		my $item=$row->{item};
		my $value=$row->{value};
		$config{"line:color:$item"}=$value;
	}
	
}

#-----------------------------------------------------------------------
# Name        : query_set_line_color
# Purpose     : Sets the color for a specific purpose
# Arguments   : colorname (e.g. vlan1, vbox)
#               colorvalue (e.g. black, blue, lightgrey
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_set_line_color {
	(my $colorname, my $colorvalue)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_set_line_color $package, $filename, line number $line");
	sql_query ("DELETE FROM config WHERE attribute='line:color' AND item= ? ",$colorname);
	sql_query ("INSERT INTO config (attribute,item,value) VALUES ('line:color', ? , ? )",$colorname,$colorvalue);
}


#    _   _  _          _  ____ 
# |   ) /  / \|\ ||\ ||_ /  |  
# |_ /_ \_ \_/| \|| \||_ \_ |  
#                          


#-----------------------------------------------------------------------
# Name        : query_l2_getvlans
# Purpose     : Get the list of VLANs in the l2 connection table
# Arguments   : 
# Returns     : array refference to a list of VLANs
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_getvlans {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_getvlans $package, $filename, line number $line");
	my $rows = sql_query("SELECT DISTINCT vlan FROM l2connect");
	my @vlans = map { $_->{vlan} } @$rows;
	return \@vlans;
}

#
# _ | _     _| 
#(_ |(_)|_|(_| 
#             

#-----------------------------------------------------------------------
# Name        : query_cloud_del_name
# Purpose     : Delete a cloud by name
# Arguments   : $name: the name of the cloud
# Returns     : array refference to a list of VLANs
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_cloud_del_name {
	(my $name)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_cloud_del_name $package, $filename, line number $line");
	sql_query("DELETE FROM cloud WHERE name= ? ",$name);
}

#-----------------------------------------------------------------------
# Name        : query_cloud_add_a_cloud
# Purpose     : Add a cloud
# Arguments   : cloud_name
#		vendor
#		type
#		service
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_cloud_add_a_cloud {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_cloud_add_a_cloud $package, $filename, line number $line");
	sql_query("INSERT INTO cloud (name,vendor,type,service) VALUES ( ? . ? , ? , ? )",@_);
}

#-----------------------------------------------------------------------
# Name        : query_cloud_update_type
# Purpose     : Update the type of a cloud
# Arguments   : id
#		type
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_cloud_update_type {
	(my $id, my $type)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_cloud_update_type $package, $filename, line number $line");
	sql_query("UPDATE cloud SET type= ? WHERE id= ? ",$type,$id);
}

# __  _  _      _  _  
#(_  |_ |_)\  /|_ |_) 
#__) |_ | \ \/ |_ | \ 
#

#-----------------------------------------------------------------------
# Name        : query_server_update_type
# Purpose     : Update the type of a server
# Arguments   : id
#		type
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_server_update_type {
	(my $id, my $type)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_server_update_type $package, $filename, line number $line");
	sql_query("UPDATE server SET type= ? WHERE id= ? ",$type,$id);
}

# _     _     _ ___
#(_ | ||_)|\||_  |  
# _)|_||_)| ||_  |  
#


#-----------------------------------------------------------------------
# Name        : query_subnet_on_page
# Purpose     : Initiate query for subbnets on a page
# Arguments   : page
# Returns     : 
# Globals     : @lastresult
# Side‑effects: 
# Notes       : Results must be obtained using sql_getrow()
#-----------------------------------------------------------------------
sub query_subnet_on_page {
	(my $page)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_subnet_on_page $package, $filename, line number $line");
	my $sql;
	if ($page eq 'top'){
		sql_query('SELECT id,nwaddress,cidr,xcoord,ycoord,name,options FROM subnet');
	}
	else {
		sql_query ("	SELECT subnet.id,nwaddress,cidr,pages.xcoord,pages.ycoord,name,subnet.options
				FROM   subnet
				INNER JOIN pages ON pages.item = subnet.id
				WHERE  pages.page= ? AND pages.tbl='subnet'
			", $page);
	}
}
		

#  _     __  _  _  
# |_)/\ /__ |_ (_  
# | /--\\_| |_  _) 
# 

#-----------------------------------------------------------------------
# Name        : query_pages_tbl_id
# Purpose     : Initiate query for page list of an object
# Arguments   : table (e.g. subnet or server)
#		id
# Returns     : 
# Globals     : @lastresult
# Side‑effects: 
# Notes       : Results must be obtained using sql_getvalue()
#-----------------------------------------------------------------------
sub query_pages_tbl_id {
	(my $table,my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_pages_tbl_id $package, $filename, line number $line");
	sql_query("SELECT page FROM pages WHERE tbl= ? AND item= ?",$table,$id);
}






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
our @pagelist;
our @realpagelist;
our $package;
our $filename;
our $line;

our %nw_logos;
our %pagetypes;
our @colors;
our @devicetypes;
our @logolist;

our @if_access;
our @if_host;
our @if_hostname;
our @if_name;
our @if_ifname;
our @if_id;
our @if_ip;
our @if_macid;
our @if_port;
our @if_subnet;
our @if_switch;
our @if_connect_if;

our @l2_id;
our @l2_from_id;
our @l2_from_port;
our @l2_from_tbl;
our @l2_to_id;
our @l2_to_port;
our @l2_to_tbl;
our @l2_vlan;
our @l2_source;

our @net_access;
our @net_cidr;
our @net_name;
our @net_nwaddress;
our @net_options;
our @net_xcoord;
our @net_ycoord;

our %srv_id;
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

our @sw_switch;
our @sw_server;
our @sw_name;
our @sw_ports;
our %sw_id;

#      _       _	_
#   __| | __ _| |_ __ _| |__   __ _ ___  ___
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
#

my $db;
my $db_sth;
my $db_error=0;

my $database_open=0;

sub connect_db {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"executing connect_db $package, $filename, $line");
	(my $dbfile)=@_;
	# debug(2,"Opening database $package, $filename, line number $line");
	
	debug($DEB_SUB,"connect_db");
	$db = DBI->connect("dbi:SQLite:dbname=".$dbfile)
		or die $DBI::errstr;
	$db_error=0;
	$database_open=1;
	return $db;
}


sub db_dosql{
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"executing db_dosql $package, $filename, $line");
	(my $sql)=@_;
	debug($DEB_SUB,"db_dosql \"$sql\"");
	if ($database_open==0){
		connect_db($config{'dbfile'});
		$database_open=1;
	}
	else {
		
		debug($DEB_DB,"Someone left the database open before $package, $filename, line number $line");
		db_close();
		connect_db($config{'dbfile'});
	}
	
	if ($db_sth = $db->prepare($sql)){
		$db_sth->execute();
		$db_error=0;
		return 0;
	}
	else { 
		debug($DEB_DB,"Prepare failed for $sql");
		$db_error=1;
		return 1;
	}
}

my $NDB=0;
sub db_getrow {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"executing db_getrow $package, $filename, $line");
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

sub db_value {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"executing db_value $package, $filename, $line");
	(my $sql)=@_;
	my @row;
	if ($database_open==0){
		connect_db($config{'dbfile'});
		$database_open=1;
	}
	else {
		debug($DEB_DB,"Someone left the database open before $package, $filename, line number $line");
		db_close();
		connect_db($config{'dbfile'});
	}
	debug($DEB_SUB,"db_value \"$sql\"");
	if ($db_sth = $db->prepare($sql)){
		$db_sth->execute();
		if (@row = $db_sth->fetchrow()){
			return $row[0];
		}
		else {
			debug($DEB_DB,"Empty row for $sql");
			return undef;
		}
		db_close();
	}
	else { 
		debug($DEB_DB,"Prepare failed for $sql");
		return undef;
	}
}

sub db_close {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"executing db_close $package, $filename, $line");
	if (defined ($db_sth)){
		if ($db_sth->{Active}){
			debug($DEB_DB,"db_close called with open statement handler from $filename, line: $line");
		}
	}
	if ($database_open==1){
		$db->disconnect() if defined $db;
		$database_open=0;
	}
}


sub db_get_interfaces {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"executing db_get_interfaces $package, $filename, $line");
	debug($DEB_SUB,"db_get_interfaces");
	splice @if_id;
	splice @if_macid;
	splice @if_ip;
	splice @if_hostname;
	splice @if_name;
	splice @if_ifname;
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
		$if_host[$id]=$host;
		$if_subnet[$id]=$subnet;
		$if_access[$id]=$access;
		$if_connect_if[$id]=$switch;
		$if_port[$id]=$port;
		$if_ifname[$id]=$ifname;
		$if_name[$id]=$ifname;
	}
	db_close;
}

sub db_get_subnet {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"executing db_get_subnet $package, $filename, $line");
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
	db_close;
}
	

sub db_get_server {
	my ($package, $filename, $line) = caller;
	debug(2,"executing db_get_server $package, $filename, $line");
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
	db_close;
}


sub db_get_l2 {
	my ($package, $filename, $line) = caller;
	debug(2,"executing db_get_l2 $package, $filename, $line");
	debug($DEB_SUB,"db_get_l2");
	splice @l2_id;
	splice @l2_vlan;
	splice @l2_from_tbl;
	splice @l2_from_id;
	splice @l2_from_port;
	splice @l2_to_tbl;
	splice @l2_to_id;
	splice @l2_to_port;
	db_dosql("SELECT id,vlan,from_tbl,from_id,from_port,to_tbl,to_id,to_port,source FROM l2connect");
	while ((my $id,my $vlan,my $from_tbl,my $from_id,my $from_port,my $to_tbl,my $to_id,my $to_port,my $source)=db_getrow()){
		$l2_id[$id]=$id;
		$l2_vlan[$id]=$vlan;
		$l2_from_tbl[$id]=$from_tbl;
		$l2_from_id[$id]=$from_id;
		$l2_from_port[$id]=$from_port;
		$l2_to_tbl[$id]=$to_tbl;
		$l2_to_id[$id]=$to_id;
		$l2_to_port[$id]=$to_port;
		$l2_source[$id]=$source;
	}
	db_close;
}


sub db_get_sw {
	my ($package, $filename, $line) = caller;
	debug(2,"executing db_get_sw $package, $filename, $line");
	splice @sw_switch;
	splice @sw_server;
	splice @sw_name;
	splice @sw_ports;
	db_dosql("SELECT id,switch,server,name,ports FROM switch");
	while ((my $id,my $switch,my $server,my $name,my $ports)=db_getrow()){
		$sw_switch[$id]=$switch;
		$sw_server[$id]=$server;
		$sw_name[$id]=$name;
		$sw_ports[$id]=$ports;
		$sw_id{$name}=$id;
	}
	db_close;
}
		

1;
