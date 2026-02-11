
#INSTALL@ /opt/djedefre/connections.pm
use strict;
use warnings;

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
our $main_frame;

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
my @sort_if_ip;

# The variables that were selected from the multi-column list.
# They are set in the sub connect_select_callback
my $sel_id;			
my $sel_from_tbl;
my $sel_from_id;
my $sel_from_ip;
my $sel_from_if_name;
my $sel_from_port;
my $sel_from_if_host_id;
my $sel_from_if_host_name;
my $sel_to_tbl;
my $sel_to_id;
my $sel_to_ip;
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
	@sort_if_ip=sort @if_ip;
	mkconnectframe($connectionlist_frame);
	mkconnectselectedframe($connectionlist_frame);
}


sub connect_select_callback {
	(my $arg)=@_;
	$sel_id=$arg;
	$sel_from_tbl=$l2_from_tbl[$sel_id];
	$sel_from_id=$l2_from_id[$sel_id];
	$sel_from_if_name=$if_ifname[$sel_from_id];
	$sel_from_ip=$if_ip[$sel_from_id];
	$sel_from_port=$l2_from_port[$sel_id];
	$sel_from_if_host_id=$if_host[$sel_from_id];
	$sel_from_if_host_name=$srv_name[$sel_from_if_host_id];
	
	$sel_to_tbl=$l2_to_tbl[$sel_id];
	$sel_to_id=$l2_to_id[$sel_id];
	$sel_to_if_name=$if_ifname[$sel_to_id];
	$sel_to_ip=$if_ip[$sel_to_id];
	$sel_to_port=$l2_to_port[$sel_id];
	$sel_to_if_host_id=$if_host[$sel_to_id];
	$sel_to_if_host_name=$srv_name[$sel_to_if_host_id];
	$sel_vlan=$l2_vlan[$sel_id];
	$sel_source=$l2_source[$sel_id];

}


my @switchname;


