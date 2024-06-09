#INSTALL@ /opt/djedefre/l2drawing.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
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

my @l2_obj;
our $l2_showpage;
#$l2_showpage='top';
our $repeat_sub;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;

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


sub l2_objects {
	debug($DEB_SUB,"l2_objects");
	splice @l2_obj;
	my @hostnames;
	db_dosql("SELECT interfaces.id,server.name FROM interfaces INNER JOIN server WHERE interfaces.host=server.id");
	while ((my $id,my $name)=db_getrow()){
		$hostnames[$id]=$name;
	}
	my $sql;
	$sql="	SELECT subnet.id,nwaddress,cidr,pages.xcoord,pages.ycoord,name,subnet.options
		FROM   subnet
		INNER JOIN pages ON pages.item = subnet.id
		WHERE  pages.page='$l2_showpage' AND pages.tbl='subnet'
	";
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
		push @l2_obj, {
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
	
	#if ($l2_showpage eq 'top'){
	#	$sql = 'SELECT id,name,xcoord,ycoord,type,interfaces,status,options,ostype,os,processor,memory,devicetype FROM server';
	#}
	#else {
		$sql="	SELECT  server.id,name,pages.xcoord,pages.ycoord,type,interfaces,status,options,ostype,os,processor,memory,devicetype
			FROM   server
			INNER JOIN pages ON pages.item = server.id
			WHERE  pages.page='$l2_showpage' AND pages.tbl='server'
		";
	#}
	my $sth = db_dosql($sql);
	while((my $id,my $name, my $x,my $y,my $type,my $interfaces,my $status,my $options,my $ostype,my $os,my $processor,my $memory,my $devicetype) = db_getrow()){
		$type='server' unless defined $type;
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y;
		}
		$name='' unless defined $name;
		push @l2_obj, {
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
		my $max=$#l2_obj;
		push @{$l2_obj[$max]{pages}},' ';
		
	}
	for my $i (0 .. $#l2_obj){
		# Separate to prevent database locks
		my $id=$l2_obj[$i]->{'id'};
		my $table=$l2_obj[$i]->{'table'};
		my $name=$l2_obj[$i]->{'name'};
		if ($table eq 'server'){
			my $sql = "SELECT ip,macid FROM interfaces WHERE host=$id";
			my $sth = db_dosql($sql);
			while((my $ip,my $mac) = db_getrow()){
				push @{$l2_obj[$i]{interfaces}}, "$mac $ip";
			}
			splice @{$l2_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='server' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$l2_obj[$i]{pages}}, $item;
			}
			db_dosql("SELECT switch FROM switch WHERE server='$name'");
			while ((my $nwtype) = db_getrow()){
				$l2_obj[$i]->{'logo'}=$nwtype;
			}
			
		}
		elsif($table eq 'subnet'){
			push @{$l2_obj[$i]{pages}},' ';
			splice @{$l2_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='subnet' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$l2_obj[$i]{pages}}, $item
			}
		}
		elsif($table eq 'cloud'){
			push @{$l2_obj[$i]{pages}},' ';
			splice @{$l2_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='cloud' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$l2_obj[$i]{pages}}, $item
			}
		}
	}

}

