
#  _ _     _   _                 
# | (_)___| |_(_)_ __   __ _ ___ 
# | | / __| __| | '_ \ / _` / __|
# | | \__ \ |_| | | | | (_| \__ \
# |_|_|___/\__|_|_| |_|\__, |___/
#                      |___/ 

our $main_frame;

my $listing_frame;
my $listing_button_frame;
my $listing_listing_frame;
sub make_listing {
	(my $parent)=@_;
	$main_frame->destroy if Tk::Exists($main_frame);
        $main_frame=$main_window->Frame()->pack();
	$listing_frame->destroy if Tk::Exists($listing_frame);
	$listing_frame=$main_frame->Frame()->pack(-side=>'left');
	$listing_button_frame=$listing_frame->Frame(
	)->pack(-side=>'top');
	$listing_listing_frame=$listing_frame->Frame(
	)->pack(-side=>'top');

	$listing_button_frame->Button(-text => "Servers",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		$listing_listing_frame=$listing_frame->Frame(
		)->pack(-side =>'bottom');
		listing_servers($listing_listing_frame);
	})->pack(-side=>'left');
	$listing_button_frame->Button(-text => "Subnets",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		$listing_listing_frame=$listing_frame->Frame(
		)->pack(-side =>'bottom');
		listing_subnets($listing_listing_frame);
	})->pack(-side=>'left');
	$listing_button_frame->Button(-text => "Interfaces",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		$listing_listing_frame=$listing_frame->Frame(
		)->pack(-side =>'bottom');
		listing_interfaces($listing_listing_frame);
	})->pack(-side=>'left');
}

my $listing_server_frame;
sub listing_servers{
	(my $parent)=@_;
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame(
	)->pack();
	$listing_server_frame->Label(-text=>"Servers")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;	# $id;
	$ar[1]=20;	# $name;
	$ar[2]=20;	# $type;
	$ar[3]=20;	# $ostype;
	$ar[4]=40;	# $os;
	$ar[5]=35;	# $processor;
	$ar[6]=15;	# $memory;
	ml_colwidth(@ar);
	splice @ar;
	@ar=('ID','Name','Type','OS Type','OS','Processor','Memory');
	ml_colhead(@ar);
	ml_create();
	my $sql = 'SELECT id,name,type,ostype,os,processor,memory FROM server ORDER BY id';
	my $sth =  db_dosql($sql);
	while((my $id,my $name,my $type,my $ostype,my $os,my $processor,my $memory) = db_getrow()){
		$type='server' unless defined $type;
		$ostype='' unless defined $ostype;
		$os='' unless defined $os;
		$os=~s/ADVENTERPRISE/ADVENTPR/;
		$processor='' unless defined $processor;
		$memory='' unless defined $memory;
		$ar[0]= $id;
		$ar[1]= $name;
		$ar[2]= $type;
		$ar[3]= $ostype;
		$ar[4]= $os;
		$ar[5]= $processor;
		$ar[6]= $memory;
		ml_insert(@ar);
	}
		
}

my $listing_subnet_frame;
sub listing_subnets {
	(my $parent)=@_;
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame(
	)->pack();
	$listing_server_frame->Label(-text=>"Subnets")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;	# $id;
	$ar[1]=20;	# $name;
	$ar[2]=20;	# $nwaddress;
	$ar[3]= 5;	# $cidr;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='Name';
	$ar[2]='Network';
	$ar[3]='CIDR';
	ml_colhead(@ar);
	ml_create();
	my $sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name FROM subnet ORDER BY id';
	my $sth =  db_dosql($sql);
	while((my $id,my $nwaddress,my $cidr, my $x,my $y,my $name) = db_getrow()){
		$name="$nwaddress/$cidr" unless defined $name;
		$name="$nwaddress/$cidr" if ($name eq '');
		$ar[0]=$id;
		$ar[1]=$name;
		$ar[2]=$nwaddress;
		$ar[3]=$cidr;
		ml_insert(@ar);
	}
}
		
my $listing_interfaces_frame;
sub listing_interfaces {
	(my $parent)=@_;
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame(
	)->pack();
	$listing_server_frame->Label(-text=>"Interfaces")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;	# $id;
	$ar[1]=20;	# $net;
	$ar[2]=20;	# $host;
	$ar[3]=20;	# $ip;
	$ar[4]=20;	# $hostname;
	$ar[5]=20;	# $mac;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='MAC';
	$ar[2]='IP';
	$ar[3]='Name';
	$ar[4]='Net';
	$ar[5]='Host';
	ml_colhead(@ar);
	ml_create();
	my @servers=[];
	my $sql = 'SELECT id,name FROM server';
	my $sth =  db_dosql($sql);
	while((my $id,my $name) = db_getrow()){
		$servers[$id]=$name;
	}
	my @subnets=[];
	my $sql = 'SELECT id,nwaddress,cidr FROM subnet';
	my $sth =  db_dosql($sql);
	while((my $id,my $nwaddress,my $cidr) = db_getrow()){
		$subnets[$id]="$nwaddress/$cidr";
	}
	my $sql = 'SELECT id,macid,ip,hostname,host,subnet,access FROM interfaces ORDER BY id';
	my $sth =  db_dosql($sql);
	while((my $id,my $macid,my $ip,my $hostname,my $host,my $subnet,my $access) = db_getrow()){
		my $name=$servers[$host];
		$name=$hostname unless defined $name;
		my $snet;
		if (defined $subnets[$subnet]){
			$snet=$subnets[$subnet];
		}
		else {
			$snet='';
		}
		$ar[0]=$id;
		$ar[1]=$macid;
		$ar[2]=$ip;
		$ar[3]=$name;
		$ar[4]=$snet;
		$ar[5]=$hostname;
		ml_insert(@ar);
	}
}

1;