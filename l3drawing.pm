#INSTALL@ /opt/djedefre/l3drawing.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
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
our $repeat_sub;


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



connect_db($config{'dbfile'});


sub l3_objects {
	splice @l3_obj;
	my @hostnames;
	db_dosql("SELECT interfaces.id,server.name FROM interfaces INNER JOIN server WHERE interfaces.host=server.id");
	while ((my $id,my $name)=db_getrow()){
		$hostnames[$id]=$name;
	}
	my @switchnames;
	db_dosql("SELECT id,name FROM switch");
	while ((my $id,my $name)=db_getrow()){
		$switchnames[$id]=$name;
	}
	my $sql;
	if ($l3_showpage eq 'top'){
		$sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name,options FROM subnet';
	}
	else {
		$sql="	SELECT subnet.id,nwaddress,cidr,pages.xcoord,pages.ycoord,name,subnet.options
			FROM   subnet
			INNER JOIN pages ON pages.item = subnet.id
			WHERE  pages.page='$l3_showpage' AND pages.tbl='subnet'
		";
	}
	my $sth = db_dosql($sql);
	while((my $id,my $nwaddress, my $cidr,my $x,my $y,my $name,my $options) = db_getrow()){
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y
		}
		$name="$nwaddress/$cidr" unless defined $name;
		my $color='black';
		if ($options=~/color=([^;]*);/){$color=$1;}
		push @l3_obj, {
			newid	=> $id*$qobjtypes+$objtsubnet,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> 'subnet',
			name	=> $name,
			nwaddress=> $nwaddress,
			cidr	=> $cidr,
			table	=> 'subnet',
			color	=> $color
		}
	}
	
	$sql="  SELECT switch,switch.id,name,ports,pages.xcoord,pages.ycoord
		FROM switch
		INNER JOIN pages ON pages.item = switch.id
		WHERE  pages.page='$l3_showpage' AND pages.tbl='switch'
	";
	
	db_dosql($sql);
	while ((my $switchtype,my $id,my $name,my $ports,my $x,my $y)=db_getrow()){
		$switchtype='switch' unless defined $switchtype;
		push @l3_obj, {
			newid	=> $id*$qobjtypes+$objtswitch,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> $switchtype,
			name	=> $name,
			ports	=> $ports,
			table	=> 'switch'
		};
		my $newid   =$id*$qobjtypes+$objtswitch;
	}
	if ($l3_showpage eq 'top'){
		$sql = 'SELECT id,name,xcoord,ycoord,type,interfaces,status,options,ostype,os,processor,memory,devicetype FROM server';
	}
	else {
		$sql="	SELECT  server.id,name,pages.xcoord,pages.ycoord,type,interfaces,status,options,ostype,os,processor,memory,devicetype
			FROM   server
			INNER JOIN pages ON pages.item = server.id
			WHERE  pages.page='$l3_showpage' AND pages.tbl='server'
		";
	}
	my $sth = db_dosql($sql);
	while((my $id,my $name, my $x,my $y,my $type,my $interfaces,my $status,my $options,my $ostype,my $os,my $processor,my $memory,my $devicetype) = db_getrow()){
		$type='server' unless defined $type;
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y;
		}
		$name='' unless defined $name;
		push @l3_obj, {
			newid	=> $id*$qobjtypes+$objtserver,
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
			memory	=> $memory,
			devicetype => $devicetype
		};
		my $max=$#l3_obj;
		push @{$l3_obj[$max]{pages}},' ';
		
	}
	
	if ($l3_showpage eq 'top'){
		$sql = 'SELECT id,name,xcoord,ycoord,type,vendor,service FROM cloud';
	}
	else {
		$sql="	SELECT  cloud.id,name,pages.xcoord,pages.ycoord,type,vendor,service
			FROM    cloud
			INNER JOIN pages ON pages.item =  cloud.id
			WHERE  pages.page='$l3_showpage' AND pages.tbl='cloud'
		";
	}
	my $sth = db_dosql($sql);
	while((my $id,my $name, my $x,my $y,my $type,my $vendor,my $service) = db_getrow()){
		$type='server' unless defined $type;
		$vendor='none' unless defined $vendor;
		$service='server' unless defined $service;
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y;
		}
		$name='' unless defined $name;
		push @l3_obj, {
			newid	=> $id*$qobjtypes+$objtcloud,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> $type,
			name	=> $name,
			table	=> 'cloud',
			vendor  => $vendor,
			service => $service
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
		elsif($table eq 'cloud'){
			push @{$l3_obj[$i]{pages}},' ';
			splice @{$l3_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='cloud' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$l3_obj[$i]{pages}}, $item
			}
		}
		elsif($table eq 'switch'){
			push @{$l3_obj[$i]{pages}},' ';
			splice @{$l3_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='switch' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$l3_obj[$i]{pages}}, $item
			}
			push @{$l3_obj[$i]{connected}},' ';
			splice @{$l3_obj[$i]{connected}};
			my $sql = "SELECT to_tbl,to_id,from_port FROM l2connect WHERE from_tbl='switch' AND from_id=$id ORDER BY from_port";
			my $sth = db_dosql($sql);
			while ((my $to_tbl,my $to_id,my $from_port) = db_getrow()){
				my $name;
				if ($to_tbl eq 'interfaces'){
					 $name=$hostnames[$to_id];
				}
				elsif ($to_tbl eq 'switch'){
					$name=$switchnames[$to_id];
				}
				else { $name='';}
				$name='' unless defined $name;
				push @{$l3_obj[$i]{connected}}, "$from_port:$to_tbl:$name";
			}
			my $sql = "SELECT from_tbl,from_id,to_port FROM l2connect WHERE to_tbl='switch' AND to_id=$id ORDER BY to_port";
			my $sth = db_dosql($sql);
			while ((my $to_tbl,my $to_id,my $from_port) = db_getrow()){
				my $name;
				if ($to_tbl eq 'interfaces'){
					 $name=$hostnames[$to_id];
				}
				elsif ($to_tbl eq 'switch'){
					$name=$switchnames[$to_id];
				}
				else { $name='';}
				$name='' unless defined $name;
				push @{$l3_obj[$i]{connected}}, "$from_port:$to_tbl:$name";
			}
		}
	}

}

