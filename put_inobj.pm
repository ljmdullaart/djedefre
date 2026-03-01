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
		$options='' unless defined $options;
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

#-----------------------------------------------------------------------
# Name        : put_serverinobj
# Purpose     : Put servers of a page in an array
# Arguments   : page - name of the page
#		ar_ref - refference of the array where to put the subnets
# Returns     : 
# Globals     : @lastresult
# Side-effects: 
# Notes       : 
#-----------------------------------------------------------------------
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
			query_pages_tbl_id('server',$id);
			while (my $item = sql_getvalue()){
				push @pagear, $item;
			}
			$element->{'pages'}=[@pagear];

			if ($layer == 2){
				my $swid=q_switch_id_by('server',$name);
				if (defined($swid)){
					query_switch($swid);
					while (my $r = sql_getrow()){
						$element->{'logo'}='switch';
					}
				}
			}
		
		}
	}
}

#-----------------------------------------------------------------------
# Name        : put_cloudinobj
# Purpose     : Put clouds of a page in an array
# Arguments   : page - name of the page
#		ar_ref - refference of the array where to put the subnets
# Returns     : 
# Globals     : @lastresult
# Side-effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub put_cloudinobj {
	(my $page,my $ar_ref)=@_;
	my @pagear=[];
	my $sql;
	query_obj_on_page($page,'cloud');
	
	while(my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		my $type=$r->{type};
		my $vendor=$r->{vendor};
		my $service=$r->{servie};
		my $x=$r->{pagex};
		my $y=$r->{pagey};
		if ($page eq 'top'){
			$x=$r->{xcoord};
			$y=$r->{ycoord};
		}
		$type='cloud' unless defined $type;
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
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		if($table eq 'cloud'){
			query_pages_tbl_id('cloud',$id);
			while (my $r=sql_getrow()){
				my $item=$r->{page};
				push @pagear, $item;
			}
			$element->{'pages'}=[@pagear];
		}
	}
}

#-----------------------------------------------------------------------
# Name        : put_switchinobj
# Purpose     : Put switches of a page in an array
# Arguments   : page - name of the page
#		ar_ref - refference of the array where to put the subnets
# Returns     : 
# Globals     : @lastresult
# Side-effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub put_switchinobj {
	(my $page,my $ar_ref)=@_;
	my @pagear=[];
	query_obj_on_page ($page,'switch');
	while(my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		my $x=$r->{pagex};
		my $y=$r->{pagey};
		my $type=$r->{type};
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
			pages	=> []
		};
	}
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		splice @pagear;
		if($table eq 'switch'){
			query_pages_tbl_id('switch',$id);
			while (my $r=sql_getrow()){
				my $item=$r->{page};
				push @pagear, $item;
			}
			$element->{'pages'}=[@pagear];
		}
	}
}
1;
