
#INSTALL@ /opt/djedefre/srvinput.pm
#INSTALLEDFROM verlaine:/home/ljm/Dropbox/src/djedefre

use strict;
use warnings;

require dje_db;

our $main_window;
our $mainframe;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;

my $selected_srv;
my $srvinput_frame;

sub srvinput {
	debug($DEB_SUB,"l2input");
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame(
		#-height      => 0.8*$main_window_height,
		#-width       => $main_window_width
	)->pack(-side =>'top');
	$srvinput_frame->destroy if Tk::Exists($connectionlist_frame);
	$srvinput_frame=$main_frame->Frame()->pack(-side =>'top');
	mksrvinpuframe($srvinput_frame);
	mksrvinpuframe($srvinput_frame);
}
	
my $l2_selected_frame;
my $l2_selected_entry_frame;
my $l2_selected_button_frame;
sub srvinpuframe {
	(my $parent)=@_;
	$l2_selected_frame->destroy if Tk::Exists($l2_selected_frame);
	$l2_selected_frame=$parent->Frame()->pack(-side =>'bottom');
	$l2_selected_entry_frame=$l2_selected_frame->Frame()->pack(-side =>'top');
	$l2_selected_entry_frame->Entry ( -textvariable => \$id,        -width => 5,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$from_tbl,  -width =>10,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$fromhost,  -width =>15,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$fromif,    -width =>15,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$from_port, -width => 5,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$to_tbl,    -width =>10,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$tohost,    -width =>15,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$toif,      -width =>15,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$to_port,   -width => 5,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Entry ( -textvariable => \$to_port,   -width =>10,-font=>"arial 14")->pack(-side=>left);
	$l2_selected_entry_frame->Label(-text=>'.',-font=>"arial 14",-width=>2)->pack(-side=>left);
	$l2_selected_button_frame=$l2_selected_frame->Frame()->pack(-side =>'bottom');
	$l2_selected_button_frame->Button ( -width=>20,-text=>'Add'   )->pack(-side=>left);
	$l2_selected_button_frame->Button ( -width=>20,-text=>'Change')->pack(-side=>left);
	$l2_selected_button_frame->Button ( -width=>20,-text=>'Delete', -command=>sub{ print "del\n";l2deleteentry(); mkl2connectframe($connectionlist_frame); })->pack(-side=>left);
}
sub l2deleteentry {
	(my $id)=@_;
	print "DELETE FROM l2connect WHERE id=$id\n";
	db_dosql ("DELETE FROM l2connect WHERE id=$id");
	undef $ids[$id];
}

sub l2changeentry{
	if ($from_tbl =~/^i/){$from_tbl='interfaces';}
	elsif ($from_tbl =~/^a/){$from_tbl='switch';}
	elsif ($from_tbl =~/^s/){$from_tbl='switch';}
	# to be done
	db_get_interfaces();
	db_get_server();
	db_get_l2();
	
}

my $l2_listing_frame;
sub mkl2connectframe {
	(my $parent)=@_;
	db_get_interfaces();
	db_get_server();
	db_get_l2();
	db_get_sw();
	splice @fromhosts;
	splice @tohosts;
	
	$l2_listing_frame->destroy if Tk::Exists($l2_listing_frame);
	$l2_listing_frame=$parent->Frame()->pack(-side =>'top');
	$l2_listing_frame->Label(-text=>"Connections")->pack()-side =>'top';
	ml_new($l2_listing_frame,25,'top');
	my @ar;
	$ar[0]= 5;	#id
	$ar[1]=10;	#from type
	$ar[2]=10;	#from type
	$ar[3]=15;	#from host
	$ar[4]=15;	#from interface
	$ar[5]= 5;	#from port
	$ar[6]=10;	#to type
	$ar[7]=15;	#to host
	$ar[8]=15;	#to Interface
	$ar[9]= 5;	#to port
	$ar[10]=10;	#vlan
	ml_colwidth(@ar);
	splice @ar;
	@ar=('ID','From',"IF",'Name','Interface','Port','To','Name','Interface','Port','VLAN');
	ml_colhead(@ar);
	foreach my $id (@l2_id){
		next unless defined $id;
		my $fromhost='';
		my $fromif='';
		my $fromifname='';
		my $from_id=sql_l2_from_id($id);
		if ( $l2_from_tbl[$id]  eq 'switch' ){
			$fromhost=$sw_name[$from_id];
		}
		else {
			my $fromhostid=$if_host[$from_id];
			if (defined ($srv_name[$fromhostid])) {
				$fromhosts[$id]=$srv_name[$fromhostid];
			}
			else {
				$fromhosts[$id]=$fromid;
			}
			$fromif=$if_ip[$from_id];
			$fromifname=$if_ifname[$from_id] if defined $if_ifname[$from_id];
		}
		my $tohost='';
		my $toif='';
		my $to_id=$l2_to_id[$id];
		if ( $l2_to_tbl[$id] eq 'switch' ){
			$tohost=$sw_name[$to_id];
		}
		else {
			my $tohostid=$if_host[$to_id];
			if (defined ($srv_name[$tohostid])) {
				$tohosts[$id]=$srv_name[$tohostid];
			}
			else {
				$tohosts[$id]=$toid;
			}
			$toif=$if_ip[$to_id];
			$toifname=$if_ifname[$to_id] if defined $if_ifname[$to_id];
		}
		
#		$from_ifnames[$id]=$fromifname;
		$tohosts[$id]=$tohost;
	}
	foreach my $id (@l2_id){
		next unless defined $id;
		splice @ar;
		$ar[0]='';
		$ar[1]='';
		$ar[2]='';
		$ar[3]='';
		$ar[4]='';
		$ar[5]='';
		$ar[6]='';
		$ar[7]='';
		$ar[8]='';
		$ar[9]='';
		$ar[10]='';
		$ar[0]=$id               if defined $id;
		$ar[1]=$l2_from_tbl[$id] if defined $l2_from_tbl[$id];
		$ar[2]=$from_ifnames[$id]if defined $from_ifnames[$id];
		$ar[3]=$fromhosts[$id]   if defined $fromhosts[$id];
		$ar[4]=$l2_from_id[$id]  if defined $l2_from_id[$id];
		$ar[5]=$l2_from_port[$i] if defined $l2_from_port[$i];
		$ar[6]=$l2_to_tbl[$id]   if defined $l2_to_tbl[$id];
		$ar[7]=$tohosts[$id]     if defined $tohosts[$id];
		$ar[8]=$l2_to_id[$id]    if defined $l2_to_id[$id];
		$ar[9]=$l2_to_port[$id]  if defined $l2_to_port[$id];
		$ar[10]=$l2_vlan[$id]     if defined $l2_vlan[$id];
		ml_insert(@ar);

	}
	ml_create();
	ml_callback(\&l2connect_callback);
}


sub l2connect_callback {
	(my $i)=@_;
	$id        =   '';
	$from_tbl  =   '';
	$fromhosts =   '';
	$fromif    =   '';
	$fromif    =   '';
	$from_port =   '';
	$to_tbl    =   '';
	$tohost    =   '';
	$toif      =   '';
	$to_port   =   '';
	$vlan      =   '';
	$id       = $ids[$i]        if defined $ids[$i];
	$from_tbl = $from_tbls[$i]  if defined $from_tbls[$i];
	$fromhost = $fromhosts[$i]  if defined $fromhosts[$i];
	$fromif   = $fromifs[$i]    if defined $fromifs[$i];
	$from_port= $from_ports[$i] if defined $from_ports[$i];
	$to_tbl   = $to_tbls[$i]    if defined $to_tbls[$i];
	$tohost   = $tohosts[$i]    if defined $tohosts[$i];
	$toif     = $toifs[$i]      if defined $toifs[$i];
	$to_port  = $to_ports[$i]   if defined $to_ports[$i];
	$vlan     = $vlans[$i]      if defined $vlans[$i];
}
	
1;
