
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
#INSTALL@ /opt/djedefre/overview.pm

use Data::Dumper;
use strict;

#                            _               
#   _____   _____ _ ____   _(_) _____      __
#  / _ \ \ / / _ \ '__\ \ / / |/ _ \ \ /\ / /
# | (_) \ V /  __/ |   \ V /| |  __/\ V  V / 
#  \___/ \_/ \___|_|    \_/ |_|\___| \_/\_/  
#  

our $main_frame;
our $repeat_sub;
our $main_window;
our $Message;
our %config;

my $overview_frame;

my $selected_overview='Lists';
sub menu_make_overview {
	$repeat_sub=\&norepeat;
	$main_frame->destroy if Tk::Exists($main_frame);
        $main_frame=$main_window->Frame()->pack();
	$Message='';
	if ($selected_overview eq 'Dashboard'){
		overview_dashboard($overview_frame);
	}
	$selected_overview='Overview';
}

sub make_overviewselectframe {
	(my $parent)=@_;
	my @overviewtypes=qw/ Overview Dashboard /;
	$parent->Optionmenu (
		-variable	=> \$selected_overview,
		-options	=> [@overviewtypes],
		-width		=> 15,
		-command	=> sub { menu_make_overview(); }
	)->pack();
}
	
sub repeat_overview_dashboard {
	db_dosql("SELECT value FROM config WHERE attribute='run:param' AND item='changed'");
	(my $val)=db_getrow();
	if ($val ne 'no'){
        	db_dosql("UPDATE config SET value='no' WHERE attribute='run:param' AND item='changed'");
		overview_dashboard();
	}
}

sub overview_dashboard{
	(my $parent)=@_;
	$repeat_sub=\&repeat_overview_dashboard;
	$overview_frame->destroy if Tk::Exists($overview_frame);
	$overview_frame=$main_frame->Frame()->pack(-side=>'left');
	overview_server();
	overview_network();
}

sub overview_network {
	my $overview_network=$overview_frame->Scrolled("Frame",-scrollbars=>'e',-width=>300,-height=>800)->pack(-side=>'left');
	db_dosql("SELECT value FROM config WHERE attribute='run:param' AND item='inetup'");
	(my $inetup)=db_getrow();
	if ($inetup eq 'up'){
		$overview_network->Label (-text=>'Internet is up',-background=>'green',-anchor=>'w',-width=>25)->pack(-side=>'top');
	}
	else {
		$overview_network->Label (-text=>'Internet is DOWN',-background=>'red',-anchor=>'w',-width=>25)->pack(-side=>'top');
	}
	db_dosql("SELECT value FROM config WHERE attribute='run:param' AND item='idpath'");
	(my $idpath)=db_getrow();
	my @pathids=split (':',$idpath);
	my $image;
	my $lineframe;
	for my $id (@pathids){
		db_dosql("SELECT name FROM server WHERE id=$id");
		(my $name)=db_getrow();
		db_dosql("SELECT type FROM server WHERE id=$id");
		(my $type)=db_getrow();
		db_dosql("SELECT status FROM server WHERE id=$id");
		(my $status)=db_getrow();
		my $color='red';
		if ($status eq 'up'){ $color='green';}
		$image=$main_window->Photo(-file=> $config{'image_directory'}."/logo_".$type.".png");
		$lineframe=$overview_network->Frame()->pack(-side=>'top');
		$lineframe->Label(-image => $image)->pack(-side=>'top');
		$lineframe=$overview_network->Frame()->pack(-side=>'top');
		$lineframe->Label(-text=>$name,-background=>$color)->pack(-side=>'top');

		$image=$main_window->Photo(-file=> $config{'image_directory'}."/darrow.png");
		$lineframe=$overview_network->Frame()->pack(-side=>'top');
		$lineframe->Label(-image => $image)->pack(-side=>'top');
	}
	$image=$main_window->Photo(-file=> $config{'image_directory'}."/logo_internet.png");
	$lineframe=$overview_network->Frame()->pack(-side=>'top');
	$lineframe->Label(-image => $image)->pack(-side=>'top');
	$lineframe=$overview_network->Frame()->pack(-side=>'top');
	$lineframe->Label(-text=>'Internet')->pack(-side=>'top');
		
}
	

sub overview_server {
	my $overview_server_frame=$overview_frame->Scrolled("Frame",-scrollbars=>'e',-width=>300,-height=>800)->pack(-side=>'left');
	db_dosql("SELECT id,name,last_up FROM server WHERE status='down' ORDER BY last_up");
	while ((my $id, my $name, my $lastup)=db_getrow()){
		my $lineframe=$overview_server_frame->Frame(-borderwidth=>2)->pack(-side=>'top');
		$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
		$lineframe->Button(-text=>'Exclude',-width=>8,-background=>'red',-command=>sub {
			db_dosql("UPDATE server SET status='excluded' WHERE id=$id");
			overview_dashboard();
		})->pack(-side=>'left');
	}	
	db_dosql("SELECT id,name,last_up FROM server WHERE status='up' ORDER BY last_up");
	while ((my $id, my $name, my $lastup)=db_getrow()){
		my $lineframe=$overview_server_frame->Frame(-borderwidth=>2)->pack(-side=>'top');
		$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
		$lineframe->Button(-text=>'Exclude',-width=>8,-background=>'green',-command=>sub {
			db_dosql("UPDATE server SET status='excluded' WHERE id=$id");
			overview_dashboard();
		})->pack(-side=>'left');
	}	
	db_dosql("SELECT id,name,last_up FROM server WHERE status='excluded' ORDER BY last_up");
	while ((my $id, my $name, my $lastup)=db_getrow()){
		my $lineframe=$overview_server_frame->Frame(-borderwidth=>2)->pack(-side=>'top');
		$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
		$lineframe->Button(-text=>'Include',-width=>8,-command=>sub {
			db_dosql("UPDATE server SET status='down' WHERE id=$id");
			overview_dashboard();
		})->pack(-side=>'left');
	}	
}

1;
