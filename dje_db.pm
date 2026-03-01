#!/usr/bin/perl

#INSTALL@ /opt/djedefre/dje_db.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
use DBI;
use strict;
use warnings;


#
# Prefixes:
# sql_     Get results from the database
# query_   Do a standard query; all queries should be centralized to improve 
#          portablility across databases.
# q_       Get a value from a table, always by ID without using @lastresult.
# db_      Old databas access; in the process of being removed.


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
# Name        : sql_qvalue
# Purpose     : Return a single value from the database
# Arguments   : query, bind values
# Returns     : the requested value or undef
# Globals     : 
# Side-effects: 
# Notes       : The sub does not use @results and can therefore be used
#               in a loop over @results.
#-----------------------------------------------------------------------
sub sql_qvalue{
	my ($query, @bind) = @_;
	my $dbfile=$config{'dbfile'};
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"sql_query  $package, $filename, line number $line using $dbfile");
	my $db = DBI->connect(
		"dbi:SQLite:dbname=$dbfile",
		"",
		"",
		{ RaiseError => 1, AutoCommit => 1 }
	) or die "Cannot open database $dbfile: $DBI::errstr";
	my ($value) = $db->selectrow_array($query, undef, @bind);
	$db->disconnect;
	return $value;
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
	my $value = (values %$row)[0];
	$value='-' unless defined $value;
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

#  __  _       _  _          
# /__ |_ |\ | |_ |_)  /\  |  
# \_| |_ | \| |_ | \ /--\ |_ 
#   (queries for multiple tables)
#-----------------------------------------------------------------------
# Name        : query_coordinates
# Purpose     : Get the x and y coordinates of an object
# Arguments   : page, table, id
# Returns     : array with x and y coordinates
# Globals     : @lastresult
# Side‑effects: 
# Notes       : Results must be obtained using sql_getrow()
#-----------------------------------------------------------------------
sub query_coordinates {
	(my $page,my $tbl,my $id)=@_;
	my  %allowed_tables = (
		cloud	=> 1,
		server	=> 1,
		subnet	=> 1,
		switch	=> 1
	);
	my @retval=();
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_coordinates $package, $filename, line number $line page=$page tbl=$tbl");
	if ($allowed_tables{$tbl}) {
		if ($page eq 'top'){
			$retval[0]=sql_qvalue("SELECT xcoord FROM $tbl WHERE id=$id");
			$retval[1]=sql_qvalue("SELECT ycoord FROM $tbl WHERE id=$id");
		}
		else {
			$retval[0]=sql_qvalue ("SELECT xcoord FROM pages WHERE page= ? AND tbl= ? AND item= ? ",$page,$tbl,$id);
			$retval[1]=sql_qvalue ("SELECT ycoord FROM pages WHERE page= ? AND tbl= ? AND item= ? ",$page,$tbl,$id);
		}
	}
	return @retval;
}


#         _
# _ _  __|_. _  _|_ _ |_ | _  
#(_(_)| || |(_|  |_(_||_)|(/_ 
#            _|               
#

#-----------------------------------------------------------------------
# Name        : q_config
# Purpose     : Query the value of an attribute, item
# Arguments   : attribute, item
# Returns     : The value
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------

sub q_config {
	(my $attr,my $item)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"q_config $package, $filename, line number $line");
	my $retval=sql_qvalue ("SELECT value FROM config WHERE attribute= ? AND item= ? ",$attr,$item);
	return $retval;
}

#-----------------------------------------------------------------------
# Name        : q_changed
# Purpose     : Query the value of changed; always set it to no
# Arguments   : none
# Returns     : The value of changed
# Globals     : 
# Side‑effects: After query, it is always set to 'no'
# Notes       : 
#-----------------------------------------------------------------------

