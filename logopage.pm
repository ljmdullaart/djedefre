
#INSTALL@ /opt/djedefre/logopage.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;
#  _                                            
# | | ___   __ _  ___    _ __   __ _  __ _  ___ 
# | |/ _ \ / _` |/ _ \  | '_ \ / _` |/ _` |/ _ \
# | | (_) | (_| | (_) | | |_) | (_| | (_| |  __/
# |_|\___/ \__, |\___/  | .__/ \__,_|\__, |\___|
#          |___/        |_|          |___/  
our %config;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;
our $Message;
our $main_frame;
our $main_window;


my $image;
my $logo_frame;

sub logoframe {
	(my $parent)=@_;
	debug($DEB_SUB,"logoframe");
	$Message='';
	$logo_frame->destroy if Tk::Exists($logo_frame);
	$logo_frame=$parent->Frame()->pack(-side =>'top');
	$image = $logo_frame->Photo(-file => "$config{image_directory}/djedefre.gif");
	$logo_frame->Label(-text=>'Djedefre', -width=>1500)->pack(-side=>'top');
	$logo_frame->Label(-image => $image)->pack(-side=>'top');
}
	
1;
