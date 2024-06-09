
#INSTALL@ /opt/djedefre/connections.pm

#                                  _   _                 
#   ___ ___  _ __  _ __   ___  ___| |_(_) ___  _ __  ___ 
#  / __/ _ \| '_ \| '_ \ / _ \/ __| __| |/ _ \| '_ \/ __|
# | (_| (_) | | | | | | |  __/ (__| |_| | (_) | | | \__ \
#  \___\___/|_| |_|_| |_|\___|\___|\__|_|\___/|_| |_|___/
# 
#                       |_|     
use Tk::JBrowseEntry;

require dje_db;

our $main_window;
our $mainframe;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;

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
our %srv_id;

our @devicetypes;

our @if_access;
our @if_host;
our @if_hostname;
our @if_ifname;
our @if_id;
our @if_ip;
our @if_macid;
our @if_port;
our @if_subnet;
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

our $Message;

my $connect_listing_frame;	
my $connectionlist_frame;

my $connect_selected_frame;
my $connect_selected_entry_frame;
my $lastparent;
my $fromiffield;
my $toiffield;
my @fromiflist;

# The variables that were selected from the multi-column list.
# They are set in the sub connect_select_callback
my $sel_id;			
my $sel_from_tbl;
my $sel_from_id;
my $sel_from_if_name;
my $sel_from_port;
my $sel_from_if_host_id;
my $sel_from_if_host_name;
my $sel_to_tbl;
my $sel_to_id;
my $sel_to_if_name;
my $sel_to_port;
my $sel_to_if_host_id;
my $sel_to_if_host_name;
my $sel_vlan;
my $sel_source;

sub connections_input {
	debug($DEB_SUB,"connections_input");
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	$connectionlist_frame->destroy if Tk::Exists($connectionlist_frame);
	$connectionlist_frame=$main_frame->Frame()->pack(-side =>'top');
	mkconnectframe($connectionlist_frame);
	mkconnectselectedframe($connectionlist_frame);
}


sub connect_select_callback {
	(my $arg)=@_;
	$sel_id=$arg;
	$sel_from_tbl=$l2_from_tbl[$sel_id];
	$sel_from_id=$l2_from_id[$sel_id];
	$sel_from_if_name=$if_ifname[$sel_from_id];
	$sel_from_port=$l2_from_port[$sel_id];
	$sel_from_if_host_id=$if_host[$sel_from_id];
	$sel_from_if_host_name=$srv_name[$sel_from_if_host_id];
	
	$sel_to_tbl=$l2_to_tbl[$sel_id];
	$sel_to_id=$l2_to_id[$sel_id];
	$sel_to_if_name=$if_ifname[$sel_to_id];
	$sel_to_port=$l2_to_port[$sel_id];
	$sel_to_if_host_id=$if_host[$sel_to_id];
	$sel_to_if_host_name=$srv_name[$sel_to_if_host_id];
	$sel_vlan=$l2_vlan[$sel_id];
	$sel_source=$l2_source[$sel_id];

}



sub mkconnectframe {
	(my $parent)=@_;
	db_get_l2();
	db_get_interfaces();
	db_get_server();
	$connect_listing_frame>destroy if Tk::Exists($connect_listing_frame);
	$connect_listing_frame=$parent->Frame()->pack(-side =>'top');
	$connect_listing_frame->Label(-text=>"Connections")->pack()-side =>'top';
	ml_new($connect_listing_frame,25,'top');
	my @ar;
	$ar[0]=10;
	$ar[1]=10;
	$ar[2]=10;
	$ar[3]=10;
	$ar[4]=10;
	$ar[5]=10;
	$ar[6]=10;
	$ar[7]=10;
	$ar[8]=10;
	$ar[9]=10;
	$ar[10]=10;
	$ar[11]=10;
	$ar[12]=10;
	ml_colwidth(@ar);
	@ar=('ID','FROM','From-ID','IF name','Port','Host name','TO','To-ID','IF name','Port','Host name','VLAN','Source');
	ml_colhead(@ar);
	foreach my $id (@l2_id){
		next unless defined $id;
		my $from_if=$l2_from_id[$id];
		my $from_if_name=$if_ifname[$from_if];
		my $from_if_host=$if_host[$from_if];
		my $from_if_host_name=$srv_name[$from_if_host];
		my $to_if=$l2_to_id[$id];
		my $to_if_name=$if_ifname[$to_if];
		my $to_if_host=$if_host[$to_if];
		my $to_if_host_name=$srv_name[$to_if_host];

		$ar[0]=$id;
		$ar[1]=$l2_from_tbl[$id];
		$ar[2]=$l2_from_id[$id];
		$ar[3]=$from_if_name;
		$ar[4]=$l2_from_port[$id];
		$ar[5]=$from_if_host_name;
		$ar[7]=$l2_to_tbl[$id];
		$ar[6]=$l2_to_id[$id];
		$ar[8]=$to_if_name;
		$ar[9]=$l2_to_port[$id];
		$ar[10]=$to_if_host_name;
		$ar[11]=$l2_vlan[$id];
		$ar[12]=$l2_source[$id];
		ml_insert(@ar);
	}
	ml_create();
	ml_callback(\&connect_select_callback);
}