sub q_changed {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"q_changed$package, $filename, line number $line");
	my $retval=sql_qvalue ("SELECT value FROM config WHERE attribute='run:param' AND item='changed'");
	sql_qvalue ("UPDATE config SET value='no' WHERE attribute='run:param' AND item='changed'");
	return $retval;
}
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
# Name        : query_pagelist
# Purpose     : Gets a list of pages from the config table
# Arguments   : none
# Returns     : 
# Globals     : @lastresult
# Side‑effects: 
# Notes       :  item,value must be retrieved with sql_getrow() 
#-----------------------------------------------------------------------
sub query_pagelist {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_pagelist $package, $filename, line number $line");
	sql_query ("SELECT DISTINCT item,value FROM config WHERE attribute LIKE 'page:%'");
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

#-----------------------------------------------------------------------
# Name        : query_set_pagetype
# Purpose     : Sets the color for a specific purpose
# Arguments   : page
#               type
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_set_pagetype {
	(my $page, my $type)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_set_pagetype $package, $filename, line number $line");
	sql_query ("DELETE FROM config WHERE attribute='page:type' AND item= ? ",$page);
	sql_query ("INSERT INTO config (attribute,item,value) VALUES ('page:type', ? , ? )",$page,$type);
}

#
# _ | _     _| 
#(_ |(_)|_|(_| 
#             

#-----------------------------------------------------------------------
# Name        : query_delete_cloud
# Purpose     : Delete a cloud by id
# Arguments   : ID
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_delete_cloud {
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_cloud_delete $package, $filename, line number $line");
	sql_query("DELETE FROM cloud WHERE id= ? ",$id);
}
#-----------------------------------------------------------------------
# Name        : query_cloud_del_name
# Purpose     : Delete a cloud by name
# Arguments   : $name: the name of the cloud
# Returns     : 
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
#-----------------------------------------------------------------------
# Name        : q_cloud_update
# Purpose     : Update a column in the cloud table
# Arguments   : id, column,value
# Returns     : requested value
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_cloud_update {
	my ($id, %updates) = @_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		xcoord     => 1,
		ycoord     => 1,
		type       => 1,
		vendor     => 1,
		service    => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	return unless defined $id;
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			sql_qvalue("UPDATE cloud SET $var = ?  WHERE id= ? ",$val, $id);
		}
	}
}

#-----------------------------------------------------------------------
# Name        : query_cloud_from_id
# Purpose     : Get the cloud from the ID
# Arguments   : cloud-id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getrow
#-----------------------------------------------------------------------
sub query_cloud_from_id {
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_cloud_from_id $package, $filename, line number $line");
	sql_query("SELECT * FROM cloud WHERE id = ? ",$id);
}

#-----------------------------------------------------------------------
# Name        : query_cloud_from_name
# Purpose     : Get the cloud from the name
# Arguments   : cloud-name
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getrow
#-----------------------------------------------------------------------
sub query_cloud_from_name {
	(my $name)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_cloud_from_name $package, $filename, line number $line");
	sql_query("SELECT * FROM cloud WHERE name = ? ",$name);
}

#-----------------------------------------------------------------------
# Name        : query_cloud
# Purpose     : Get the clouds
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getrow
#-----------------------------------------------------------------------
sub query_cloud{
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_cloud $package, $filename, line number $line");
	sql_query("SELECT * FROM cloud");
}
#  _        __      _   _        _   _  
# | \  /\  (_  |_| |_) / \  /\  |_) | \ 
# |_/ /--\ __) | | |_) \_/ /--\ | \ |_/ 
#   
#-----------------------------------------------------------------------
# Name        : query_dashboard
# Purpose     : Get the dashboard
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getrow
#-----------------------------------------------------------------------
sub query_dashboard{
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_dashboard $package, $filename, line number $line");
	sql_query("SELECT * FROM dashboard");
}
#-----------------------------------------------------------------------
# Name        : query_dashboard_servers
# Purpose     : Get the the servers  from the dashboard
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getvalue
#-----------------------------------------------------------------------
sub query_dashboard_servers{
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_dashboard_servers $package, $filename, line number $line");
	sql_query("SELECT DISTINCT server FROM dashboard");
}