my @l2_line;
sub l2_lines {
	debug($DEB_SUB,"l2_lines");
	my @interfacelist;
	splice @l2_line;

	my @ifserver;
	my @serverif;
	my %colorization;
	db_dosql("SELECT item,value FROM config WHERE attribute='line:color'");
	while ((my $item,my $value)=db_getrow()){
		$colorization{$item}=$value;
	}
	db_dosql("SELECT id,host FROM interfaces");
	while ((my $id, my $host)=db_getrow()){
		$ifserver[$id]=$host;
		$serverif[$host]=$id;
	}
	db_dosql("SELECT id,options FROM subnet WHERE nwaddress='Internet'");
	(my $Internet,my $Internetoptions)=db_getrow();
	my $Internetcolor='black';
	if ($Internetoptions=~/color=([^;]+);/){
		$Internetcolor=$1;
	}
	my $newInternet=$Internet*$qobjtypes+$objtsubnet;
	my $linefrom=0;
	my $lineto=0;
	db_dosql("SELECT vlan,from_tbl,from_id,from_port,to_tbl,to_id,to_port FROM l2connect");
	while ((my $vlan,my $from_tbl,my $from_id,my $from_port,my $to_tbl,my $to_id,my $to_port)=db_getrow()){
		$to_port='' unless defined $to_port;
		$from_port='' unless defined $from_port;
		$vlan=0 unless defined $vlan;
		if ($to_port>1000){$to_port='';}
		if ($from_port>1000){$from_port='';}
		if ($from_tbl eq 'interfaces'){
			my $host=$ifserver[$from_id];
			$linefrom=$host*$qobjtypes+$objtserver
		}
		elsif ($from_tbl eq 'server'){
			$linefrom=$from_id*$qobjtypes+$objtserver
		}
		if ($to_tbl eq 'interfaces'){
			my $host=$ifserver[$to_id];
			$lineto=$host*$qobjtypes+$objtserver
		}
		elsif ($to_tbl eq 'server'){
			$lineto=$to_id*$qobjtypes+$objtserver
		}
print "l2drawing: line from $linefrom to $lineto\n";
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
sub make_l2_plot {
	(my $parent)=@_;
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
sub cbdump {
	print "----Djedefre2-callback-dumper-----\n";
	print Dumper @_;
	print "----------------------------------\n";
}
sub l2_page {
	(my $table,my $id,my $name,my $action,my $page)=@_;
	debug($DEB_SUB,"l2_page");
	my $arg="$table:$id:$name";
	$managepg_pagename=$page;
	mgpg_selector_callback ($action,$arg,$page);
	l2_renew_content();
}

sub l2_color {
	(my $table, my $id, my $color)=@_;
	debug($DEB_SUB,"l2_color");
	if ($table eq 'subnet'){
		db_dosql("SELECT options FROM $table WHERE id=$id");
		(my $opts)=db_getrow();
		while ($opts=~/color=[^;]*;/){
			$opts=~s/color=[^;]*;//;
		}
		$opts="color=$color;$opts";
		db_dosql("UPDATE $table SET options='$opts' WHERE id=$id");
	}
	l2_renew_content();
}
sub l2_devicetype {
	(my $table, my $id, my $type)=@_;
	debug($DEB_SUB,"l2_devicetype");
	if ($table eq 'server'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET devicetype='$type' WHERE id=$id");
	}
	l2_renew_content();
}
sub l2_type {
	(my $table, my $id, my $type)=@_;
	debug($DEB_SUB,"l2_type");
	if ($table eq 'server'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET type='$type' WHERE id=$id");
	}
	elsif ($table eq 'cloud'){
		#my $sql = "UPDATE $table SET type='$type' WHERE id=$id"; my $sth = $db->prepare($sql); $sth->execute();
		db_dosql("UPDATE $table SET type='$type' WHERE id=$id");
	}
	l2_renew_content();
}
sub l2_name {
	(my $table, my $id, my $name)=@_;
	debug($DEB_SUB,"l2_name");
	my $sql = "UPDATE $table SET name='$name' WHERE id=$id"; db_dosql($sql);
	l2_renew_content();
}
sub l2_delete {
	(my $table, my $id, my $name)=@_;
	debug($DEB_SUB,"l2_delete");
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
	l2_renew_content();
}
sub l2_move {
	(my $table, my $id, my $x, my $y)=@_;
	debug($DEB_SUB,"l2_move");
	my $sql;
	if ((defined($id)) && (defined($x)) && (defined ($y))) {
		$sql = "UPDATE pages SET xcoord=$x WHERE item=$id AND tbl='$table' AND page='$l2_showpage'"; db_dosql($sql);
		$sql = "UPDATE pages SET ycoord=$y WHERE item=$id AND tbl='$table' AND page='$l2_showpage'"; db_dosql($sql);
	}
}

sub l2_merge {
	(my $table, my $id, my $name, my $target)=@_;
	debug($DEB_SUB,"l2_merge");
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
	l2_renew_content();
}


1;
