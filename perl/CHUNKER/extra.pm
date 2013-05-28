package CHUNKER::extra;

use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;

# get all the meta data associated with a file
my %extradata = initialiseData();

sub initialiseData{
    return (
	    headref => {}
    );
}

sub getHeadref{
    my $i = $_;
    my $headref =  $i->{att}->{"headref"}?$i->{att}->{"headref"}:"";
    if (! $extradata{"headref"}{$headref}) {
	 $extradata{"headref"}{$headref}{"words"} = [];
	 $extradata{"headref"}{$headref}{"parent"} = $i->parent()->{att}->{"label"};
    }
    
    if ($headref ne "") {
	my @endchildren = $i->children();
	my $localdata = {};
	my $cnt = 0;
	foreach my $j (@endchildren) {
	    push(@{$extradata{"headref"}{$headref}{"words"}}, $j);
	    #my ($tempdata, $position) = &splitWord (\@arrayWord, $j, $label, $position);
	    #$cnt++;
	}
	# add extra line number; find parent of swc
	#my $parent = $i->parent();
	#if ($parent->{att}->{"label"}) { my $extraLabel = $parent->{att}->{"label"}; $label .= "-".$extraLabel; }
    }
}
sub returnHeadref{
    my $item = shift;
    if ($extradata{"headref"}{$item}) {
	return $extradata{"headref"}{$item};
    }
    return "";
}

1;