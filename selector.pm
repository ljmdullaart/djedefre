#!/usr/bin/perl
#INSTALL@ /opt/djedefre/selector.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;
use Tk;
use Data::Dumper;

my @selector_options;
my @selector_selected;
my $selector_optbox;
my $selector_selbox;
my $selector_optboxsel='';
my $selector_selboxsel='';

my $selector_mainframe;

sub selector_dump {
        print Dumper(@_);
}
my $selector_callback_function=\&selector_dump;

#--------------------------------------------------------------------------------------------------
#
#
#my @numbers = (1..10);
#my @words = qw(hello world outside);
#my $main_window = MainWindow->new();
#
#
#selector( {options=>\@numbers , selected=>\@words , parent=>$main_window} );
#
#
#MainLoop;
#exit;
#--------------------------------------------------------------------------------------------------

sub selector_callback {
        (my $func)=@_;
        $selector_callback_function=$func; 
}
sub selector {
	die "no parameter!\n" unless @_;
	my %opt = %{ shift @_ };
	my $r_options=$opt{options};
	@selector_options=@$r_options;
	my $r_selected=$opt{selected};
	@selector_selected=@$r_selected;
	my $parent=$opt{parent};
	$selector_mainframe->destroy if Tk::Exists($selector_mainframe);
	$selector_mainframe=$parent->Frame()->pack();
	my $title=$opt{title}; $title='Select' unless defined $title;
	my $height=$opt{height}; $height=25 unless defined $height;
	my $width=$opt{width}; $width=50 unless defined $width;
	if (defined($opt{callback})){$selector_callback_function=$opt{callback};}

	$selector_mainframe->Label (-text=>$title)->pack(-side => 'top');
	$selector_optbox=$selector_mainframe->Scrolled("Listbox", -scrollbars=>'e',-width=>0.4*$width,-height=>$height)->pack(-side=>'left');
	$selector_optbox->insert('end',@selector_options);
	my $buttonframe=$selector_mainframe->Frame()->pack(-side=>'left');
	$buttonframe->Button (-text=>'-->',-command=>sub {selector_add_action();})->pack(-side=>'top');
	$buttonframe->Button (-text=>'X',-command=>sub {selector_del_action();})->pack(-side=>'top');
	$selector_selbox=$selector_mainframe->Scrolled("Listbox", -scrollbars=>'e',-width=>0.4*$width,-height=>$height)->pack(-side=>'right');
	$selector_selbox->insert('end',@selector_selected);

	$selector_selbox->bind('<<ListboxSelect>>' => sub {my @sel= $selector_selbox->curselection;$selector_selboxsel=@selector_selected[$sel[0]];});
	$selector_optbox->bind('<<ListboxSelect>>' => sub {my @opt= $selector_optbox->curselection;$selector_optboxsel=@selector_options[$opt[0]];});

}

sub selector_add_action {
	my $exists=-1;
	for my $a (@selector_selected) {
		if ($a eq $selector_optboxsel){ $exists=1;}
	}
	if ($exists==-1){
		push @selector_selected,$selector_optboxsel;
		$selector_selbox->insert('end',$selector_optboxsel);
	}
	$selector_callback_function->('add',$selector_optboxsel);
}
sub selector_del_action{
	my $index=0;
	for my $i (0 ..$#selector_selected){
		if ($selector_selected[$i] eq $selector_selboxsel){
			splice (@selector_selected,$i,1);
			$selector_selbox->delete($i);
			last;
		}
	}
	$selector_callback_function->('del',$selector_selboxsel);
	
}
		


1;
