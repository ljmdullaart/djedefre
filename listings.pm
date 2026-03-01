
#INSTALL@ /opt/djedefre/listings.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;

use Data::Dumper;

#  _ _     _   _                 
# | (_)___| |_(_)_ __   __ _ ___ 
# | | / __| __| | '_ \ / _` / __|
# | | \__ \ |_| | | | | (_| \__ \
# |_|_|___/\__|_|_| |_|\__, |___/
#                      |___/ 

our $main_frame;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;

my $listing_frame;
my $listing_button_frame;
my $listing_listing_frame;
our $main_window;
our $main_window_height;
our $Message;

my $selected_listing='Lists';
#-----------------------------------------------------------------------
# Name        : menu_make_listing
# Purpose     : Make the selected listing
# Arguments   : 
# Returns     : 
# Globals     : $listing_frame, $main_frame, $main_window
# Side‑effects: 
# Notes       : There should be an entry for evrey listing in
#		make_listingselectframe()
#-----------------------------------------------------------------------
sub menu_make_listing {
	debug($DEB_SUB,"menu_make_listing");
	$main_frame->destroy if Tk::Exists($main_frame);
        $main_frame=$main_window->Frame()->pack();
	$listing_frame->destroy if Tk::Exists($listing_frame);
	$listing_frame=$main_frame->Frame()->pack(-side=>'left');
	$listing_button_frame=$listing_frame->Frame()->pack(-side=>'top');
	$listing_listing_frame=$listing_frame->Frame()->pack(-side=>'top');
	$Message='';
	$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
	$listing_listing_frame=$listing_frame->Frame(
	)->pack(-side =>'bottom');
	if ($selected_listing eq 'Servers'){
		listing_servers($listing_listing_frame);
	}
	elsif ($selected_listing eq 'Virtuals'){
		listing_virtual($listing_listing_frame);
	}
	elsif ($selected_listing eq 'Subnets'){
		listing_subnets($listing_listing_frame);
	}
	elsif ($selected_listing eq 'Interfaces'){
		listing_interfaces($listing_listing_frame);
	}
	elsif ($selected_listing eq 'Switches'){
		listing_switch($listing_listing_frame);
	}
	elsif ($selected_listing eq 'Cloud'){
		listing_cloud($listing_listing_frame);
	}
	elsif ($selected_listing eq 'NFS'){
		listing_nfs($listing_listing_frame);
	}
	$selected_listing='Lists';
}

#-----------------------------------------------------------------------
# Name        : make_listingselectframe
# Purpose     : Make the selection-list for the listings
# Arguments   : 
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : There should be an entry for every listing in
#               menu_make_listing()
#-----------------------------------------------------------------------
sub make_listingselectframe {
	(my $parent)=@_;
	debug($DEB_SUB,"make_listingselectframe");
	my @listingtypes=qw/ Lists Servers Virtuals Subnets Interfaces Switches Cloud NFS/;
	$parent->Optionmenu (
		-variable	=> \$selected_listing,
		-options	=> [@listingtypes],
		-width		=> 15,
		-command	=> sub { menu_make_listing(); }
	)->pack();
}
	

# duplicate van menu_make_listing? welke wordt gebruikt wanneer?
sub make_listing {
	(my $parent)=@_;
	debug($DEB_SUB,"make_listing");
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
	$listing_button_frame->Button(-text => "Virtuals",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		$listing_listing_frame=$listing_frame->Frame(
		)->pack(-side =>'bottom');
		listing_virtual($listing_listing_frame);
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
	$listing_button_frame->Button(-text => "Cloud",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		$listing_listing_frame=$listing_frame->Frame(
		)->pack(-side =>'bottom');
		listing_cloud($listing_listing_frame);
	})->pack(-side=>'left');
	$listing_button_frame->Button(-text => "Cloud",-width=>20, -command =>sub {
		$Message='';
		$listing_listing_frame->destroy if Tk::Exists($listing_listing_frame);
		$listing_listing_frame=$listing_frame->Frame(
		)->pack(-side =>'bottom');
		listing_nfs($listing_listing_frame);
	})->pack(-side=>'left');
}

