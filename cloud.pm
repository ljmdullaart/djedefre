use strict;
#INSTALL@ /opt/djedefre/cloudnput.pm
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

my @cloud_cloudlist;
my $cloud_addcloud;
my $cloud_selectedcloud;

my $cloud_id;
my $cloud_name;
my $cloud_vendor;
my $cloud_type;
my $cloud_service;

	

#-----------------------------------------------------------------------
# Name        : cloud_del_a_cloud
# Purpose     : Delete a cloud named $cloud_addcloud
# Arguments   : none; a global variable is used
# Returns     : 
# Globals     : $cloud_addcloud
# Side‑effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub cloud_del_a_cloud {
	my ($package, $filename, $line) = caller;
	debug($DEB_SUB,"cloud_del_a_cloud caled from $package, $filename, line number $line");
	#db_dosql("DELETE FROM cloud WHERE name='$cloud_addcloud'");
	#db_close();
	query_cloud_del_name($cloud_addcloud);
	cloud_input();
}

#-----------------------------------------------------------------------
# Name        : cloud_add_a_cloud
# Purpose     : Add a cloud named from global variables
# Arguments   : none;  global variables are used
# Returns     : 
# Globals     : $cloud_addcloud,$cloud_vendor,$cloud_type,$cloud_service
# Side‑effects: If the cloud-name exists, it is deleted first.
# Notes       : 
#-----------------------------------------------------------------------

sub cloud_add_a_cloud {
	debug($DEB_SUB,"cloud_add_a_cloud");
	cloud_del_a_cloud();
	#db_dosql("INSERT INTO cloud (name,vendor,type,service) VALUES ('$cloud_addcloud','$cloud_vendor','$cloud_type','$cloud_service')");
	#db_close();
	query_cloud_add_a_cloud ($cloud_addcloud,$cloud_vendor,$cloud_type,$cloud_service);
	cloud_input();
}	

sub cloud_change_a_cloud {
	debug($DEB_SUB,"cloud_change_a_cloud");
	cloud_del_a_cloud();
	db_dosql("INSERT INTO cloud (name,vendor,type,service) VALUES ('$cloud_addcloud','$cloud_vendor','$cloud_type','$cloud_service')");
	db_close();
	cloud_input();
}

sub cloud_select_a_cloud {
	debug($DEB_SUB,"cloud_select_a_cloud");
	$cloud_addcloud=$cloud_selectedcloud;
	db_dosql("SELECT id,name,vendor,type,service FROM cloud WHERE name='$cloud_selectedcloud'");
	($cloud_id,$cloud_name,$cloud_vendor,$cloud_type,$cloud_service)=db_getrow();
	while (db_getrow()){}
	db_close();
}


sub cloud_input {
	debug($DEB_SUB,"cloud_input");
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	$main_frame->Label(-text=> 'Cloud service')->pack(-side=>'top');
	my $cloudframe=$main_frame->Frame()->pack(-side =>'left');
	my $detailsframe=$main_frame->Frame()->pack(-side =>'right');

	splice @cloud_cloudlist;
	my $i=0;
	db_dosql("SELECT name FROM cloud");
	while((my $name) = db_getrow()){
		$cloud_cloudlist[$i]=$name;
		$i++;
	}
	db_close();
	my $cloudlistbox=$cloudframe->Scrolled("Listbox", -scrollbars=>'e',-width=>28,-height=>20)->pack(-side=>'top');
	$cloudlistbox->insert('end',@cloud_cloudlist);
	$cloudlistbox->bind('<<ListboxSelect>>' => sub {
		my @sel=$cloudlistbox->curselection;
		$cloud_selectedcloud=$cloud_cloudlist[$sel[0]];
		cloud_select_a_cloud();
	});
	
	$cloudframe->Entry (
		-width=>32,
		-textvariable=>\$cloud_addcloud
	)->pack(-side=>'top');

	my $buttoncloudframe=$cloudframe->Frame()->pack(-side=>'top');
	$buttoncloudframe->Button ( -width=>15,-text=>'Add cloud', -command=>sub{ cloud_add_a_cloud('cloud');})->pack(-side=>'left');
	$buttoncloudframe->Button ( -width=>15,-text=>'Delete',    -command=>sub{ cloud_del_a_cloud();})->pack(-side=>'left');

	my $localframe;
	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Name',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->Label(-textvariable=>\$cloud_name,-width=>40,-anchor=>'w')->pack(-side=>'right');

	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'ID',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->Label(-textvariable=>\$cloud_id,-width=>40,-anchor=>'w')->pack(-side=>'right');

	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Vendor',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->Entry(-textvariable=>\$cloud_vendor,-width=>40)->pack(-side=>'right');

	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Service',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->Entry(-textvariable=>\$cloud_service,-width=>40)->pack(-side=>'right');

	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Label(-text=>'Type',-width=>20,-anchor=>'w')->pack(-side=>'left');
	$localframe->JBrowseEntry(
		-variable => \$cloud_type,
		-width=>37,
		-choices => \@logolist,
		-height=>10
	)->pack(-side=>'right');
	$localframe=$detailsframe->Frame()->pack(-side =>'top');
	$localframe->Button ( -width=>15,-text=>'change',    -command=>sub{ cloud_change_a_cloud();})->pack(-side=>'left');
}

		

1;
