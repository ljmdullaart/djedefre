

#  _     ____    _                   _   
# | |   |___ \  (_)_ __  _ __  _   _| |_ 
# | |     __) | | | '_ \| '_ \| | | | __|
# | |___ / __/  | | | | | |_) | |_| | |_ 
# |_____|_____| |_|_| |_| .__/ \__,_|\__|
#                       |_|     

require dje_db;

our $main_window;
our $mainframe;

my @l2i_switchlist;
my $l2i_selectedswitch='';
my $l2i_addswitch='';
my $l2i_qtyports=16;
my @l2i_connect;
my @l2i_switchports;
my @l2i_setif;
my $l2i_buttonsettext='';

sub l2i__add_a_switch {
	print "Add switch $l2i_addswitch\n";
	if ($l2i_addswitch ne ''){
		db_dosql("DELETE FROM switch WHERE name='$l2i_addswitch'");
                db_dosql("INSERT INTO switch (name,ports) VALUES ('$l2i_addswitch',$l2i_qtyports)");
	}
	l2input();
}

sub l2i__del_a_switch {
	print "Add switch $l2i_addswitch\n";
	if ($l2i_addswitch ne ''){
		db_dosql("DELETE FROM switch WHERE name='$l2i_addswitch'");
	}
	l2input();
}

sub l2i__reconnect{

	print "reconnect @_\n";
	

}
	

sub l2input {
	print "l2input\n";
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"12 Create main_frame for manage pages");
	$main_frame=$main_window->Frame(
		#-height      => 0.8*$main_window_height,
		#-width       => $main_window_width
	)->pack(-side =>'top');
	my $switchframe=$main_frame->Frame()->pack(-side =>'left');
	#my $switchlistbox=$switchframe->Scrolled("Listbox", -scrollbars=>'e',-width=>28,-height=>20)->pack(-side=>'top');
	my $portframe = $main_frame->Scrolled("Frame",-scrollbars=>'e',-height=>400)->pack(-side =>'right');
	my $sth=db_dosql("SELECT name FROM switch");
	my $i=0;
	splice @l2i_switchlist;
	while((my $name) = db_getrow()){
		$l2i_switchlist[$i]=$name;
		$i++;
	}
	$switchframe->Label(-text=> 'Switch')->pack(-side=>'top');
	my $switchlistbox=$switchframe->Scrolled("Listbox", -scrollbars=>'e',-width=>28,-height=>20)->pack(-side=>'top');
	$switchlistbox->insert('end',@l2i_switchlist);
	$switchlistbox->bind('<<ListboxSelect>>' => sub {my @sel=$switchlistbox->curselection;$l2i_addswitch=$l2i_switchlist[$sel[0]];l2input();});
	
	my @portoptions=(5,6,8,13,15,16,24,48,64);
	$switchframe->Optionmenu(-variable=>\$l2i_qtyports, -options=>\@portoptions,-width=>27)->pack(-side=>'top');

	$switchframe->Entry ( -width=>32,-textvariable=>\$l2i_addswitch)->pack(-side=>'top');

	my $buttoswitchframe=$switchframe->Frame()->pack(-side=>'top');
	$buttoswitchframe->Button ( -width=>10,-text=>'Set qty ports',-command=>sub{ l2i__add_a_switch();})->pack(-side=>'left');
	$buttoswitchframe->Button ( -width=>10,-text=>'Add switch',   -command=>sub{ l2i__add_a_switch();})->pack(-side=>'left');
	$buttoswitchframe->Button ( -width=>10,-text=>'Delete',       -command=>sub{ l2i__del_a_switch();})->pack(-side=>'left');

	my $sth=db_dosql("SELECT id,ports FROM switch WHERE name='$l2i_addswitch'");
	(my $switchid,$l2i_qtyports)=db_getrow();
	$switchid=0 unless defined $switchid;
	$l2i_qtyports=16 unless defined $l2i_qtyports;
	for my $i (0 .. $l2i_qtyports) { $l2i_connect[$i]='Not connected';}
	my @hostnames;
	splice @hostnames;
	$sth=db_dosql("SELECT id,name FROM server");
	while ((my $id,my $name)= db_getrow()){
		$hostnames[$id]=$name;
	}
	my @freeif;
	splice @freeif;
	$sth=db_dosql("SELECT id,macid,ip,host FROM interfaces WHERE switch=-1");
	while ((my $id,my $macid,my $ip,my $host)= db_getrow()){
		my $server=' ';
		if (defined $hostnames[$host]){$server=$hostnames[$host];}
		push @freeif,"$id:$server:$ip:$macid";
	}
	$sth=db_dosql("SELECT from_port,to_tbl,to_id,to_port FROM l2connect WHERE from_tbl='switch' AND from_id=$switchid");
	while ((my $from_port,my $to_tbl,my $to_id,my $to_port)= db_getrow()){
		if ($to_tbl eq 'switch'){
			$l2i_connect[$from_port]="switch:$to_id:$to_port";
		}
		elsif($to_tbl eq 'interfaces'){
			$l2i_connect[$from_port]="interfaces:$to_id:0";
		}
	}
	db_dosql("SELECT from_port,from_id,from_tbl,to_id,to_port FROM l2connect WHERE to_tbl='switch' AND to_id=$switchid");
	while ((my $from_port,my $from_id,my $from_tbl,my $to_id,my $to_port)= db_getrow()){
		if ($from_tbl eq 'switch'){
			$l2i_connect[$to_port]="switch:$from_id:$from_port";
		}
	}
	my $portbuttonframe=$portframe->Frame()->pack(-side=>'top');
	$portbuttonframe->Button (
		-text=>'(re)connect all changes',
		-command=>sub {print "reconnect\n";}
	)->pack(-side=>'top');
	for my $i (0 .. $l2i_qtyports) {
		my $perportframe=$portframe->Frame()->pack(-side=>'top');
		$perportframe->Label (-text=>"Port $i",-width=>10)->pack(-side=>'left');
		$perportframe->Label (-text=>$l2i_connect[$i],-width=>50)->pack(-side=>'left');
		my $selifdrop=$perportframe->JBrowseEntry(
			-variable => \$l2i_setif[$i],
			-width=>25,
			-choices => \@freeif,
			-height=>10,
			-browsecmd => sub {
				$l2i_buttonsettext="Connect port $i on switch $l2i_addswitch to ${\$l2i_setif[$i]}";
			} )->pack(-side=>'right');
		
	}

	#for my $i (0 .. 5){
		#for my $j (0 .. 4){
			#$l2i_inputgrid[$i][$j]=$main_frame->Frame();
		#}
	#}
	#for my $i (0 .. 5){
		#Tk::grid(@{$l2i_inputgrid[$i]});
	#}
}

		

1;