# ___      ___  _  _   _       _  _  __ 
#  |  |\ |  |  |_ |_) |_  /\  /  |_ (_  
# _|_ | \|  |  |_ | \ |  /--\ \_ |_ __) 
#
#-----------------------------------------------------------------------
# Name        : query_if_from_host
# Purpose     : Get all interfaces belonging to a host
# Arguments   : host-id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getrow
#-----------------------------------------------------------------------
sub query_if_from_host {
	(my $hostid)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_if_from_host $package, $filename, line number $line");
	sql_query("SELECT * FROM interfaces WHERE host= ? ",$hostid);
}
#-----------------------------------------------------------------------
# Name        : query_if_ip_by_host
# Purpose     : Get all IP-addresses belonging to a host
# Arguments   : $host_id
# Returns     : An array of IP addresses
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_if_ip_by_host{
	(my $host_id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_if_by_host_ifname $package, $filename, line number $line");
	my @retvals;
	sql_query("SELECT ip FROM interfaces WHERE host= ? ",$host_id);
	my $ip=sql_getvalue();
	while (defined $ip){
		push @retvals,$ip;
		$ip=sql_getvalue();
	}
	return @retvals;
}
#-----------------------------------------------------------------------
# Name        : query_if_by_host_ifname
# Purpose     : Get all interface belonging to a hostand ifname
# Arguments   : $host_id,$ifname
# Returns     : id 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_if_by_host_ifname {
	(my $host_id,my $ifname)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_if_by_host_ifname $package, $filename, line number $line");
	return sql_qvalue("SELECT id FROM interfaces WHERE host= ?  AND ifname= ? ",$host_id,$ifname);
}
#-----------------------------------------------------------------------
# Name        : query_if_by_id
# Purpose     : Get interface by id
# Arguments   : id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getrow
#-----------------------------------------------------------------------
sub query_if_by_id {
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_if_by_id $package, $filename, line number $line");
	sql_query("SELECT * FROM interfaces WHERE id = ? ",$id);
}
#-----------------------------------------------------------------------
# Name        : query_if_names
# Purpose     : Get all interface names
# Arguments   : 
# Returns     : array with interface names
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_if_names {
	my @retval;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_if_names $package, $filename, line number $line");
	sql_query("SELECT DISTINCT ifname FROM interfaces ORDER BY ifname");
	my $val=sql_getvalue();
	while (defined $val){
		push @retval,$val;
		$val=sql_getvalue();
	}
	return @retval;
}

#-----------------------------------------------------------------------
# Name        : query_if_id_by
# Purpose     : Get all ID based on a column value
# Arguments   : 
# Returns     : id
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_if_id_by {
	my (%updates) = @_;
	(my $var, my $val)=@_;
        my  %allowed_column = (
		id         =>1,
		macid      =>1,
		ip         =>1,
		hostname   =>1,
		host       =>1,
		subnet     =>1,
		access     =>1,
		connect_if =>1,
		port       =>1,
		ifname     =>1,
		switch     =>1,
                options    =>1
        );
	my ($package, $filename, $line) = caller; my $sbr=(caller(0))[3];
	debug($DEB_DB,"$sbr $package, $filename, line number $line");
	my $where='';
	my @args;
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			$where="$where AND $var = ? ";
			push @args,$val;
		}
		else {
			debug($DEB_DB,"ILLEGAL COLUMN $var");
		}
	}
	$where=~s/^ AND//;
	return sql_qvalue("SELECT id FROM interfaces WHERE $where LIMIT 1", @args);
}

#-----------------------------------------------------------------------
# Name        : query_if_ips
# Purpose     : Get all IP adresses from interfaces
# Arguments   : 
# Returns     : array op IP addresses
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_if_ip {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_if_ip $package, $filename, line number $line");
	my @iplist;
	sql_query("SELECT DISTINCT ip FROM interfaces ORDER BY ip");
	while (my $ip=sql_getvalue()){
		push @iplist,$ip;
	}
	return @iplist;
}

#-----------------------------------------------------------------------
# Name        : query_interfaces
# Purpose     : Get all interfaces 
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : Results must be obtained with sql_getrow
#-----------------------------------------------------------------------
sub query_interfaces {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_interfaces $package, $filename, line number $line");
	sql_query("SELECT * FROM interfaces ");
}
#-----------------------------------------------------------------------
# Name        : q_interfaces
# Purpose     : The following routines allow simple lookups in the table
#		always based on the id
# Arguments   : column,id
# Returns     : requested value
# Globals     : 
# Side‑effects: 
# Notes       : The routines use sql_qvalue, and do not touch @lastresults
#-----------------------------------------------------------------------
sub q_interfaces {
	(my $var, my $id)=@_;
        my  %allowed_column = (
		id         =>1,
		macid      =>1,
		ip         =>1,
		hostname   =>1,
		host       =>1,
		subnet     =>1,
		access     =>1,
		connect_if =>1,
		port       =>1,
		ifname     =>1,
		switch     =>1,
                options    =>1
        );
	my ($package, $filename, $line) = caller; my $sbr=(caller(0))[3];
	debug($DEB_DB,"$sbr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT $var FROM interfaces WHERE id= ? ", $id);
	}
	else {
		debug($DEB_DB,"ILLEGAL COLUMN $var");
		return sql_qvalue("SELECT id FROM interfaces WHERE id= ? ", $id);
	}
}

