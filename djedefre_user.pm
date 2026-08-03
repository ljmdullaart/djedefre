# drawing.pm
use strict;
use warnings;
use Dancer2 appname => 'dancr';

use dje_db;
sub q_check_system_auth {
	my ($username, $password) = @_;
	my ($package, $filename, $line) = caller;
	my $pam = Authen::Simple::PAM->new(
		service => 'login'
	);
	if ( $pam->authenticate($username, $password) ) {
		return 1; 
	}
	
	return 0; 
}
 
#######################################################################
any ['get', 'post'] => '/login' => sub {
	my $err;
	if ( request->method() eq "POST" ) {
		# process form input
		my $tusername=body_parameters->get('username');
		my $tpwd=body_parameters->get('pwd');
		my $username;
		if ($tusername=~/(\w+)/){
			$username=$1;
			#if ( 0 == system ("/usr/bin/grep '$username:' /etc/passwd")){
				#session 'logged_in' => true;
				#set_flash('You are logged in.');
				#return redirect '/';
			#}
			if ( q_check_system_auth($username, $tpwd) ) {
				session 'logged_in' => true;
				set_flash('You are logged in.');
				return redirect '/';
			}
			elsif (q_user_password_hash($username) ne "" ){
				session 'logged_in' => true;
				set_flash('You are logged in.');
				return redirect '/';
			}
		}
		else {
			$err = "Invalid username";
		}
	}
	# display login form
	template 'login.tt', {
		err => $err,
	};
 
};
 
get '/logout' => sub {
	app->destroy_session;
	set_flash('You are logged out.');
	redirect '/';
};
 

1;