sub mkconnectselectedframe {
	(my $parent)=@_;
	$lastparent=$parent;
	my $localframe;
	my $jbrowse;
	my @usrvlist=uniq(@srv_name);
	my @srtsrvlist=sort @usrvlist;
	unshift (@srtsrvlist,'');
	my @uvlanlist=uniq(@l2_vlan);
	my @srtvlanlist=sort @uvlanlist;
	unshift(@srtvlanlist,'');
	splice @fromiflist;
	my @toiflist; splice @toiflist;
	$sel_from_if_host_name ='' unless defined $sel_from_if_host_name;
	if ($sel_from_if_host_name eq ''){
		@fromiflist=uniq(@if_ifname);
	}
	else {
		db_dosql("SELECT id FROM server WHERE name='$sel_from_if_host_name'");
		if((my $retval)=db_getrow()){
			push @fromiflist,'';
			db_dosql("SELECT ifname FROM interfaces WHERE host=$retval");
			while ((my $retval)=db_getrow()){
				push @fromiflist,$retval;
			}
		}
		else {
			$Message='Unknown hostname in FROM';
			@fromiflist=uniq(@if_ifname);
		}
	}

	@fromiflist=sort @fromiflist;
		@toiflist=sort @fromiflist;
	my @sourcelist=uniq(@l2_source);
	@sourcelist=sort @sourcelist;
	unshift (@sourcelist,"Manual");
	unshift (@sourcelist,"");
	my @tablelist=('','interfaces','switch');


	$connect_selected_frame->destroy if Tk::Exists($connect_selected_frame);
	$connect_selected_frame=$parent->Frame()->pack(-side =>'bottom');
	$connect_selected_entry_frame=$connect_selected_frame->Frame()->pack(-side =>'top');
	my $connect_selected_entry_frame_from=$connect_selected_entry_frame->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'left');
	$localframe=$connect_selected_entry_frame_from->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'FROM', -width =>10)->pack();

	$localframe=$connect_selected_entry_frame_from->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Table', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_from_tbl,
                -width=>17,
                -choices => \@tablelist,
                -height=>10
        )->pack(-side=>'left');

	$localframe=$connect_selected_entry_frame_from->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Server', -width =>10)->pack(-side =>'left');
        $fromiffield=$localframe->JBrowseEntry(
                -variable => \$sel_from_if_host_name,
                -width=>17,
                -choices => \@srtsrvlist,
                -height=>10,
        )->pack(-side=>'left');
	$fromiffield->bind('<<ComboboxSelected>>', \&refill_fromif);

	$localframe=$connect_selected_entry_frame_from->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Interface', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_from_if_name,
                -width=>17,
                -choices => \@fromiflist,
                -height=>10
        )->pack(-side=>'left');

	$localframe=$connect_selected_entry_frame_from->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'ID', -width =>10)->pack(-side =>'left');
	$localframe->Label(-anchor => 'w',-textvariable=>\$sel_from_id, -width =>20)->pack(-side =>'left');

	$localframe=$connect_selected_entry_frame_from->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Port', -width =>10)->pack(-side =>'left');
	$localframe->Entry(-textvariable=>\$sel_from_port, -width =>20)->pack(-side =>'left');

	my $connect_selected_entry_frame_to=$connect_selected_entry_frame->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'left');
	$localframe=$connect_selected_entry_frame_to->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'top');
	$localframe->Label(-text=>'TO', -width =>10)->pack();

	$localframe=$connect_selected_entry_frame_to->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Table', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_to_tbl,
                -width=>17,
                -choices => \@tablelist,
                -height=>10
        )->pack(-side=>'left');

	$localframe=$connect_selected_entry_frame_to->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Server', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_to_if_host_name,
                -width=>17,
                -choices => \@srtsrvlist,
                -height=>10
        )->pack(-side=>'left');

	$localframe=$connect_selected_entry_frame_to->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Interface', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_to_if_name,
                -width=>17,
                -choices => \@toiflist,
                -height=>10
        )->pack(-side=>'left');

	$localframe=$connect_selected_entry_frame_to->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'ID', -width =>10)->pack(-side =>'left');
	$localframe->Label(-anchor => 'w',-textvariable=>\$sel_to_id, -width =>20)->pack(-side =>'left');

	$localframe=$connect_selected_entry_frame_to->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Port', -width =>10)->pack(-side =>'left');
	$localframe->Entry(-textvariable=>\$sel_to_port, -width =>20)->pack(-side =>'left');

	my $connect_selected_entry_frame_rest=$connect_selected_entry_frame->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'left');
	$localframe=$connect_selected_entry_frame_rest->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'top');
	$localframe->Label(-text=>'Parameters', -width =>10)->pack(-side =>'left');

	$localframe=$connect_selected_entry_frame_rest->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'VLAN', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_vlan,
                -width=>17,
                -choices => \@srtvlanlist,
                -height=>10
        )->pack(-side=>'left');

	$localframe=$connect_selected_entry_frame_rest->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'Source', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_source,
                -width=>17,
                -choices => \@sourcelist,
                -height=>10
        )->pack(-side=>'left');

	$localframe=$connect_selected_entry_frame_rest->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'ConnectID', -width =>10)->pack(-side =>'left');
	$localframe->Label(-anchor => 'w',-textvariable=>\$sel_id, -width =>20)->pack(-side =>'left');

	$localframe=$connect_selected_entry_frame_rest->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'', -width =>10)->pack(-side =>'left');

	$localframe=$connect_selected_entry_frame_rest->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'', -width =>10)->pack(-side =>'left');

	my $connect_selected_entry_frame_button=$connect_selected_entry_frame->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'left');
	$localframe=$connect_selected_entry_frame_button->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'top');
	$localframe->Label(-text=>'Actions', -width =>10)->pack(-side =>'top');
	$localframe->Button(-text=>'Add',-width =>30,-command=>sub{do_button('add')})->pack(-side =>'top');
	$localframe->Button(-text=>'Change',-width =>30,-command=>sub{do_button('change')})->pack(-side =>'top');
	$localframe->Button(-text=>'Delete',-width =>30,-command=>sub{do_button('delete')})->pack(-side =>'top');
	$localframe->Label(-text=>'', -width =>10)->pack(-side =>'top');
}