#-----------------------------------------------------------------------
# Name        : q_if_delete
# Purpose     : Delete an interface
# Arguments   : id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_if_delete {
	(my $id)=@_;
	my ($package, $filename, $line) = caller; my $sbr=(caller(0))[3];
	debug($DEB_DB,"$sbr $package, $filename, line number $line");
	sql_qvalue("DELETE FROM interfaces WHERE id= ? ", $id);
}

#     _   _  _          _  _ ___ 
# |    ) /  / \|\ ||\ ||_ /   |  
# |_  /_ \_ \_/| \|| \||_ \_  |  
#                          


#-----------------------------------------------------------------------
# Name        : query_l2_sources
# Purpose     : Get the list of sources in the l2 connection table
# Arguments   : 
# Returns     : array of VLANs
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_sources {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_sources $package, $filename, line number $line");
	sql_query("SELECT DISTINCT source FROM l2connect ORDER BY source");
	my @sources;
	my $source = sql_getvalue();
	while (defined $source){
		push @sources,$source;
		$source = sql_getvalue();
	}
	return @sources;
}
#-----------------------------------------------------------------------
# Name        : query_l2_ids
# Purpose     : Get the list of ids in the l2 connection table
# Arguments   : 
# Returns     : array of ids
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_ids {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_ids $package, $filename, line number $line");
	sql_query("SELECT DISTINCT id FROM l2connect ORDER BY id");
	my @ids;
	my $id=sql_getvalue();
	while (defined $id){
		push @ids,$id;
		$id=sql_getvalue();
	}
	return @ids;
}
#-----------------------------------------------------------------------
# Name        : query_l2_getvlans
# Purpose     : Get the list of VLANs in the l2 connection table
# Arguments   : 
# Returns     : array of VLANs
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_getvlans {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_getvlans $package, $filename, line number $line");
	sql_query("SELECT DISTINCT vlan FROM l2connect ORDER BY vlan");
	my @vlans;
	my $vlan=sql_getvalue();
	while (defined $vlan){
		push @vlans,$vlan;
		$vlan=sql_getvalue();
	}
	return @vlans;
}
#-----------------------------------------------------------------------
# Name        : query_l2
# Purpose     : Get all rows from l2
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : get the row with sql_getrow();
#-----------------------------------------------------------------------
sub query_l2{
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2$package, $filename, line number $line");
	my $rows = sql_query("SELECT * FROM l2connect");
}
#-----------------------------------------------------------------------
# Name        : query_l2_by_id
# Purpose     : Get a row from l2 by id
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : get the row with sql_getrow();
#-----------------------------------------------------------------------
sub query_l2_by_id {
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_by_id $package, $filename, line number $line");
	my $rows = sql_query("SELECT * FROM l2connect WHERE id= ? ", $id);
}
#-----------------------------------------------------------------------
# Name        : q_l2connect
# Purpose     : The following routines allow simple lookups in the table
#		always based on the id
# Arguments   : column,id
# Returns     : requested value
# Globals     : 
# Side‑effects: 
# Notes       : The routines use sql_qvalue, and do not touch @lastresults
#-----------------------------------------------------------------------
sub q_l2connect {
	(my $var, my $id)=@_;
        my  %allowed_column = (
                id         => 1,
                vlan       => 1,
                from_tbl   => 1,
                from_id    => 1,
                from_port  => 1,
                to_tbl     => 1,
                to_id      => 1,
                to_port    => 1,
		source     => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT $var FROM l2connect WHERE id= ? ", $id);
	}
	else {
		return sql_qvalue("SELECT id FROM l2connect WHERE id= ? ", $id);
	}
}

