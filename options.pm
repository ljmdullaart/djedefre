#INSTALL@ /opt/djedefre/options.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
#              _   _                 
#   ___  _ __ | |_(_) ___  _ __  ___ 
#  / _ \| '_ \| __| |/ _ \| '_ \/ __|
# | (_) | |_) | |_| | (_) | | | \__ \
#  \___/| .__/ \__|_|\___/|_| |_|___/
#       |_|   

require dje_db;

our $main_window;
our $mainframe;

our $Message;

our %config;
our @colors;



sub options_read {
	db_dosql("SELECT item,value FROM config WHERE attribute='line:color'");
	while ((my $item,my $value)=db_getrow()){
		$config{"line:color:$item"}=$value;
	}
	if (! defined $config{'line:color:vlan1'}){
		$config{"line:color:vlan1"}='black';
		db_dosql ("DELETE FROM config WHERE attribute='line:color' AND item='vlan1'");
		db_dosql ("INSERT INTO config (attribute,item,value) VALUES ('line:color','vlan1','black')");
	}

	if (! defined $config{'line:color:vbox'}){
		$config{"line:color:vbox"}='lightgrey';
		db_dosql ("DELETE FROM config WHERE attribute='line:color' AND item='vbox'");
		db_dosql ("INSERT INTO config (attribute,item,value) VALUES ('line:color','vbox','lightgrey')");
	}
	db_dosql('SELECT DISTINCT vlan FROM l2connect');
	while ((my $vlan)=db_getrow()){
		$vlan=1 unless defined $vlan;
		if ($vlan=~/^[0-9][0-9]*$/){ $vlan="vlan$vlan";}
		if (! defined $config{"line:color:$vlan"}){
			$config{"line:color:$vlan"}='black';
			db_dosql ("DELETE FROM config WHERE attribute='line:color' AND item='$vlan'");
			db_dosql ("INSERT INTO config (attribute,item,value) VALUES ('line:color','$vlan','black')");
		}
	}
		
}


sub options_window {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	my $lineframe=$main_frame->Frame()->pack(-side =>'left');
	$lineframe->Label (
		-text	=> 'Drawing colors',
		-width	=> 60
	)->pack(-side =>'top');
	my %linecols;
	my %example;
	my $perlineframe;
	my $inputnew;
	my $inputcol='black';
	my $inputlab;
	$perlineframe=$lineframe->Frame(
		-borderwidth	=> 2,
		-relief		=> 'groove'
	)->pack(-side =>'top');
	$perlineframe->Entry (
		-textvariable	=> \$inputnew,
		-width		=> 30
	)->pack(-side=>left);
	$inputlab=$perlineframe->Label(
		-text	=> '     ',
		-width	=> 5,
		-bg	=> $inputcol
	)->pack(-side=>'left');
	$perlineframe->Optionmenu(
		-variable	=> \$inputcol,
		-options	=> [@colors],
		-width		=> 30,
		-command	=> sub {
			$inputlab->configure(-bg=>$inputcol);
		}
	)->pack(-side=>'left');
	$perlineframe->Button (
		-text	=> 'Add',
		-width	=> 5,
		-command=>sub {
			$inputnew='' unless defined $inputnew;
			if ($inputnew ne '' ){
				$config{"line:color:$inputnew"}=$inputcol;
				db_dosql ("DELETE FROM config WHERE attribute='line:color' AND item='$inputcol'");
				db_dosql ("INSERT INTO config (attribute,item,value) VALUES ('line:color','$inputnew','$inputcol')");
				options_window();
			}
		}
	)->pack(-side=>'left');
	
	foreach my $key (sort keys %config) {
		if ($key=~/^line:color:(.*)/){
			my $linename=$1;
			$linecols{$linename}=$config{$key};
			$perlineframe=$lineframe->Frame(
				-borderwidth	=> 2,
				-relief		=> 'groove'
			)->pack(-side =>'top');
			$perlineframe->Label(
				-text	=> $linename,
				-width	=> 30,
			)->pack(-side=>'left');
			$example{$linename}=$perlineframe->Label(
				-text	=> '     ',
				-width	=> 5,
				-bg	=> $config{$key}
				
			)->pack(-side=>'left');
			$perlineframe->Optionmenu(
				-variable	=> \$config{$key},
				-options	=> [@colors],
				-width		=> 30,
				-command	=> sub {
					$example{$linename}->configure(-bg=>$config{$key});
					$config{"line:color:$linename"}=$config{$key};
					db_dosql ("DELETE FROM config WHERE attribute='line:color' AND item='$linename'");
					db_dosql ("INSERT INTO config (attribute,item,value) VALUES ('line:color','$linename','$config{$key}')");
				}
			)->pack(-side=>'left');
			my $buttontext='Delete';
			$buttontext='' if $linename eq 'vbox';
			$buttontext='' if $linename eq 'vlan1';
			$perlineframe->Button (
				-text	=> $buttontext,
				-width	=>5,
				-command=>sub {
					if ($linename eq 'vbox'){}
					elsif ($linename eq 'vlan1'){}
					else{
						delete($config{"line:color:$linename"});
						db_dosql ("DELETE FROM config WHERE attribute='line:color' AND item='$linename'");
						options_window();
					}
				}
			)->pack(-side=>'left');
		}
	}

}

		

1;