sub do_button {
	(my $action)=@_;
	$Message= '';
	my $fromid;
	my $fromtype='';
	my $toid;
	my $totype='';
	$sel_vlan='' unless defined $sel_vlan;
	$sel_source='manual' unless defined $sel_source;
	if ($action eq 'delete'){
		db_dosql( "DELETE FROM l2connect WHERE id=$sel_id");
	}
	if ($action eq 'change'){
		db_dosql( "DELETE FROM l2connect WHERE id=$sel_id");
		$action='add'
	}
	if ($action eq 'add'){
		if ($sel_from_tbl eq 'interfaces'){
			$fromtype='interfaces';
			my $from_hostid=db_value("SELECT id FROM server WHERE name='$sel_from_if_host_name'");
			print "Adding from $sel_from_if_host_name ($from_hostid)\n";
			$sel_from_id=-1;
			if (defined ($from_hostid)){
				$sel_from_if_name='' unless defined $sel_from_if_name;
				my $retval=db_value("SELECT id FROM interfaces WHERE host=$from_hostid AND ifname='$sel_from_if_name'");
				$sel_from_id=$retval if defined $retval;
			}
			if ($sel_from_id==-1){
				$sel_from_id=db_value("SELECT id FROM interfaces WHERE host=$from_hostid");
			}
			$sel_from_port=0 unless defined $sel_from_port;
		}
		if ($sel_to_tbl eq 'interfaces'){
			$totype='interfaces';
			my $to_hostid=db_value("SELECT id FROM server WHERE name='$sel_to_if_host_name'");
			print "Adding to $sel_to_if_host_name ($to_hostid)\n";
			
			$sel_to_id=-1;
			if (defined ($to_hostid)){
				$sel_to_if_name='' unless defined $sel_to_if_name;
				my $retval=db_value("SELECT id FROM interfaces WHERE host=$to_hostid AND ifname='$sel_to_if_name'");
				$sel_to_id=$retval if defined $retval;
			}
			if ($sel_to_id==-1){
				$sel_to_id=db_value("SELECT id FROM interfaces WHERE host=$to_hostid");
			}
			$sel_to_port=0 unless defined $sel_to_port;
		}
		$sel_vlan=0 unless defined $sel_vlan;
		db_dosql ("INSERT INTO l2connect (from_tbl,from_id,from_port,to_tbl,to_id,to_port,vlan,source) VALUES ('$fromtype',$sel_from_id,$sel_from_port,'$totype',$sel_to_id,$sel_to_port,'$sel_vlan','$sel_source')\n");
	
	}
	mkconnectselectedframe($lastparent);
}
sub refill_fromif{
	db_dosql("SELECT id FROM server WHERE name='$sel_from_if_host_name'");
	splice @fromiflist;
	if((my $retval)=db_getrow()){
		print "Only interfaces from $sel_from_if_host_name ($retval)\n";
		push @fromiflist,'';
		db_dosql("SELECT ifname FROM interfaces WHERE host=$retval");
		while ((my $retval)=db_getrow()){
			push @fromiflist,$retval;
		}
	}
	else {
		$Message='Unknown hostname in FROM';
		@fromiflist=uniq(@if_ifname);
	}
	@fromiflist=sort @fromiflist;
	$fromiffield->configure(-choices => \@fromiflist);
}
#id          vlan        from_tbl    from_id     from_port   to_tbl      to_id       to_port     source
1;