#-----------------------------------------------------------------------
# Name        : query_l2_insert
# Purpose     : Insert an l2 row
# Arguments   : $from_tbl,$from_id,$from_port,$to_tbl,$to_id,$to_port,$vlan,$source
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_insert {
	(my $from_tbl,my $from_id,my $from_port,my $to_tbl,my $to_id,my $to_port,my $vlan,my $source)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_delete $package, $filename, line number $line");
	sql_query("INSERT INTO l2connect (from_tbl,from_id,from_port,to_tbl,to_id,to_port,vlan,source) VALUES ( ? , ? , ? , ? , ? , ? , ? , ? )",
	          $from_tbl,$from_id,$from_port,$to_tbl,$to_id,$to_port,$vlan,$source) ;
}
#-----------------------------------------------------------------------
# Name        : query_l2_delete
# Purpose     : Delete an l2connect entry by ID
# Arguments   : ID
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_delete {
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_delete $package, $filename, line number $line");
	sql_query("DELETE FROM l2connect WHERE id= ? ",$id);
}
#-----------------------------------------------------------------------
# Name        : query_l2_delete_to
# Purpose     : Delete an l2connect entry by to_tbl and to_id
# Arguments   : to_tbl, to_id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_delete_to {
	(my $to_tbl,my $to_id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_delete_to $package, $filename, line number $line");
	sql_query("DELETE FROM l2connect WHERE to_tbl= ? AND to_id= ? ",$to_tbl,$to_id);
}
#-----------------------------------------------------------------------
# Name        : query_l2_delete_to_by_host
# Purpose     : Delete an l2connect entry by to_tbl and to_id
# Arguments   : to_tbl, to_id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_l2_delete_to_by_host {
	(my $to_tbl,my $to_host)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_l2_delete_to_by_host $package, $filename, line number $line");
	sql_query("DELETE FROM l2connect WHERE to_tbl= ? AND to_id= ? ",$to_tbl,$to_host);
}



#       _  __ 
# |\ | |_ (_  
# | \| |  __) 
#      

#-----------------------------------------------------------------------
# Name        : query_nfs
# Purpose     : Get all the nfs mounts
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : retrieve results with "while ( my $r=sql_getrow()){"
#-----------------------------------------------------------------------
sub query_nfs {
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_nfs $package, $filename, line number $line");
	sql_query("SELECT * FROM nfs");
}

#  _     __  _  _  
# |_)/\ /__ |_ (_  
# | /--\\_| |_  _) 
# 

#-----------------------------------------------------------------------
# Name        : q_page_id
# Purpose     : get page-id fron the arguments
# Arguments   : var,value pairs
# Returns     : id
# Globals     : 
# Side‑effects: 
# Notes       : var,value pairs are used in the where-clause
#-----------------------------------------------------------------------
sub q_page_id {
	my (%updates) = @_;
	my  %allowed_column = (
		id	=> 1,
		page	=> 1,
		tbl	=> 1,
		item	=> 1,
		xcoord	=> 1,
		ycoord	=> 1
	);
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"q_page_id $package, $filename, line number $line");
	my $where='';
	my @vals;
	my $retval=0;
	while (my ($var, $val) = each %updates) {
		$where="$where AND $var = ?";
		push @vals,$val;
	}
	$where=~s/^ AND//;
	if ($where ne ''){
		$retval=sql_qvalue("SELECT id FROM pages WHERE $where",@vals);
	}
}

#-----------------------------------------------------------------------
# Name        : q_page_update
# Purpose     : get page-id fron the arguments
# Arguments   : id, var,value pairs
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_page_update {
	my ($id,%updates) = @_;
	my  %allowed_column = (
		id	=> 1,
		page	=> 1,
		tbl	=> 1,
		item	=> 1,
		xcoord	=> 1,
		ycoord	=> 1
	);
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"q_page_update $package, $filename, line number $line");
	my $where='';
	my @vals;
	my $retval=0;
	while (my ($var, $val) = each %updates) {
		sql_qvalue("UPDATE pages SET $var = ? WHERE id= ? ",$val,$id);
	}
}

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

