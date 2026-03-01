
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
our $Message;

# our-list that must be removed




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

#-----------------------------------------------------------------------
# Name        : connections_input
# Purpose     : Called when input->connections is selected from the menus
# Arguments   : 
# Returns     : 
# Globals     : $main_frame, $connectionlist_frame
# Side-effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub connections_input {
	debug($DEB_SUB,"connections_input");
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	$connectionlist_frame->destroy if Tk::Exists($connectionlist_frame);
	$connectionlist_frame=$main_frame->Frame()->pack(-side =>'top');
	@sort_if_ip=query_if_ip();
	mkconnectframe($connectionlist_frame);
	mkconnectselectedframe($connectionlist_frame);
}


#-----------------------------------------------------------------------
# Name        : connect_select_callback
# Purpose     : Called when a connection is selected from the list. The
#		global variables in the mkconnectselectedframe are set
#		from the selected line.
# Arguments   : sel_id - the id of the selected connection
# Returns     : 
# Globals     : $sel_id
#		$sel_from_tbl
#		$sel_from_id
#		sel_from_port
#		$sel_to_tbl
#		$sel_to_id
#		$sel_to_port
#		$sel_vlan
#		$sel_source
#		$sel_from_if_name
#		$sel_from_ip
#		$sel_from_if_host_id
#		$sel_from_if_host_name
#		$sel_to_if_name
#		$sel_to_ip
#		$sel_to_if_host_id
#		$sel_to_if_host_name
# Side-effects: The fields in the connectselectedframe are set.
# Notes       : 
#-----------------------------------------------------------------------
sub connect_select_callback {
	(my $arg)=@_;
	$sel_id=$arg;
	query_l2_by_id($sel_id);
	my $r=sql_getrow();
	$sel_from_tbl=$r->{from_tbl};
	$sel_from_id=$r->{from_id};
	$sel_from_port=$r->{from_port};
	$sel_to_tbl=$r->{to_tbl};
	$sel_to_id=$r->{to_id};
	$sel_to_port=$r->{to_port};
	$sel_vlan=$r->{vlan};
	$sel_source=$r->{source};

	query_if_by_id($sel_from_id);
	$r=sql_getrow();
	$sel_from_if_name=$r->{ifname};
	$sel_from_ip=$r->{ip};
	$sel_from_if_host_id=$r->{host};

	$sel_from_if_host_name=q_server('name',$sel_from_if_host_id);
	
	query_if_by_id($sel_to_id);
	$r=sql_getrow();
	$sel_to_if_name=$r->{ifname};
	$sel_to_ip=$r->{ip};
	$sel_to_if_host_id=$r->{host};

	$sel_to_if_host_name=q_server('name',$sel_to_if_host_id);

}



#-----------------------------------------------------------------------
# Name        : mkconnectframe
# Purpose     : Using a multilist, create a frame with all the connections
#		in l2connect. Add information from other tables as well.
# Arguments   : parent frame 
# Returns     : 
# Globals     : 
# Side-effects: 
# Notes       :
#-----------------------------------------------------------------------
sub mkconnectframe {
	(my $parent)=@_;
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
	my @l2_id=query_l2_ids();
	foreach my $id (@l2_id){
		next unless defined $id;
		my $from_if=q_l2connect('from_id',$id);
		my $to_if=q_l2connect('to_id',$id);
		my $from_tbl=q_l2connect('from_tbl',$id);
		my $to_tbl=q_l2connect('to_tbl',$id);
		my $fromport=q_l2connect('from_port',$id); 
		$fromport='' unless defined $fromport;
		if ($fromport =~ /^\d+$/ && $fromport> 9999){$fromport='';}
		my $toport=q_l2connect('to_port',$id);
		$toport='' unless defined $toport;
		if ($toport =~ /^\d+$/ && $toport> 9999){$toport='';}

		my $from_ip     =q_interfaces('ip'    ,$from_if);
		my $from_if_name=q_interfaces('ifname',$from_if);
		my $from_if_host=q_interfaces('host'  ,$from_if);

		my $to_ip       =q_interfaces('ip'    ,$to_if);
		my $to_if_name  =q_interfaces('ifname',$to_if);
		my $to_if_host  =q_interfaces('host'  ,$to_if);

		my $from_if_host_name;
		my $to_if_host_name;

		if ($from_tbl eq 'switch'){
			$from_if_host_name=q_switch('name',$from_if);
		}
		else {
			$from_if_host_name=q_server('name',$from_if_host);
		}
		if ($to_tbl eq 'switch'){
			$to_if_host_name=q_switch('name',$to_if);
		}
		else {
			$to_if_host_name=q_server('name',$to_if_host);
		}
		$ar[0]=$id;
		$ar[1]=$from_tbl;
		$ar[2]=q_l2connect('from_id',$id);
		$ar[3]=$from_if_name;
		$ar[4]=$from_ip;
		$ar[5]=$fromport;
		$ar[6]=$from_if_host_name;
		$ar[7]=$to_tbl;
		$ar[8]=q_l2connect('to_id',$id);
		$ar[9]=$to_if_name;
		$ar[10]=$to_ip;
		$ar[11]=$toport;
		$ar[12]=$to_if_host_name;
		$ar[13]=q_l2connect('vlans',$id);
		$ar[14]=q_l2connect('source',$id);
		ml_insert(@ar);
	}
	ml_create();
	ml_callback(\&connect_select_callback);
}

