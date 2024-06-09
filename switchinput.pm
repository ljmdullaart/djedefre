use strict;
#INSTALL@ /opt/djedefre/switchnput.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
#       _                 _ 
#   ___| | ___  _   _  __| |
#  / __| |/ _ \| | | |/ _` |
# | (__| | (_) | |_| | (_| |
#  \___|_|\___/ \__,_|\__,_|
#  

require dje_db;

our $main_window;
our $main_frame;
our $Message;
our @logolist;
our @devicetypes;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;

my @switch_switchlist;
my $switch_addswitch;
my $switch_selectedswitch;

my $switch_id;
my $switch_name;
my $switch_type;
my $switch_server;
my $switch_ports=0;

	

sub switch_del_a_switch {
	debug($DEB_SUB,"switch_del_a_switch");
	db_dosql("DELETE FROM switch WHERE name='$switch_addswitch'");
	switch_input();
}

sub switch_add_a_switch {
	debug($DEB_SUB,"switch_add_a_switch");
	switch_del_a_switch();
	db_dosql("INSERT INTO switch (name,switch,server,ports) VALUES ('$switch_addswitch','$switch_type','$switch_server',$switch_ports)");
	switch_input();
}	

sub switch_change_a_switch {
	debug($DEB_SUB,"switch_change_a_switch");
	switch_del_a_switch();
	db_dosql("INSERT INTO switch (name,switch,server,ports) VALUES ('$switch_addswitch','$switch_type','$switch_server',$switch_ports)");
}

sub switch_select_a_switch {
	debug($DEB_SUB,"switch_select_a_switch");
	$switch_addswitch=$switch_selectedswitch;
	db_dosql("SELECT id,name,switch,server,ports FROM switch WHERE name='$switch_selectedswitch'");
	($switch_id,$switch_name,$switch_type,$switch_server,$switch_ports)=db_getrow();
}


sub switch_input {
	debug($DEB_SUB,"switch_input");
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	$main_frame->Label(-text=> 'Switch server')->pack(-side=>'top');
	my $switchframe=$main_frame->Frame()->pack(-side =>'left');
	my $detailsframe=$main_frame->Frame()->pack(-side =>'right');

	splice @switch_switchlist;
	my $i=0;
	db_dosql("SELECT name FROM switch");
	while((my $name) = db_getrow()){
		$switch_switchlist[$i]=$name;
		$i++;
	}
	my $switchlistbox=$switchframe->Scrolled("Listbox", -scrollbars=>'e',-width=>28,-height=>20)->pack(-side=>'top');
	$switchlistbox->insert('end',@switch_switchlist);
	$switchlistbox->bind('<<ListboxSelect>>' => sub {
		my @sel=$switchlistbox->curselection;
		$switch_selectedswitch=$switch_switchlist[$sel[0]];
		switch_select_a_switch();
	});
	
	$switchframe->Entry (
		-width=>32,
		-textvariable=>\$switch_addswitch
	)->pack(-side=>'top');

	my $buttonswitchframe=$switchframe->Frame()->pack(-side=>'top');
	$buttonswitchframe->Button ( -width=>15,-text=>'Add switch', -command=>sub{ switch_add_a_switch('switch');})->pack(-side=>'left');
	$buttonswitchframe->Button ( -width=>15,-text=>'Delete',    -command=>sub{ switch_del_a_switch();})->pack(-side=>'left');

	my $localframe;
	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Name',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->Label(-textvariable=>\$switch_name,-width=>40,-anchor=>'w')->pack(-side=>'right');

	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'ID',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->Label(-textvariable=>\$switch_id,-width=>40,-anchor=>'w')->pack(-side=>'right');

	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Server',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->Entry(-textvariable=>\$switch_server,-width=>40)->pack(-side=>'right');

	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Type',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->JBrowseEntry(
		-variable => \$switch_type,
		-width=>37,
		-choices => \@logolist,
		-height=>10
	)->pack(-side=>'right');
	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Ports',-width=>20,-anchor=>'w')->pack(-side=>'left');
	my @qtyports=(1,2,3,4,5,6,8,10,12,16,24,28,32,48,52,64);
	$localframe->JBrowseEntry(
		-variable => \$switch_ports,
		-width=>37,
		-choices => \@qtyports,
		-height=>10
	)->pack(-side=>'right');
	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Button ( -width=>15,-text=>'change',    -command=>sub{ switch_change_a_switch();})->pack(-side=>'left');
}

		

1;
