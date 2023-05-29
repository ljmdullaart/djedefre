#!/usr/bin/perl
  
use strict;
use warnings;

use Tk;
use Tk::PNG;
use Tk::Photo;
use Image::Magick;
use Tk::JBrowseEntry;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;
use Data::Dumper;


#	A single multilist is supported at one time.
#	For a new multilist, do the following:
#	1	ml_new($parent,$height,$pack_side)	Create a multilist in $parent, and pack on the $pac_side
#	2	ml_colwidth(@width)			set the column-widths in the multilist
#	3	ml_colhead(@headers)			set the labels of the column-headers
#	4	ml_create()				create the multilist
#	5	ml_insert(@content)			Add content to the multilist
#
#	6	ml_destroy
#

my $mlframe;
	my $mlheaderframe;
	my $mlboxframe;

my $mlheight;
my $qcol;
my @colwidth;
my @colhead;
my @mlcolumns;
my $scroll;


sub scroll_listboxes {
	my ($sb, $scrolled, $lbs, @args) = @_;
	$sb->set(@args); # tell the Scrollbar what to display
	my ($top, $bottom) = $scrolled->yview( );
	foreach my $list (@$lbs) {
		$list->yviewMoveto($top); # adjust each lb
	}
}

sub ml_new {
	(my $parent,my $height,my $side)=@_;
	$mlframe->destroy if Tk::Exists($mlframe);
	$mlframe=$parent->Frame(-height=>$height)->pack(-side=>$side);
	$mlheight=$height*0.5;
}
	

sub ml_destroy {
	$mlframe->destroy if Tk::Exists($mlframe);
}
	

sub ml_colwidth {
	(my @width)=@_;
	for my $i (0 .. $#width){
		$colwidth[$i]=$width[$i];
		$qcol=$i;
	}
}

sub ml_colhead {
	(my @head)=@_;
	for my $i (0 .. $#head){
		$colhead[$i]=$head[$i];
		$qcol=$i;
	}
}

sub ml_create {
	$mlheaderframe=$mlframe->Frame()->pack(-side=>'top');
	my $col;
	for my $i (0 .. $qcol ){
		$colwidth[$i]=10 unless defined $colwidth[$i];
		$colwidth[$i]=10 if ($colwidth[$i] eq '');
		$mlheaderframe->Label(-text=>$colhead[$i],-width=>$colwidth[$i], -font=>"arial 14")->pack(-side=>'left');
	}
	$mlboxframe=$mlframe->Frame()->pack(-side=>'bottom');
	$scroll = $mlboxframe->Scrollbar( );
	splice @mlcolumns;
	for my $i (0 .. $qcol ){
		$col=$mlboxframe->Listbox(-height=> $mlheight,-width=>$colwidth[$i], -font=>"arial 14");
		push @mlcolumns,$col;
	}
	foreach my $lstbx (@mlcolumns){
		$lstbx->configure(-yscrollcommand => [ \&scroll_listboxes, $scroll,$lstbx, \@mlcolumns ])
	}
	$scroll->configure(-command => sub {
		foreach my $list (@mlcolumns){
			$list->yview(@_);
			$list->bind('<<ListboxSelect>>' => sub {my $sel= $list->curselection;my $id=$mlcolumns[0]->get($sel);print "Selected $id\n";});
		}
	});
	$scroll->pack(-side => 'right', -fill => 'y');
	foreach my $list (@mlcolumns){
		$list->pack(-side => 'left');
	}
}

sub ml_insert {
	(my @args)=@_;
	for my $i (0 .. $#args){
		$mlcolumns[$i]->insert('end',$args[$i]);
	}
}

	
	


1;