my $listing_server_frame;
#-----------------------------------------------------------------------
# Name        : list_sel_srv
# Purpose     : stub voor een callback
# Arguments   : id
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub list_sel_srv {
	(my $id)=@_;
	print "list_sel_srv: $id\n";
}
#-----------------------------------------------------------------------
# Name        : listing_servers
# Purpose     : Create a listing of all servers
# Arguments   : parent - parent frame for the listing
# Returns     : 
# Globals     : $listing_server_frame
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub listing_servers{
	(my $parent)=@_;
	debug($DEB_SUB,"listing_servers");
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame()->pack();
	$listing_server_frame->Label(-text=>"Servers")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;	# $id;
	$ar[1]=20;	# $name;
	$ar[2]=20;	# $type;
	$ar[3]=15;	# $devicetype;
	$ar[4]=15;	# $ostype;
	$ar[5]=40;	# $os;
	$ar[6]=35;	# $processor;
	$ar[7]=15;	# $memory;
	ml_colwidth(@ar);
	splice @ar;
	@ar=('ID','Name','Type','Devicetype','OS Type','OS','Processor','Memory');
	ml_colhead(@ar);
	query_server();
	while (my $r=sql_getrow()){
		$ar[0]= $r->{id};
		$ar[1]= defined ($r->{name}) ? $r->{name} : $r->{id};
		$ar[2]= defined ($r->{type}) ? $r->{type} : "server";
		$ar[3]= defined ($r->{devicetype}) ? $r->{devicetype} : "server";
		$ar[4]= defined ($r->{ostype}) ? $r->{ostype} : "";
		$ar[5]= defined ($r->{os}) ? $r->{os} : "";
		$ar[6]= defined ($r->{processor}) ? $r->{processor} : "";
		$ar[7]= defined ($r->{memory}) ? $r->{memory} : "";
		ml_insert(@ar);
	}
	ml_create();
		
}

my $listing_subnet_frame;
#-----------------------------------------------------------------------
# Name        : listing_subnets
# Purpose     : Create a listing of all subnets
# Arguments   : parent - parent frame for the listing
# Returns     : 
# Globals     : 
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub listing_subnets {
	(my $parent)=@_;
	debug($DEB_SUB,"listing_subnets");
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
	query_subnet();
	while (my $r=sql_getrow()){
		my $cidr=defined($r->{cidr}) ? $r->{cidr} :"";
		my $tn=$r->{nwaddress} . '/' . $cidr;
		$ar[0]=$r->{id};
		$ar[1]=defined ($r->{name}) ? $r->{name} : $tn;
		  $ar[1]= $tn if ( $ar[1] eq '');
		$ar[2]=$r->{nwaddress};
		$ar[3]=$cidr;
		ml_insert(@ar);
	}
	ml_create();
}
		
my $listing_interfaces_frame;
#-----------------------------------------------------------------------
# Name        : listing_interfaces
# Purpose     : Create a listing of all interfaces
# Arguments   : parent - parent frame for the listing
# Returns     : 
# Globals     : $listing_interfaces_frame
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub listing_interfaces {
	(my $parent)=@_;
	debug($DEB_SUB,"listing_interfaces");
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame()->pack();
	$listing_server_frame->Label(-text=>"Interfaces")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;
	$ar[1]=20;
	$ar[2]=20;
	$ar[3]=20;
	$ar[4]=20;
	$ar[5]=10;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='MAC';
	$ar[2]='IP';
	$ar[3]='Host';
	$ar[4]='Net';
	$ar[5]='Options';
	ml_colhead(@ar);
	my @servers=[];
	query_server();
	while(my $r=sql_getrow()){
		$servers[$r->{id}]=$r->{name};
	}
	my @subnets;
	$subnets[0]=' ';
	query_subnet();
	while (my $r=sql_getrow()){
		my $cidr=defined($r->{cidr}) ? $r->{cidr} :"";
		my $id= $r->{id};
		$subnets[$id]=$r->{nwaddress} . '/' . $cidr;
	}
	query_interfaces();
	while (my $r=sql_getrow()){
		my $name=$servers[$r->{host}];
		$name=' ' unless defined $name;
		my $snet='';
		if ((defined ($r->{subnet})&&($r->{subnet} ne ''))){
			if (defined $subnets[$r->{subnet}]){
				$snet=$subnets[$r->{subnet}];
			}
		}
		$ar[0]=$r->{id};
		$ar[1]=$r->{macid};
		$ar[2]=$r->{ip};
		$ar[3]=$name;
		$ar[4]=$snet;
		$ar[5]=$r->{options};
		ml_insert(@ar);
	}
	ml_create();
}

