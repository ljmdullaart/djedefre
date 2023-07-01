
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
our $l3_showpage='top';


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



connect_db($config{'dbfile'});


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
	my $sth = db_dosql($sql);
	while((my $id,my $nwaddress, my $cidr,my $x,my $y,my $name) = db_getrow()){
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y
		}
		$name="$nwaddress/$cidr" unless defined $name;
		push @l3_obj, {
			newid	=> $id*4,
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
	$sql="  SELECT switch.id,name,ports,pages.xcoord,pages.ycoord
		FROM switch
		INNER JOIN pages ON pages.item = switch.id
		WHERE  pages.page='$l3_showpage' AND pages.tbl='switch'
	";
	db_dosql($sql);
	while ((my $id,my $name,my $ports,my $x,my $y)=db_getrow()){
		push @l3_obj, {
			newid   => $id*4+2,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> 'switch',
			name	=> $name,
			ports	=> $ports,
			table	=> 'switch'
		};
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
	my $sth = db_dosql($sql);
	while((my $id,my $name, my $x,my $y,my $type,my $interfaces,my $status,my $options,my $ostype,my $os,my $processor,my $memory) = db_getrow()){
		$type='server' unless defined $type;
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y;
		}
		$name='' unless defined $name;
		push @l3_obj, {
			newid	=> $id*4+1,
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
			my $sth = db_dosql($sql);
			while((my $ip) = db_getrow()){
				push @{$l3_obj[$i]{interfaces}}, $ip;
			}
			splice @{$l3_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='server' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$l3_obj[$i]{pages}}, $item
			}
			
		}
		elsif($table eq 'subnet'){
			push @{$l3_obj[$i]{pages}},' ';
			splice @{$l3_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='subnet' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$l3_obj[$i]{pages}}, $item
			}
		}
	}
}

my @l3_line;
sub l3_lines {
	my @interfacelist;
	splice @l3_line;

	my @ifserver;
	db_dosql("SELECT id,host FROM interfaces");
	while ((my $id, my $host)=db_getrow()){
		$ifserver[$id]=$host;
	}
	for my $k (0 .. $#ifserver){
		print "ifserver $k  $ifserver[$k]\n" if defined $ifserver[$k];
	}
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
				my $host=$hostid*4+1;
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
		if ($l3_obj[$i]->{'table'} eq 'switch'){
			$obj_id=$l3_obj[$i]->{'newid'};
			my $sw_id=$l3_obj[$i]->{'id'};
			my $sw_newid=$l3_obj[$i]->{'newid'};
			print "Found a switch $sw_id, $sw_newid\n";
			db_dosql("SELECT to_tbl,to_id FROM l2connect WHERE from_tbl='switch' AND from_id=$sw_id");
			while ((my $to_tbl,my $to_id)=db_getrow()){
				my $to_srv=$to_id;
				if ( $to_tbl eq 'interfaces'){
					$to_srv=$ifserver[$to_id];
					$to_tbl='server';
				}
				print "	switch is connected to $to_tbl interface:$to_id  server:$to_srv\n";
				for my $j ( 0 .. $#l3_obj){
					my $con_id=$l3_obj[$j]->{'id'};
					my $con_tbl=$l3_obj[$j]->{'table'};
					my $con_newid=$l3_obj[$j]->{'newid'};
					my $con_srv=$con_id;
					if($con_tbl eq 'interfaces'){
						$con_srv=$ifserver[$con_id];
						$con_tbl='server';
					}
					print "		test if on page: $to_tbl eq $con_tbl && $to_srv == $con_id\n";
					if (($to_tbl eq $con_tbl) && ($to_srv == $con_id)){
						print "			yes: push $sw_newid to $con_newid\n";
						push @l3_line, {
							from    => $sw_newid,
							to	=> $con_newid,
							type	=> 1
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
		db_dosql("UPDATE $table SET type='$type' WHERE id=$id");
	}
	l3_renew_content();
}
sub l3_name {
	(my $table, my $id, my $name)=@_;
	my $sql = "UPDATE $table SET name='$name' WHERE id=$id"; db_dosql($sql);
	l3_renew_content();
}
sub l3_delete {
	(my $table, my $id, my $name)=@_;
	my $sql = "DELETE FROM $table WHERE id=$id";  db_dosql($sql);
	l3_renew_content();
}
sub l3_move {
	(my $table, my $id, my $x, my $y)=@_;
	my $sql;
	if ( $l3_showpage eq 'top'){
		$sql = "UPDATE $table SET xcoord=$x WHERE id=$id"; db_dosql($sql);
		$sql = "UPDATE $table SET ycoord=$y WHERE id=$id"; db_dosql($sql);
	}
	else {
		$sql = "UPDATE pages SET xcoord=$x WHERE item=$id AND tbl='$table' AND page='$l3_showpage'"; db_dosql($sql);
		$sql = "UPDATE pages SET ycoord=$y WHERE item=$id AND tbl='$table' AND page='$l3_showpage'"; db_dosql($sql);
	}
}

sub l3_merge {
	(my $table, my $id, my $name, my $target)=@_;
	if ($table eq "server"){
		my $targetid=$id;
		if ($target =~/^(\d+\.\d+\.\d+\.\d+)/){
			my $sql = "SELECT host FROM interfaces WHERE ip='$1'";
			my $sth=db_dosql($sql);
			while((my $host) = db_getrow()){
				$targetid=$host;
			}
		}
		elsif ($target=~/^([A-Za-z]\w*)/){
			my $sql = "SELECT id FROM server WHERE name='$1'";
			my $sth =  db_dosql($sql);
			while((my $host) = db_getrow()){
				$targetid=$host;
			}
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
			foreach(@iflist){
				my $sql = "UPDATE interfaces SET host=$targetid WHERE id=$_";
				db_dosql($sql);
			}
			db_dosql("DELETE FROM server WHERE id=$id");
			db_dosql("DELETE FROM pages  WHERE item=$id AND tbl='server'");
		}
	}
	l3_renew_content();
}


1;
