
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
#INSTALL@ /opt/djedefre/logopage.pm
#  _                                            
# | | ___   __ _  ___    _ __   __ _  __ _  ___ 
# | |/ _ \ / _` |/ _ \  | '_ \ / _` |/ _` |/ _ \
# | | (_) | (_| | (_) | | |_) | (_| | (_| |  __/
# |_|\___/ \__, |\___/  | .__/ \__,_|\__, |\___|
#          |___/        |_|          |___/  
our %config;

my $image;

sub logoframe {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$image = $main_window->Photo(-file => "$config{image_directory}/djedefre.gif");
	$main_frame=$main_window->Frame(
	)->pack(-side =>'top');
	$main_frame->Label(-text=>'Djedefre', -width=>1500)->pack(-side=>'top');
	$main_frame->Label(-image => $image)->pack(-side=>'top');
}
	
1;