#-----------------------------------------------------------------------
# Name        : listing_virtual
# Purpose     : Create a listing of all virtual systems
# Arguments   : parent - parent frame for the listing
# Returns     : 
# Globals     : $listing_server_frame
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub listing_virtual {
	(my $parent)=@_;
	debug($DEB_SUB,"listing_virtual");
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame()->pack();
	$listing_server_frame->Label(-text=>"Interfaces")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;
	$ar[1]=20;
	$ar[2]=20;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='Virtual';
	$ar[2]='Hypervisor';
	ml_colhead(@ar);
	my @servers=[];
	query_server();
	while(my $r=sql_getrow()){
		$servers[$r->{id}]=$r->{name};
	}
	query_server();
	while(my $r=sql_getrow()){
		my $host=-1;
		my $options=$r->{options};
		$options='' unless defined $options;
		if ($options=~/vboxhost:([^,]*)/){
			$host=$1;
			if ($host>-1){
				$ar[0]=$r->{id};
				$ar[1]=$r->{name};
				$ar[2]=$servers[$host];
				ml_insert(@ar);
			}
		}
	}
	ml_create();
}

#-----------------------------------------------------------------------
# Name        : listing_switch
# Purpose     : Create a listing of all switches
# Arguments   : parent - parent frame for the listing
# Returns     : 
# Globals     : $listing_server_frame
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub listing_switch {
	(my $parent)=@_;
	debug($DEB_SUB,"listing_switch");
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame()->pack();
	$listing_server_frame->Label(-text=>"Interfaces")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;
	$ar[1]=20;
	$ar[2]=20;
	$ar[3]= 5;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='Name';
	$ar[2]='Type';
	$ar[3]='Ports';
	ml_colhead(@ar);
	query_switch();
	while(my $r=sql_getrow()){
		$ar[0]=$r->{id};
		$ar[1]=$r->{name};
		$ar[1]='hoppa';
		$ar[2]=$r->{switch};
		$ar[3]=$r->{ports};
		if ($r->{switch} eq 'accesspoint'){ $ar[3]='-';}
		ml_insert(@ar);
	}
	ml_create();
}

#-----------------------------------------------------------------------
# Name        : listing_cloud
# Purpose     : Create a listing of all clouds
# Arguments   : parent - parent frame for the listing
# Returns     : 
# Globals     : $listing_server_frame
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub listing_cloud {
	(my $parent)=@_;
	debug($DEB_SUB,"listing_cloud");
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame()->pack();
	$listing_server_frame->Label(-text=>"Interfaces")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;
	$ar[1]=20;
	$ar[2]=20;
	$ar[3]=20;
	$ar[4]=20;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='Name';
	$ar[2]='Vendor';
	$ar[3]='Type';
	$ar[4]='Service';
	ml_colhead(@ar);
	query_cloud();
	while (my $r=sql_getrow()){
		$ar[0]=$r->{id};
		$ar[1]=$r->{name};
		$ar[2]=$r->{vendor};
		$ar[3]=$r->{type};
		$ar[4]=$r->{service};
		ml_insert(@ar);
	}
	ml_create();
}

sub listing_nfs {
	(my $parent)=@_;
	debug($DEB_SUB,"listing_nfs");
	$listing_server_frame->destroy if Tk::Exists($listing_server_frame);
	$listing_server_frame=$parent->Frame()->pack();
	$listing_server_frame->Label(-text=>"Interfaces")->pack();
	ml_new($listing_server_frame,$main_window_height*0.07,'top');
	my @ar;
	$ar[0]= 5;
	$ar[1]=20;
	$ar[2]=30;
	$ar[3]=20;
	$ar[4]=30;
	ml_colwidth(@ar);
	$ar[0]='ID';
	$ar[1]='Server';
	$ar[2]='Export';
	$ar[3]='Client';
	$ar[4]='Mount';
	ml_colhead(@ar);
	query_nfs();
	while ( my $r=sql_getrow()){
		$ar[0]=$r->{id};
		$ar[1]=$r->{server};
		$ar[2]=$r->{export};
		$ar[3]=$r->{client};
		$ar[4]=$r->{mountpoint};
		ml_insert(@ar);
	}
	ml_create();
}
	

1;
