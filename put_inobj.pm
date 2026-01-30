use strict;
use warnings;

my $qobjtypes=4;
my $objtsubnet=0;
my $objtserver=1;
my $objtswitch=2;
my $objtcloud=3;


our $nw_tmpx;
our $nw_tmpy;
our $l3_showpage;
our @l2_obj;
our $l3_showpage;

sub put_netinobj {
	(my $page,my $ar_ref)=@_;
	my $sql;
	my @pagear=[];
	if ($page eq 'top'){
		$sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name,options FROM subnet';
	}
	else {
		$sql="	SELECT subnet.id,nwaddress,cidr,pages.xcoord,pages.ycoord,name,subnet.options
			FROM   subnet
			INNER JOIN pages ON pages.item = subnet.id
			WHERE  pages.page='$page' AND pages.tbl='subnet'
		";
	}
	my $sth = db_dosql($sql);
	while((my $id,my $nwaddress, my $cidr,my $x,my $y,my $name,my $options) = db_getrow()){
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			if (! defined $x){ $x=$nw_tmpx; $nw_tmpx=$nw_tmpx+5;}
			if ($nw_tmpx > 800){$nw_tmpx=25; $nw_tmpy=$nw_tmpy+5;}
			if (! defined $y){ $y=$nw_tmpy;}
		}
		$name="$nwaddress/$cidr" unless defined $name;
		my $color='black';
		if ($options=~/color=([^;]*);/){$color=$1;}
		push @$ar_ref, {
			newid	=> $id*$qobjtypes+$objtsubnet,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> 'subnet',
			name	=> $name,
			nwaddress=> $nwaddress,
			cidr	=> $cidr,
			table	=> 'subnet',
			color	=> $color,
			pages	=> \@pagear
		} 
	}
	db_close();
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		if($table eq 'subnet'){
			splice @pagear;
			my $sql = "SELECT page FROM pages WHERE tbl='subnet' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @pagear, $item;
			}
			db_close();
			$element->{'pages'}=[@pagear];
		}
	}
}

sub put_serverinobj {
	(my $page,my $ar_ref,my $layer)=@_;
	my @pagear=[];
	my @ifar=[];
	my $sql;
	
	if ($page eq 'top'){
		$sql = 'SELECT id,name,xcoord,ycoord,type,interfaces,status,options,ostype,os,processor,memory,devicetype FROM server';
	}
	else {
		$sql="	SELECT  server.id,name,pages.xcoord,pages.ycoord,type,interfaces,status,options,ostype,os,processor,memory,devicetype
			FROM   server
			INNER JOIN pages ON pages.item = server.id
			WHERE  pages.page='$page' AND pages.tbl='server'
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
		push @$ar_ref, {
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
			devicetype => $devicetype,
			pages	=> \@pagear
		};
		my $max=$#l2_obj;
		#push @{$l2_obj[$max]{pages}},' ';
		
	}
	db_close();
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		splice @ifar;
		if($table eq 'server'){
			my $sth = db_dosql("SELECT ip,macid FROM interfaces WHERE host=$id");
			while((my $ip,my $mac) = db_getrow()){
				push @ifar, "$mac $ip";
			}
			db_close();
			$element->{interfaces}=[@ifar];
			$sth = db_dosql("SELECT page FROM pages WHERE tbl='server' AND item=$id");
			while ((my $item) = db_getrow()){
				push @pagear, $item;
			}
			db_close();
			$element->{'pages'}=[@pagear];

			if ($layer == 2){
				db_dosql("SELECT switch FROM switch WHERE server='$name'");
				while ((my $nwtype) = db_getrow()){
					$element->{'logo'}=$nwtype;
				}
				db_close();
			}
		
		}
	}
}

sub put_cloudinobj {
	(my $page,my $ar_ref)=@_;
	my @pagear=[];
	my $sql;
	if ($page eq 'top'){
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
		push @$ar_ref, {
			newid	=> $id*$qobjtypes+$objtcloud,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> $type,
			name	=> $name,
			table	=> 'cloud',
			vendor  => $vendor,
			service => $service,
			pages	=> ()
		};
	}
	db_close();
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		if($table eq 'cloud'){
			my $sth = db_dosql("SELECT page FROM pages WHERE tbl='cloud' AND item=$id");
			while ((my $item) = db_getrow()){
				push @pagear, $item;
			}
			db_close();
			$element->{'pages'}=[@pagear];
		}
	}
}


sub put_switchinobj {
	(my $page,my $ar_ref)=@_;
	my @pagear=[];
	my $sql;
	$sql="	SELECT s.id, s.name,p.xcoord,p.ycoord,s.switch
		FROM switch s
		LEFT JOIN server srv ON s.name = srv.name
		LEFT JOIN pages p ON s.id = p.item AND p.tbl = 'switch'
		WHERE srv.name IS NULL AND p.page='$page'
	";
	my $sth = db_dosql($sql);
	while((my $id,my $name, my $x,my $y,my $type) = db_getrow()){
		$type='switch' unless defined $type;
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			$x=$nw_tmpx unless defined $x;
			$y=$nw_tmpy unless defined $y;
		}
		$name='' unless defined $name;
		push @$ar_ref, {
			newid	=> $id*$qobjtypes+$objtswitch,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> $type,
			name	=> $name,
			table	=> 'switch',
			pages	=> ()
		};
	}
	db_close();
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		if($table eq 'switch'){
			my $sth = db_dosql("SELECT page FROM pages WHERE tbl='switch' AND item=$id");
			while ((my $item) = db_getrow()){
				push @pagear, $item;
			}
			db_close();
			$element->{'pages'}=[@pagear];
		}
	}
}
1;
