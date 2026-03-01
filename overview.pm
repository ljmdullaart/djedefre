
#INSTALL@ /opt/djedefre/overview.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;

use Data::Dumper;
use strict;
use File::Glob 'bsd_glob';

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
our %nw_logos;

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
	my $val=q_changed();
	if ($val ne 'no'){
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
	overview_scripts();
	overview_listings();
}

sub overview_network {
	my $overview_network=$overview_frame->Scrolled("Frame",-scrollbars=>'e',-width=>400,-height=>800)->pack(-side=>'left');
	$overview_network->Label(-text=>'Network')->pack(-side=>'top');
	my $inetup=q_config('run:param','inetup');
	if ($inetup eq 'up'){
		$overview_network->Label (-text=>'Internet is up',-background=>'green',-anchor=>'w',-width=>25)->pack(-side=>'top');
	}
	else {
		$overview_network->Label (-text=>'Internet is DOWN',-background=>'red',-anchor=>'w',-width=>25)->pack(-side=>'top');
	}
	my $idpath=q_config('run:param','idpath');
	my @pathids=split (':',$idpath);
	my $image;
	my $lineframe;
	for my $id (@pathids){
		my $name=q_server('name',$id);
		my $type=q_server('type',$id);
		my $status=q_server('status',$id);
		my $color='red';
		if ($status eq 'up'){ $color='green';}
		$image=$nw_logos{$type};
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
	query_server();
	while (my $r=sql_getrow()){
		(my $id, my $name, my $lastup,my $type)=($r->{id},$r->{name},$r->{lastup},$r->{type});
		if ($r->{status} eq 'down' && $r->{devicetype} eq 'network'){
			my $lineframe=$overview_network->Frame(-borderwidth=>2)->pack(-side=>'top');
			$lineframe->Label(-width=>50,-image => $nw_logos{$type})->pack(-side=>'left');
			$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
			$lineframe->Button(-text=>'Exclude',-width=>8,-background=>'red',-command=>sub {
				q_server_update($id,'status','excluded');
				overview_dashboard();
			})->pack(-side=>'left');
		}
	}	
	query_server();
	while (my $r=sql_getrow()){
		(my $id, my $name, my $lastup,my $type)=($r->{id},$r->{name},$r->{lastup},$r->{type});
		if ($r->{status} eq 'up' && $r->{devicetype} eq 'network'){
			my $lineframe=$overview_network->Frame(-borderwidth=>2)->pack(-side=>'top');
			$lineframe->Label(-width=>50,-image => $nw_logos{$type})->pack(-side=>'left');
			$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
			$lineframe->Button(-text=>'Exclude',-width=>8,-background=>'green',-command=>sub {
				q_server_update($id,'status','excluded');
				overview_dashboard();
			})->pack(-side=>'left');
		}	
	}
	query_server();
	while (my $r=sql_getrow()){
		(my $id, my $name, my $lastup,my $type)=($r->{id},$r->{name},$r->{lastup},$r->{type});
		if ($r->{status} eq 'excluded' && $r->{devicetype} eq 'network'){
			my $lineframe=$overview_network->Frame(-borderwidth=>2)->pack(-side=>'top');
			$lineframe->Label (-image => $nw_logos{$type},-anchor=>'w',-width=>25)->pack(-side=>'left');
			$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
			$lineframe->Button(-text=>'Include',-width=>8,-command=>sub {
				q_server_update($id,'status','down');
				overview_dashboard();
			})->pack(-side=>'left');
		}	
	}
		
}
	

sub overview_server {
	my $overview_server_frame=$overview_frame->Scrolled("Frame",-scrollbars=>'e',-width=>400,-height=>800)->pack(-side=>'left');
	$overview_server_frame->Label(-text=>'Severs')->pack(-side=>'top');
	query_server();
	while (my $r=sql_getrow()){
		(my $id, my $name, my $lastup,my $type)=($r->{id},$r->{name},$r->{lastup},$r->{type});
		if ($r->{status} eq 'down' && $r->{devicetype} ne 'network'){
			my $lineframe=$overview_server_frame->Frame(-borderwidth=>2)->pack(-side=>'top');
			$lineframe->Label(-width=>50,-image => $nw_logos{$type})->pack(-side=>'left');
			$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
			$lineframe->Button(-text=>'Exclude',-width=>8,-background=>'red',-command=>sub {
				q_server_update($id,'status','excluded');
				overview_dashboard();
			})->pack(-side=>'left');
		}
	}	
	query_server();
	while (my $r=sql_getrow()){
		(my $id, my $name, my $lastup,my $type)=($r->{id},$r->{name},$r->{lastup},$r->{type});
		if ($r->{status} eq 'up' && $r->{devicetype} ne 'network'){
			my $lineframe=$overview_server_frame->Frame(-borderwidth=>2)->pack(-side=>'top');
			$lineframe->Label(-width=>50,-image => $nw_logos{$type})->pack(-side=>'left');
			$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
			$lineframe->Button(-text=>'Exclude',-width=>8,-background=>'green',-command=>sub {
				q_server_update($id,'status','excluded');
				overview_dashboard();
			})->pack(-side=>'left');
		}
	}	
	query_server();
	while (my $r=sql_getrow()){
		(my $id, my $name, my $lastup,my $type)=($r->{id},$r->{name},$r->{lastup},$r->{type});
		if ($r->{status} eq 'excluded' && $r->{devicetype} ne 'network'){
			my $lineframe=$overview_server_frame->Frame(-borderwidth=>2)->pack(-side=>'top');
			$lineframe->Label(-width=>50,-image => $nw_logos{$type})->pack(-side=>'left');
			$lineframe->Label (-text=>$name,-anchor=>'w',-width=>25)->pack(-side=>'left');
			$lineframe->Button(-text=>'Include',-width=>8,-command=>sub {
				q_server_update($id,'status','down');
				overview_dashboard();
			})->pack(-side=>'left');
		}	
	}
}

sub overview_listings {
	my $overview_listings_frame=$overview_frame->Scrolled("Frame",-scrollbars=>'e',-width=>400,-height=>800)->pack(-side=>'left');
	$overview_listings_frame->Label(-text=>'Listings')->pack(-side=>'top');
	my $output_text = $overview_listings_frame->Scrolled('Text',
    		-wrap => 'none', # No word wrap
    		-width => 80,
    		-height => 50
		)->pack(-expand => 1, -fill => 'both');
	if ( open( my $LIST, '<','/tmp/djedefre.listing')){
		my @lst=<$LIST>;
		close $LIST;
		foreach my $line (@lst) {
			$output_text->insert('end',$line);
		}
	}
}

sub overview_scripts {
	my $overview_scripts_frame=$overview_frame->Scrolled("Frame",-scrollbars=>'e',-width=>400,-height=>800)->pack(-side=>'left');
	$overview_scripts_frame->Label(-text=>'Scripts')->pack(-side=>'top');
	my @serverlist;
	query_dashboard_servers();
	while (my $srv=sql_getvalue()){
		push @serverlist,$srv;
	}
	for my $i (0 .. $#serverlist){
		my $server=$serverlist[$i];
		my $srv_frame=$overview_scripts_frame->Frame()->pack(-side=>'top');
		$srv_frame->Label(-text=>$server)->pack(-side=>'top');
		query_dashboard();
		while (my $r=sql_getrow()){
			(my $srv,my $type,my $variable,my $value,my $color1,my $color2)=
			    ($r->{server},$r->{type},$r->{variable},$r->{value},$r->{color1},$r->{color2});
			if ($srv eq $server){
				my $srvline_frame=$srv_frame->Frame()->pack(-side=>'top');
				if ($type eq 'pct'){
					$srvline_frame->Label (-anchor => 'w',-text=>$variable,-width=>20)->pack(-side=>'left');
					$srvline_frame->Label (-text=>' ', -background=>$color1,-width=>$value/5)->pack(-side=>'left');
					if ($value<5){
						$srvline_frame->Label (-text=>' ', -background=>$color2,-width=>(100-$value)/5)->pack(-side=>'left');
					}
					elsif ($value<100){
						$srvline_frame->Label (-text=>' ', -background=>$color2,-width=>(100-$value)/5-1)->pack(-side=>'left');
					}
					$srvline_frame->Label (-anchor => 'w',-text=>$value,-width=>20)->pack(-side=>'left');
				}
				elsif ($type eq 'val'){
					$srvline_frame->Label (-anchor => 'w',-text=>$variable,-width=>20)->pack(-side=>'left');
					$srvline_frame->Label (-anchor => 'w',-text=>$value, -foreground=>$color2, -width=>20)->pack(-side=>'left');
					$srvline_frame->Label (-anchor => 'w',-text=>'',-width=>20)->pack(-side=>'left');
				}
			}
		}
	}
}
			
1;