my @l3_line;
sub l3_lines {
	my @interfacelist;
	splice @l3_line;

	my @ifserver;
	my %colorization;
	db_dosql("SELECT item,value FROM config WHERE attribute='line:color'");
	while ((my $item,my $value)=db_getrow()){
		$colorization{$item}=$value;
	}
	db_dosql("SELECT id,host FROM interfaces");
	while ((my $id, my $host)=db_getrow()){
		$ifserver[$id]=$host;
	}
	db_dosql("SELECT id,options FROM subnet WHERE nwaddress='Internet'");
	(my $Internet,my $Internetoptions)=db_getrow();
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
			for my $j ( 0 .. $#l3_obj){
				if ($l3_obj[$j]->{'table'} eq 'subnet'){
					my $netw_id=$l3_obj[$j]->{'newid'};
					my $netw=$l3_obj[$j]->{'nwaddress'};
					my $cidr=$l3_obj[$j]->{'cidr'};
					my $color=$l3_obj[$j]->{'color'};
					$color='black' unless defined $color;
					for (@interfacelist){
						if (($_ eq 'Internet') && ($l3_obj[$j]->{'nwaddress'} eq 'Internet')){
							push @l3_line, {
								from	=> $netw_id,
								to	=> $obj_id,
								type	=> $color
							};
						}
						elsif (ipisinsubnet($_,"$netw/$cidr")==1){
							push @l3_line, {
								from	=> $netw_id,
								to	=> $obj_id,
								type	=> $color
							};
						}
					}
				}
			}
			my $options=$l3_obj[$i]->{'options'};
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
		if ($l3_obj[$i]->{'table'} eq 'switch'){
			$obj_id=$l3_obj[$i]->{'newid'};
			my $sw_id=$l3_obj[$i]->{'id'};
			my $sw_newid=$l3_obj[$i]->{'newid'};
			my $sw_name=$l3_obj[$i]->{'name'};
			my $vlancolor;
			db_dosql("SELECT vlan,to_tbl,to_id FROM l2connect WHERE from_tbl='switch' AND from_id=$sw_id");
			while ((my $vlan,my $to_tbl,my $to_id)=db_getrow()){
				if (defined $colorization{$vlan}){
					$vlancolor=$colorization{$vlan};
				}
				elsif (defined $colorization{"vlan$vlan"}){
					$vlancolor=$colorization{"vlan$vlan"};
				}
				else {
					$vlancolor='black';
				}
				my $to_srv=$to_id;
				$vlan=1 unless defined $vlan;
				if ( $to_tbl eq 'interfaces'){
					$to_srv=$ifserver[$to_id];
					$to_tbl='server';
				}
				for my $j ( 0 .. $#l3_obj){
					my $con_id=$l3_obj[$j]->{'id'};
					my $con_tbl=$l3_obj[$j]->{'table'};
					my $con_newid=$l3_obj[$j]->{'newid'};
					my $con_srv=$con_id;
					if($con_tbl eq 'interfaces'){
						$con_srv=$ifserver[$con_id];
						$con_tbl='server';
					}
					if (($to_tbl eq $con_tbl) && ($to_srv == $con_id)){
						push @l3_line, {
							from    => $sw_newid,
							to	=> $con_newid,
							type	=> $vlancolor
						};
					}
				}
			}
			db_dosql("SELECT from_tbl,from_id FROM l2connect WHERE to_tbl='switch' AND to_id=$sw_id");
			while ((my $from_tbl,my $from_id)=db_getrow()){
				for my $j ( 0 .. $#l3_obj){
					my $con_id=$l3_obj[$j]->{'id'};
					my $con_tbl=$l3_obj[$j]->{'table'};
					my $con_newid=$l3_obj[$j]->{'newid'};
					my $con_srv=$con_id;
					if (($from_tbl eq $con_tbl) && ($from_id == $con_id)){
						push @l3_line, {
							from    => $sw_newid,
							to	=> $con_newid,
							type	=> $vlancolor
						};
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
	print "----Djedefre2-callback-dumper-----\n";
	print Dumper @_;
	print "----------------------------------\n";
}
sub l3_page {
	(my $table,my $id,my $name,my $action,my $page)=@_;
	my $arg="$table:$id:$name";
	$managepg_pagename=$page;
	mgpg_selector_callback ($action,$arg,$page);
	l3_renew_content();
}

sub l3_color {
	(my $table, my $id, my $color)=@_;
	if ($table eq 'subnet'){
		db_dosql("SELECT options FROM $table WHERE id=$id");
		(my $opts)=db_getrow();
		while ($opts=~/color=[^;]*;/){
			$opts=~s/color=[^;]*;//;
		}
		$opts="color=$color;$opts";
		db_dosql("UPDATE $table SET options='$opts' WHERE id=$id");
	}
	l3_renew_content();
}
sub l3_devicetype {
	(my $table, my $id, my $type)=@_;
	if ($table eq 'server'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET devicetype='$type' WHERE id=$id");
	}
	l3_renew_content();
}
sub l3_type {
	(my $table, my $id, my $type)=@_;
	if ($table eq 'server'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET type='$type' WHERE id=$id");
	}
	elsif ($table eq 'cloud'){
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
	if ($table eq 'server'){
		db_dosql("SELECT id FROM interfaces WHERE host=$id");
		my @ifids; splice @ifids;
		while ((my $ifid)=db_getrow()){ push @ifids,$ifid; }
		for my $ifid (@ifids){
			db_dosql("DELETE FROM l2connect WHERE to_tbl='interfaces' and to_id=$ifid");
		}
		db_dosql("DELETE FROM interfaces WHERE host=$id");
	}
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
