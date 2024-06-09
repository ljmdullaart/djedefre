
#INSTALL@ /opt/djedefre/ifconnect.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

#  _  __                         _   
# (_)/ _| ___ ___  _ __  _ __   ___  ___| |_ 
# | | |_ / __/ _ \| '_ \| '_ \ / _ \/ __| __|
# | |  _| (_| (_) | | | | | | |  __/ (__| |_ 
# |_|_|  \___\___/|_| |_|_| |_|\___|\___|\__|
# 


require dje_db;

our $main_window;
our $mainframe;

our @l2_vlan;
our @l2_from_tbl;
our @l2_from_id;
our @l2_from_port;
our @l2_to_tbl;
our @l2_to_id;
our @l2_to_port;

our @srv_name;
our @srv_xcoord;
our @srv_ycoord;
our @srv_type;
our @srv_interfaces;
our @srv_devicetype;
our @srv_status;
our @srv_last_up;
our @srv_options;
our @srv_ostype;
our @srv_os;
our @srv_processor;
our @srv_memory;
our %srv_id;

our @if_id;
our @if_macid;
our @if_ip;
our @if_hostname;
our @if_name;
our @if_host;
our @if_subnet;
our @if_access;
our @if_switch;
our @if_port;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;

my ($inif,$intoserver,$intoipaddress,$intohost,$intoif,$intoport)=('-','-','-','-','-','-');


sub ifc_prt_cb {
	(my $id)=@_;
	debug($DEB_SUB,"ifc_prt_cb");
	print "Selected if $id\n";
	$inif=$id;
	my $i=$ifindex[$id];
	$intoserver=$ifsrvname[$i];
	$intoipaddress=$ifip[$i];
	$intohost=$ifhost[$toif[$i]];
	$intoif=$toif[$i];
	$intoport=$toport[$i];
	if ($intoif == -1){
		$intohost='-';
		$intoport='-';
		$intoif='-';
	}
	print "	$ifid[$i],$ifsrvname[$i],$ifip[$i],$toif[$i],$toport[$i]\n";
}

my $intoifframe;
my $intoifmenu;

