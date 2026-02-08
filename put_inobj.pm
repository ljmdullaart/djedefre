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

#-----------------------------------------------------------------------
# Name        : put_netinobj
# Purpose     : Put subnets of a page in an array
# Arguments   : page - name of the page
#		ar_ref - refference of the array where to put the subnets
# Returns     : 
# Globals     : @lastresult
# Side-effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub put_netinobj {
	(my $page,my $ar_ref)=@_;
	my @pagear=[];
	query_obj_on_page($page,'subnet');
	while (my $r=sql_getrow()){
		my $id=$r->{id};
		my $nwaddress=$r->{nwaddress};
		my $cidr=$r->{cidr};
		my $x=$r->{pagex};
		my $y=$r->{pagey};
		if ($page eq 'top'){
			 $x=$r->{xcoord};
			 $y=$r->{ycoord};
		}
		my $name=$r->{name};
		my $options=$r->{options};
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
	foreach my $element (@$ar_ref) { #separate loop to prevent overwriting open sql_query
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		if($table eq 'subnet'){
			splice @pagear;
			query_pages_tbl_id('subnet',$id);
			while (my $item = sql_getvalue()){
				push @pagear, $item;
			}
			$element->{'pages'}=[@pagear];
		}
	}
}

sub put_serverinobj {
	(my $page,my $ar_ref,my $layer)=@_;
	my @pagear=[];
	my @ifar=[];
	my $sql;
	query_obj_on_page($page,'server');
	while(my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		my $x=$r->{pagex};
		my $y=$r->{pagey};
		if ($page eq 'top'){
			 $x=$r->{xcoord};
			 $y=$r->{ycoord};
		}
		my $type=$r->{type};
		my $interfaces=$r->{interfaces};
		my $status=$r->{status};
		my $options=$r->{options};
		my $ostype=$r->{ostype};
		my $os=$r->{os};
		my $processor=$r->{processor};
		my $memory=$r->{memory};
		my $devicetype=$r->{devicetype};
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
		
	}
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		splice @ifar;
		if($table eq 'server'){
			query_if_from_host($id);
			while(my $r=sql_getrow()){
				my $ip=$r->{ip};
				my $mac=$r->{macid};
				$mac='' unless defined $mac;
				$ip='' unless defined $ip;
				push @ifar, "$mac $ip";
			}
			$element->{interfaces}=[@ifar];
			#$sth = db_dosql("SELECT page FROM pages WHERE tbl='server' AND item=$id");
			query_pages_tbl_id('server',$id);
			while (my $item = sql_getvalue()){
				push @pagear, $item;
			}
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
			pages	=> []
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
