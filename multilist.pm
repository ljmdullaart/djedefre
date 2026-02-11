#!/usr/bin/perl
#INSTALL@ /opt/djedefre/multilist.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
  
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
use Sort::Naturally qw/ncmp/;

#	A single multilist is supported at one time.
#	For a new multilist, do the following:
#	1	ml_new($parent,$height,$pack_side)	Create a multilist in $parent, and pack on the $pac_side
#	2	ml_colwidth(@width)			set the column-widths in the multilist
#	3	ml_colhead(@headers)			set the labels of the column-headers
#	4	ml_insert(@content)			Add content to the multilist
#	5	ml_create()				create the multilist
#	6	ml_callback(\&subroutine)		Add a call-back for selection
#	7	ml_destroy
#

my $mlframe;
	my $mlheaderframe;
	my $mlboxframe;

my $mlheight;
my $mlside;
my $qcol;
my @colwidth;
my @colhead;
my @mlcolval;
my @mlcolumns;
my $mlmaxcolval=0;
my $scroll;
my $mlparent;
my $mlfirst=0;

sub ml_prt_cb {
	(my $id)=@_;
	print "Selected $id\n";
}
my $mlcallback=\&ml_prt_cb;

sub scroll_listboxes {
	my ($sb, $scrolled, $lbs, @args) = @_;
	$sb->set(@args); 
	my ($top, $bottom) = $scrolled->yview( );
	foreach my $list (@$lbs) {
		$list->yviewMoveto($top); 
	}
}

sub ml_new {
	(my $parent,my $height,my $side)=@_;
	$mlparent=$parent;
	$mlheight=$height;
	$mlside=$side;
	$mlmaxcolval=0;
	$mlfirst=0;
	splice @colwidth;
	splice @colhead;
	splice @mlcolval;
	splice @mlcolumns;
	$mlcallback=\&ml_prt_cb;
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

sub ml_callback {
	(my $cb)=@_;
	$mlcallback=$cb;
}

sub ml_insert {
	(my @args)=@_;
	for my $i (0 .. $#args){
		if ($i<=$qcol){
			my $val=$args[$i];
			$val='' unless defined $val;
			$mlcolval[$i][$mlmaxcolval]=$val;
			print "mlcolval[$i][$mlmaxcolval]=$val\n";
		}
	}
	$mlmaxcolval++;
}

sub ml_create {
	$mlframe->destroy if Tk::Exists($mlframe);
	$mlframe=$mlparent->Frame(-height=>$mlheight)->pack(-side=>$mlside);
	$mlheaderframe=$mlframe->Frame()->pack(-side=>'top');
	my $col;
	if ($mlfirst==0){
		ml_sortcols(0);
		$mlfirst++;
	}
	for my $i (0 .. $qcol ){
		$colwidth[$i]=10 unless defined $colwidth[$i];
		$colwidth[$i]=10 if ($colwidth[$i] eq '');
		$mlheaderframe->Button(
			-text=>$colhead[$i],
			-width=>$colwidth[$i]-2, 
			-font=>"arial 14",
			-command => sub {
				ml_sortcols($i);
				ml_create();
			}
		)->pack(-side=>'left');
	}
	$mlheaderframe->Label(-text=>' ',-width=>2)->pack(-side=>'left');
	$mlboxframe=$mlframe->Frame()->pack(-side=>'bottom');
	$scroll = $mlboxframe->Scrollbar( );
	splice @mlcolumns;
	for my $i (0 .. $qcol ){
		$col=$mlboxframe->Listbox(-height=> $mlheight,-width=>$colwidth[$i], -font=>"arial 14");
		push @mlcolumns,$col;
	}
	foreach my $lstbx (@mlcolumns){
		$lstbx->configure(-yscrollcommand => [ \&scroll_listboxes, $scroll,$lstbx, \@mlcolumns ]);
		$lstbx->bind('<<ListboxSelect>>' => sub {my $sel= $lstbx->curselection;my $id=$mlcolumns[0]->get($sel);$mlcallback->($id);});
	}
	$scroll->configure(-command => sub {
		foreach my $list (@mlcolumns){
			$list->yview(@_);
		}
	});
	$scroll->pack(-side => 'right', -fill => 'y');
	foreach my $list (@mlcolumns){
		$list->pack(-side => 'left');
	}
	for (my $i=0; $i<=$qcol; $i++){
		#if (exists($mlcolval[$i])){
		if (exists($mlcolval[$i])){
			my @args=@{$mlcolval[$i]};
			for my $j (0.. $#args){
				if (defined($args[$j])){
					$mlcolumns[$i]->insert('end',$args[$j]);
				}
			}
		}
	}
}

	
sub ml_sortcols {
	(my $col)=@_;
	# Transpose the array
	my @transposed ;
	for my $row (0..@mlcolval-1){
		for my $col(0..@{$mlcolval[$row]}-1) {
			$transposed[$col][$row]=$mlcolval[$row][$col];
		}
	}
	
	# Sort the transposed array on the first row
	@transposed = sort {
		my $a1=$a->[$col];
		my $b1=$b->[$col];
		ncmp($a1 , $b1);
	} @transposed;

	# Transpose it back
	for my $row (0..@transposed-1){
		for my $col(0..@{$transposed[$row]}-1) {
			$mlcolval[$col][$row]=$transposed[$row][$col];
		}
	}

}


1;