sub mkconnectframe {
	(my $parent)=@_;
	db_get_l2();
	db_get_interfaces();
	db_get_server();
	db_dosql("SELECT id,name FROM switch");
	while ((my $id, my $name)=db_getrow()){ $switchname[$id]=$name;}
	db_close();
	$connect_listing_frame->destroy if Tk::Exists($connect_listing_frame);
	$connect_listing_frame=$parent->Frame()->pack(-side =>'top');
	$connect_listing_frame->Label(-text=>"Connections")->pack(-side =>'top');
	ml_new($connect_listing_frame,25,'top');
	my @ar;
	$ar[0]=5;
	$ar[1]=10;
	$ar[2]=5;
	$ar[3]=15;
	$ar[4]=15;
	$ar[5]=5;
	$ar[6]=15;
	$ar[7]=10;
	$ar[8]=5;
	$ar[9]=15;
	$ar[10]=15;
	$ar[11]=5;
	$ar[12]=15;
	$ar[13]=10;
	$ar[14]=10;
	ml_colwidth(@ar);
	@ar=('ID','FROM','Fr-ID','IF name','IP','Port','Host name','TO','To-ID','IF name','IP','Port','Host name','VLAN','Source');
	ml_colhead(@ar);
	foreach my $id (@l2_id){
		next unless defined $id;
		my $from_if;
		my $from_ip;
		my $from_if_name;
		my $from_if_host;
		my $from_if_host_name;
		my $to_if;
		my $to_ip;
		my $to_if_name;
		my $to_if_host;
		my $to_if_host_name;
		my $fromport='';
		my $toport='';
		if ($l2_from_port[$id] < 10000){$fromport=$l2_from_port[$id];}
		if ($l2_to_port[$id]   < 10000){$toport=  $l2_to_port[$id];}

		$from_if=$l2_from_id[$id];
		$from_if_name=$if_ifname[$from_if];
		$from_ip=$if_ip[$from_if];
		$from_if_host=$if_host[$from_if];
		if ($l2_from_tbl[$id] eq 'switch'){
			$from_if_host_name=$switchname[$from_if];
		}
		else {
			$from_if_host_name=$srv_name[$from_if_host];
		}
		$to_if=$l2_to_id[$id];
		$to_if_name=$if_ifname[$to_if];
		$to_ip=$if_ip[$to_if];
		$to_if_name="$if_ifname[$to_if]";
		$to_if_host=$if_host[$to_if];
		#if ($l2_to_tbl[$id] eq 'switch'){ $to_if_host_name=$switchname[$to_if]; } else { $to_if_host_name="$if_ifname[$to_if]";}

		if ($l2_to_tbl[$id] eq 'switch'){
			$to_if_host_name=$switchname[$to_if];
		}
		else {
			$to_if_host_name=$srv_name[$to_if_host];
		}
		$ar[0]=$id;
		$ar[1]=$l2_from_tbl[$id];
		$ar[2]=$l2_from_id[$id];
		$ar[3]=$from_if_name;
		$ar[4]=$from_ip;
		$ar[5]=$fromport;
		$ar[6]=$from_if_host_name;
		$ar[7]=$l2_to_tbl[$id];
		$ar[8]=$l2_to_id[$id];
		$ar[9]=$to_if_name;
		$ar[10]=$to_ip;
		$ar[11]=$toport;
		$ar[12]=$to_if_host_name;
		$ar[13]=$l2_vlan[$id];
		$ar[14]=$l2_source[$id];
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
	my @objlist=@srv_name;
	db_dosql("SELECT name FROM switch");
	while ((my $nme)=db_getrow()){
		push @objlist,$nme;
	}
	db_close();
	@sort_if_ip=uniq( @if_ip);
	@sort_if_ip=sort @sort_if_ip;
	my @usrvlist=uniq(@objlist);
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
		#db_dosql("SELECT id FROM server WHERE name='$sel_from_if_host_name'");

		@fromiflist=uniq(@if_ifname);
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
	$localframe->Label(-anchor => 'w',-text=>'IP', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_from_ip,
                -width=>17,
                -choices => \@sort_if_ip,
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
	$localframe->Label(-anchor => 'w',-text=>'IP', -width =>10)->pack(-side =>'left');
        $localframe->JBrowseEntry(
                -variable => \$sel_to_ip,
                -width=>17,
                -choices => \@sort_if_ip,
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

	$localframe=$connect_selected_entry_frame_rest->Frame()->pack(-side =>'top');
	$localframe->Label(-anchor => 'w',-text=>'', -width =>10)->pack(-side =>'left');

	my $connect_selected_entry_frame_button=$connect_selected_entry_frame->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'left');
	$localframe=$connect_selected_entry_frame_button->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-side =>'top');
	$localframe->Label(-text=>'Actions', -width =>10)->pack(-side =>'top');
	$localframe->Button(-text=>'Add',-width =>30,-command=>sub{do_button('add')})->pack(-side =>'top');
	$localframe->Button(-text=>'Change',-width =>30,-command=>sub{do_button('change')})->pack(-side =>'top');
	$localframe->Button(-text=>'Delete',-width =>30,-command=>sub{do_button('delete')})->pack(-side =>'top');
	$localframe->Label(-text=>'', -width =>10)->pack(-side =>'top');
	$localframe->Label(-text=>'', -width =>10)->pack(-side =>'top');
}

sub do_button {
	(my $action)=@_;
	$Message= '';
	my $fromid;
	my $fromtype='';
	my $toid;
	my $totype='';
	my $retval;
	$sel_vlan='' unless defined $sel_vlan;
	$sel_source='manual' unless defined $sel_source;
print "to=$sel_to_ip from=$sel_from_ip\n";
	if ($action eq 'delete'){
		db_dosql( "DELETE FROM l2connect WHERE id=$sel_id");
		db_close();
	}
	if ($action eq 'change'){
		db_dosql( "DELETE FROM l2connect WHERE id=$sel_id");
		db_close();
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
				$retval=db_value("SELECT id FROM interfaces WHERE ip='$sel_from_ip'");
				$sel_from_id=$retval if defined $retval;
			}
			if ($sel_from_id==-1){
				$sel_from_id=db_value("SELECT id FROM interfaces WHERE host=$from_hostid");
			}
			if ("$sel_from_port" eq ""){$sel_from_port="NULL";}
			$sel_from_port=10000 unless defined $sel_from_port;
		}
		if ($sel_from_tbl eq 'switch'){
			$fromtype='switch';
			my $from_swid=db_value("SELECT id FROM switch WHERE name='$sel_from_if_host_name'");
			$sel_from_id=$from_swid;
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
				$retval=db_value("SELECT id FROM interfaces WHERE ip='$sel_to_ip'");
				$sel_to_id=$retval if defined $retval;
			}
			if ($sel_to_id==-1){
				my $ip_id=db_value("SELECT id FROM interfaces WHERE host=$to_hostid");
				
			}
			#$sel_to_port=10000 unless defined $sel_to_port;
			if ("$sel_to_port" eq ""){$sel_to_port="NULL";}
		}
		if ($sel_to_tbl eq 'switch'){
			$totype='switch';
			my $to_swid=db_value("SELECT id FROM switch WHERE name='$sel_to_if_host_name'");
			$sel_to_id=$to_swid;
		}
		$sel_vlan=0 unless defined $sel_vlan;
		db_dosql ("INSERT INTO l2connect (from_tbl,  from_id,     from_port,      to_tbl,  to_id,     to_port,      vlan,        source)
		           VALUES (              '$fromtype',$sel_from_id,$sel_from_port,'$totype',$sel_to_id,$sel_to_port,'$sel_vlan','$sel_source')");
	
	}
	mkconnectselectedframe($lastparent);
}
sub refill_fromif{
	db_dosql("SELECT id FROM server WHERE name='$sel_from_if_host_name'");
	splice @fromiflist;
	@fromiflist=uniq(@if_ifname);
	@fromiflist=sort @fromiflist;
	$fromiffield->configure(-choices => \@fromiflist);
}
#id          vlan        from_tbl    from_id     from_port   to_tbl      to_id       to_port     source
1;