#-----------------------------------------------------------------------
# Name        : query_pages_del_obj
# Purpose     : Delete an object in the page table
# Arguments   : page
#		table (e.g. subnet or server)
#		item (foreign id)
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_pages_del_obj {
	(my $page,my $table,my $item)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_pages_del_obj $package, $filename, line number $line");
	sql_query("DELETE FROM pages WHERE page= ? AND tbl= ? AND item= ? ",$page,$table,$item);
}
#-----------------------------------------------------------------------
# Name        : query_pages_add_obj
# Purpose     : Add an object to the page table
# Arguments   : page
#		table (e.g. subnet or server)
#		item
#		x,y
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_pages_add_obj {
	(my $page,my $table,my $item,my $x,my $y)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_pages_add_obj $package, $filename, line number $line");
	sql_query("INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ( ? ,? ,? ,? ,? )",$page,$table,$item,$x,$y);
}
#-----------------------------------------------------------------------
# Name        : query_obj_on_page
# Purpose     : Initiate query for servers on a page
# Arguments   : page, table
# Returns     : 
# Globals     : @lastresult
# Side‑effects: 
# Notes       : Results must be obtained using sql_getrow()
#-----------------------------------------------------------------------
sub query_obj_on_page {
	(my $page,my $tbl)=@_;
	my  %allowed_tables = (
		cloud	=> 1,
		server	=> 1,
		subnet	=> 1,
		switch	=> 1
	);
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_obj_on_page $package, $filename, line number $line page=$page tbl=$tbl");
	if ($allowed_tables{$tbl}) {
		if ($page eq 'top'){
			sql_query("SELECT * FROM $tbl");
		}
		else {
			sql_query ("	SELECT  $tbl.*,pages.xcoord AS pagex, pages.ycoord as pagey
					FROM   $tbl
					INNER JOIN pages ON pages.item = $tbl.id
					WHERE  pages.page= ? AND pages.tbl='$tbl'
					ORDER BY name
				", $page);
		}
	}
}


# __  _  _      _  _  
#(_  |_ |_)\  /|_ |_) 
#__) |_ | \ \/ |_ | \ 
#

#-----------------------------------------------------------------------
# Name        : query_server
# Purpose     : Select all from server
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: @lastresult
# Notes       : Results must be obtained via sql_getrow(). The order by
#		name is for convenience of the user.
#-----------------------------------------------------------------------
sub query_server{
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_server $package, $filename, line number $line");
	sql_query("SELECT * FROM server ORDER BY name");
}
#-----------------------------------------------------------------------
# Name        : query_server_names
# Purpose     : List all server names
# Arguments   : 
# Returns     : server names as an array
# Globals     : 
# Side‑effects: @lastresult
# Notes       : 
#-----------------------------------------------------------------------
sub query_server_names{
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_server_names $package, $filename, line number $line");
	my @srvnames;
	sql_query("SELECT name FROM server ORDER BY name");
	while (my $name=sql_getvalue()){
		push @srvnames,$name;
	}
	return @srvnames;
}
#-----------------------------------------------------------------------
# Name        : q_server_by_name
# Purpose     : The following routines allow simple lookups in the table
#		always based on the name
# Arguments   : column,id
# Returns     : requested value
# Globals     : 
# Side‑effects: 
# Notes       : The routines use sql_qvalue, and do not touch @lastresults
#-----------------------------------------------------------------------
sub q_server_by_name {
	(my $var, my $name)=@_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		xcoord     => 1,
		ycoord     => 1,
		type       => 1,
		status     => 1,
		last_up    => 1,
		options    => 1,
		ostype     => 1,
		os         => 1,
		processor  => 1,
		devicetype => 1,
		memory     => 1,
		interfaces => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT $var FROM server WHERE name= ? ", $name);
	}
	else {
		return $name;
	}
}

#-----------------------------------------------------------------------
# Name        : q_server
# Purpose     : The following routines allow simple lookups in the table
#		always based on the id
# Arguments   : column,id
# Returns     : requested value
# Globals     : 
# Side‑effects: 
# Notes       : The routines use sql_qvalue, and do not touch @lastresults
#-----------------------------------------------------------------------
sub q_server {
	(my $var, my $id)=@_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		xcoord     => 1,
		ycoord     => 1,
		type       => 1,
		status     => 1,
		last_up    => 1,
		options    => 1,
		ostype     => 1,
		os         => 1,
		processor  => 1,
		devicetype => 1,
		memory     => 1,
		interfaces => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT $var FROM server WHERE id= ? ", $id);
	}
	else {
		return $id;
	}
}

#-----------------------------------------------------------------------
# Name        : q_server_id_by
# Purpose     : Get a server ID
# Arguments   : column,value
# Returns     : id
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_server_id_by {
	my (%updates) = @_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		xcoord     => 1,
		ycoord     => 1,
		type       => 1,
		status     => 1,
		last_up    => 1,
		options    => 1,
		ostype     => 1,
		os         => 1,
		processor  => 1,
		devicetype => 1,
		memory     => 1,
		interfaces => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	my $where='';
	my @args;
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			$where="$where AND $var = ? ";
			push @args, $val;
		}
	}
	$where=~s/^ AND//;
	return sql_qvalue("SELECT id FROM server $where",@args);
	
}
#-----------------------------------------------------------------------
# Name        : q_server_update
# Purpose     : Update a column in the server table
# Arguments   : id, column,value
# Returns     : requested value
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_server_update {
	my ($id, %updates) = @_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		xcoord     => 1,
		ycoord     => 1,
		type       => 1,
		status     => 1,
		last_up    => 1,
		options    => 1,
		ostype     => 1,
		os         => 1,
		processor  => 1,
		devicetype => 1,
		memory     => 1,
		interfaces => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	return unless defined $id;
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			sql_qvalue("UPDATE server SET $var = ?  WHERE id= ? ",$val, $id);
		}
	}
}


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