sub ifconnect {
	debug($DEB_SUB,"ifconnect");
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	my $listingframe = $main_frame->Frame(-height=>600)->pack(-side =>'top');
	my $setframe=$main_frame->Frame()->pack(-side =>'bottom');
	db_get_interfaces();
	db_get_server;
	db_get_l2;
	ml_new($listingframe,25,'top');
	my @ar;
	$ar[0]=10;	# from ifid
	$ar[1]=20;	# from server name
	$ar[2]=20;	# from ip address
	$ar[3]=10;	# from port
	$ar[4]=10;	# to ifid
	$ar[5]=20;	# to server name
	$ar[6]=20;	# to ip
	$ar[7]=10;	# to port
	$ar[8]= 8;	# vlan

	ml_colwidth(@ar);
	@ar=('from IF','from Server','from IP address','from port','to IF','to server','to IP address','to port','VLAN');
	ml_colhead(@ar);
	print "$#if_id;\n";
	for (my $i=0; $i<=$#if_id; $i++){
		print "	$i:\n";
		if (defined($if_id[$i])){
			print "		if_id[$i]=$if_id[$i]\n";
			print "		if_ip[$i]=$if_ip[$i]\n";
			my $fromhost=' ';
			my $fromname=' ';
			my $fromip=' ';
			my $fromport=' ';
			my $toid=' ';
			my $toport=' ';
			my $totbl=' ';
			my $vlan=' ';
			if (defined($if_host[$i])){
				$fromhost=$if_host[$i];
				$fromname=$srv_name[$fromhost];
			}
			splice @ar;
			$ar[0]=$if_id[$i];
			$ar[1]=$fromname;
			$ar[2]=$if_ip[$i];
			my @connections;
			splice @connections;
			for (my $j=0; $j<$#$l2_fromid;$j++){
				if (($l2_from_tbl[$j] eq 'interfaces') && ($l2_from_id[$j]==$if_id[$i])){
					push @connections,"$l2_from_port[$j];$l2_to_id[$j];$l2_to_port[$j];$l2_to_tbl[$j];$l2_vlan[$j]";
				}
				if (($l2_to_tbl[$j] eq 'interfaces') && ($l2_to_id[$j]==$if_id[$i])){
					push @connections,"$l2_to_port[$j];$l2_from_id[$j];$l2_from_port[$j];$l2_from_tbl[$j];$l2_vlan[$j]";
				}
			}
			my @tmp=uniq(@connections);
			my @connections=sort @tmp;

			for (@connections){
				print "		$_\n";
				($fromport,$toid,$toport,$totbl,$vlan)=split ';';
				$ar[3]=$fromport;
				$ar[4]=$toid;
				my $tohost=-1;
				my $toname=' ';
				my $toip=' ';
				if (defined($if_host[$toid])){
					$tohost=$if_host[$toid];
					$toname=$srv_name[$tohost];
				}
				$toip=$if_ip[$if_host[$toid]] if (defined ($if_ip[$if_host[$toid]]));
					
				$ar[5]=$toname;	# to server name
				$ar[6]=$toip;	# to ip
				$ar[7]=$totbl;
				$ar[8]=$vlan;
			}
			ml_insert(@ar);
		}
	}
	ml_create();
	ml_callback(\&ifc_prt_cb);
	@allsrv=uniq(@ifsrvname);
	@allsrv=sort @allsrv;
	$setframe->Label (-anchor => 'w',-width=>10,-font=>"arial 14",-textvariable=>\$inif)->pack(-side=>'left');
	$setframe->Label (-anchor => 'w',-width=>20,-font=>"arial 14",-textvariable=>\$infromserver)->pack(-side=>'left');
	$setframe->Label (-anchor => 'w',-width=>20,-font=>"arial 14",-textvariable=>\$infromipaddress)->pack(-side=>'left');
	$setframe->Label (-anchor => 'w',-width=>20,-font=>"arial 14",-textvariable=>\$intoserver)->pack(-side=>'left');
	$setframe->Label (-anchor => 'w',-width=>20,-font=>"arial 14",-textvariable=>\$intoipaddress)->pack(-side=>'left');
	$setframe->JBrowseEntry(
		-variable => \$intohost,
		-width=>18,
		-choices => \@allsrv,
		-height=>10,
		-font=>"arial 14",
		-browsecmd => sub { intohost_selected() }
		)->pack(-side=>'left');

	$intoifframe=$setframe->Frame ()->pack(-side=>'left');
	$intoifmenu=$intoifframe->JBrowseEntry(
		-variable => \$intoif,
		-width=>3,
		-choices => \@ifselect,
		-height=>10,
		-font=>"arial 14",
		-browsecmd => sub { print "Selected $intoif\n";}
		)->pack(-side=>'left');
	$setframe->Entry (-width=>5,-font=>"arial 14",-textvariable=>\$intoport)->pack(-side=>'left');
	$setframe->Button (-width=>2,-font=>"arial 14",-text=>"set")->pack(-side=>'left');
	
}
		
	
sub intohost_selected {
	debug($DEB_SUB,"intohost_selected");
	my $hostid=999999;
	splice @ifselect;
	$hostid=$serverhash{$intohost};
	db_dosql("SELECT id FROM interfaces WHERE host=$hostid");
	while((my $id) = db_getrow()){
		push @ifselect,$id;
	}
	$intoifmenu->destroy if Tk::Exists($intoifmenu);
	$intoifmenu=$intoifframe->JBrowseEntry(
		-variable => \$intoif,
		-width=>18,
		-choices => \@ifselect,
		-height=>10,
		-font=>"arial 14",
		-browsecmd => sub { print "Selected $intoif\n";}
		)->pack(-side=>'left');
	
}

1;