#-----------------------------------------------------------------------
# Name        : mkconnectselectedframe
# Purpose     : Make the fill-in list below the listing frame.
# Arguments   : parent frame 
# Returns     : 
# Globals     : All content of the fields are global, but local to this file
#		$sel_from_tbl
#		$sel_from_if_host_name
#		$sel_from_if_name
#		$sel_from_ip
#		$sel_from_id
#		$sel_from_port
#		$sel_to_tbl
#		$sel_to_if_host_name
#		$sel_to_if_name
#		$sel_to_ip
#		$sel_to_id
#		$sel_to_port
#		$sel_vlan
#		$sel_source
#		$sel_id
# Side-effects: 
# Notes       :
#-----------------------------------------------------------------------
sub mkconnectselectedframe {
	(my $parent)=@_;
	my $ref;
	$lastparent=$parent;
	my $localframe;
	my $jbrowse;
	my @objlist=query_server_names();
	my @tmp=query_switch_names();
	push @objlist,@tmp;
	@sort_if_ip=query_if_ip();
	unshift (@sort_if_ip,'');
	my @srtsrvlist=uniq(@objlist);
	unshift (@srtsrvlist,'');
	@srtsrvlist=sort @srtsrvlist;
	my @srtvlanlist=query_l2_getvlans();
	unshift(@srtvlanlist,'');
	$sel_from_if_host_name ='' unless defined $sel_from_if_host_name;
	my @fromiflist=query_if_names();
	my @toiflist=@fromiflist;
	my @sourcelist=query_l2_sources();
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
	if ($action eq 'delete'){
		query_l2_delete($sel_id);
	}
	if ($action eq 'change'){
		query_l2_delete($sel_id);
		$action='add'
	}
	if ($action eq 'add'){
		if ($sel_from_tbl eq 'interfaces'){
			$fromtype='interfaces';
			my $from_hostid=q_server_by_name('id',$sel_from_if_host_name);
			$sel_from_id=-1;
			if (defined ($from_hostid)){
				$sel_from_if_name='' unless defined $sel_from_if_name;
				my $retval=query_if_by_host_ifname($from_hostid,$sel_from_if_name);
				$sel_from_id=$retval if defined $retval;
			}
			if ($sel_from_id==-1){
				$retval=query_if_id_by('ip',$sel_from_ip);
				$sel_from_id=$retval if defined $retval;
			}
			if ($sel_from_id==-1){
				$sel_from_id=query_if_id_by('host',$from_hostid);
			}
			if ("$sel_from_port" eq ""){$sel_from_port="NULL";}
			$sel_from_port=10000 unless defined $sel_from_port;
		}
		if ($sel_from_tbl eq 'switch'){
			$fromtype='switch';
			my $from_swid=q_switch_id_by('name',$sel_from_if_host_name);
			$sel_from_id=$from_swid;
		}
		if ($sel_to_tbl eq 'interfaces'){
			$totype='interfaces';
			my $to_hostid=q_server_by_name('id',$sel_to_if_host_name);
			
			$sel_to_id=-1;
			if (defined ($to_hostid)){
				$sel_to_if_name='' unless defined $sel_to_if_name;
				my $retval=query_if_by_host_ifname($to_hostid,$sel_to_if_name);
				$sel_to_id=$retval if defined $retval;
			}
			if ($sel_to_id==-1){
				$retval=query_if_id_by('ip',$sel_to_ip);
				$sel_to_id=$retval if defined $retval;
			}
			if ($sel_to_id==-1){
				$sel_from_id=query_if_id_by('host',$to_hostid);
				
			}
			#$sel_to_port=10000 unless defined $sel_to_port;
			if ("$sel_to_port" eq ""){$sel_to_port="NULL";}
		}
		if ($sel_to_tbl eq 'switch'){
			$totype='switch';
			my $to_swid=q_switch_id_by('name',$sel_to_if_host_name);
			$sel_to_id=$to_swid;
		}
		$sel_vlan=0 unless defined $sel_vlan;
		query_l2_insert($fromtype,$sel_from_id,$sel_from_port,$totype,$sel_to_id,$sel_to_port,$sel_vlan,$sel_source);
	}
	mkconnectselectedframe($lastparent);
}
sub refill_fromif{
	my @fromiflist=query_if_names();
	$fromiffield->configure(-choices => \@fromiflist);
}
#id          vlan        from_tbl    from_id     from_port   to_tbl      to_id       to_port     source
1;