#-----------------------------------------------------------------------
# Name        : query_delete_server
# Purpose     : Delete a server. Remove also the interfaces and connections
# Arguments   : id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_delete_server {
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_delete_server $package, $filename, line number $line");
	my @iflist;
	sql_query("DELETE FROM pages WHERE tbl='server' AND item = ? ",$id);
	sql_query("SELECT id FROM interfaces WHERE host= ? ",$id);
	my $interface=sql_getvalue();
	while (defined $interface){
		push @iflist,$interface;
		$interface=sql_getvalue();
	}
	for $interface (@iflist){
		sql_query("DELETE FROM l2connect  WHERE to_tbl='interfaces' and to_id= ? ", $interface);
		sql_query("DELETE FROM l2connect  WHERE from_tbl='interfaces' and from_id= ? ", $interface);
		sql_query("DELETE FROM interfaces WHERE id= ? ", $interface);
	}
	sql_query("DELETE FROM server WHERE id= ? ", $id);
}

# _     _     _ ___
#(_ | ||_)|\||_  |  
# _)|_||_)| ||_  |  
#

#-----------------------------------------------------------------------
# Name        : query_subnet
# Purpose     : Select all from server
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: @lastresult
# Notes       : Results must be obtained via sql_getrow(). The order by
#		nwaddress is for convenience of the user.
#-----------------------------------------------------------------------
sub query_subnet{
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_subnet $package, $filename, line number $line");
	sql_query("SELECT * FROM subnet ORDER BY nwaddress");
}

#-----------------------------------------------------------------------
# Name        : query_delete_subnet
# Purpose     : Detele a subnet
# Arguments   : id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : It is not possible to delete all interfaces on the subnet
#		because they could be on another subnet as well
#-----------------------------------------------------------------------
sub query_delete_subnet{
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_delete_subnet $package, $filename, line number $line");
	sql_query("DELETE FROM subnet WHERE id= ?", $id);
}


#-----------------------------------------------------------------------
# Name        : q_subnet_id_by
# Purpose     : Get an ID based on a column value
# Arguments   : 
# Returns     : id
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_subnet_id_by {
	(my $var, my $val)=@_;
        my  %allowed_column = (
		id         =>1,
		nwaddress  =>1,
		cidr       =>1,
		xcoord     =>1,
		ycoord     =>1,
		name       =>1,
		options    =>1,
		access     =>1
        );
	my ($package, $filename, $line) = caller; my $sbr=(caller(0))[3];
	debug($DEB_DB,"$sbr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT id FROM subnet WHERE $var= ? LIMIT 1", $val);
	}
	else {
		debug($DEB_DB,"ILLEGAL COLUMN $var");
		return $val;
	}
}

#-----------------------------------------------------------------------
# Name        : q_subnet
# Purpose     : Get a a value based on a column value
# Arguments   : 
# Returns     : column name, id
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_subnet {
	(my $var,my $id)=@_;
        my  %allowed_column = (
		id         =>1,
		nwaddress  =>1,
		cidr       =>1,
		xcoord     =>1,
		ycoord     =>1,
		name       =>1,
		options    =>1,
		access     =>1
        );
	my ($package, $filename, $line) = caller; my $sbr=(caller(0))[3];
	debug($DEB_DB,"$sbr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT $var FROM subnet WHERE id= ? LIMIT 1", $id);
	}
	else {
		debug($DEB_DB,"ILLEGAL COLUMN $var");
		return $id;
	}
}
#-----------------------------------------------------------------------
# Name        : q_subnet_update
# Purpose     : Update a column based on ID
# Arguments   : 
# Returns     : id
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_subnet_update {
	my ($id, %updates) = @_;
        my  %allowed_column = (
		id         =>1,
		nwaddress  =>1,
		cidr       =>1,
		xcoord     =>1,
		ycoord     =>1,
		name       =>1,
		options    =>1,
		access     =>1
        );
	my ($package, $filename, $line) = caller; my $sbr=(caller(0))[3];
	debug($DEB_DB,"$sbr $package, $filename, line number $line");
	return unless defined $id;
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			sql_qvalue("UPDATE subnet SET $var = ? WHERE id = ? ", $val,$id);
		}
		else {
			debug($DEB_DB,"ILLEGAL COLUMN $var");
		}
	}
}

#  __        ___ ___  _     
# (_  \    /  |   |  /  |_| 
# __)  \/\/  _|_  |  \_ | | 
#                           

#-----------------------------------------------------------------------
# Name        : query_switch
# Purpose     : Select all rows from the tabel switch
# Arguments   : 
# Returns     : 
# Globals     : @lastresult
# Side‑effects: 
# Notes       : Retrieve rows with sql_getrow()
#-----------------------------------------------------------------------
sub query_switch{
	(my $name)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_switch $package, $filename, line number $line");
	sql_query("SELECT * FROM switch ORDER BY name");
}

#-----------------------------------------------------------------------
# Name        : query_delete_switch
# Purpose     : Delets a switch
# Arguments   : ID
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub query_delete_switch {
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_delete_switch $package, $filename, line number $line");
	sql_query("DELETE FROM switch WHERE id = ? ", $id);
}
#-----------------------------------------------------------------------
# Name        : query_switch_names
# Purpose     : List all switch names
# Arguments   : 
# Returns     : switch names as an array
# Globals     : 
# Side‑effects: @lastresult
# Notes       : 
#-----------------------------------------------------------------------
sub query_switch_names{
	(my $id)=@_;
	my ($package, $filename, $line) = caller;
	debug($DEB_DB,"query_switch_names $package, $filename, line number $line");
	my @swnames;
	sql_query("SELECT name FROM switch");
	while (my $name=sql_getvalue()){
		push @swnames,$name;
	}
	return @swnames;
}

#-----------------------------------------------------------------------
# Name        : q_switch
# Purpose     : The following routines allow simple lookups in the table
#		always based on the id
# Arguments   : column,id
# Returns     : requested value
# Globals     : 
# Side‑effects: 
# Notes       : The routines use sql_qvalue, and do not touch @lastresults
#-----------------------------------------------------------------------
sub q_switch {
	(my $var, my $id)=@_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		server     => 1,
		switch     => 1,
		port       => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT $var  FROM server WHERE id= ? ", $id);
	}
	else {
		return $id;
	}
}
#-----------------------------------------------------------------------
# Name        : q_switch_id_by
# Purpose     : Get the ID of the switch from the value of another column
# Arguments   : column,value
# Returns     : id
# Globals     : 
# Side‑effects: 
# Notes       : The routines use sql_qvalue, and do not touch @lastresults
#-----------------------------------------------------------------------
sub q_switch_id_by {
	(my $var, my $val)=@_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		server     => 1,
		switch     => 1,
		port       => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	if ($allowed_column{$var}) {
		return sql_qvalue("SELECT id  FROM switch WHERE $var= ? ", $val);
	}
	else {
		return $val;
	}
}
#-----------------------------------------------------------------------
# Name        : q_switch_update
# Purpose     : Update a column based on ID
# Arguments   : 
# Returns     : id
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub q_switch_update {
	my ($id, %updates) = @_;
        my  %allowed_column = (
		id         => 1,
		name       => 1,
		server     => 1,
		switch     => 1,
		port       => 1
        );
	my ($package, $filename, $line) = caller; my $sbr=(caller(0))[3];
	debug($DEB_DB,"$sbr $package, $filename, line number $line");
	return unless defined $id;
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			sql_qvalue("UPDATE switch SET $var = ? WHERE id = ? ", $val,$id);
		}
		else {
			debug($DEB_DB,"ILLEGAL COLUMN $var");
		}
	}
}

#-----------------------------------------------------------------------
# Name        : q_switch_insert
# Purpose     : Insert a new switch
# Arguments   : pairs of column,value
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : There must alway be a name
#-----------------------------------------------------------------------
sub q_switch_insert {
	my (%updates) = @_;
        my  %allowed_column = (
		name       => 1,
		server     => 1,
		switch     => 1,
		port       => 1
        );
	my ($package, $filename, $line) = caller; my $subr=(caller(0))[3];
	debug($DEB_DB,"$subr $package, $filename, line number $line");
	my %values;
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			$values{$var}=$val;
		}
	}
	return 0 unless defined $values{name};
	sql_qvalue("INSERT INTO switch (name) VALUES ( ? )",$values{name});
	while (my ($var, $val) = each %updates) {
		if ($allowed_column{$var}) {
			if(defined($val)){
				sql_qvalue("UPDATE switch SET $var = ? WHERE name = ? ", $val,$values{name});
			}
		}
	}
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
