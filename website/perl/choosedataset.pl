#!/usr/bin/perl -w
use strict;
use warnings;

use utf8;

my %corpora = ();

($in{corpus1}, $in{corpus2});

&writetofile($shortname,\%localdata);


sub writetofile{
    my $shortname = shift; #passed in as a parameter
    my $data = shift; #passed in as a parameter
    my $startpath = $resultspath."/".$resultsfolder;
    &makedir ($startpath); #pass to function
    my $destinationdir = $startpath;
    print $destinationdir."/".$shortname;
    if(defined $data){
    #    create a file called the shortname - allows sub sectioning of error messages
	open(SUBFILE2, ">".$destinationdir."/".$shortname) or die "Couldn't open: $!";
	binmode SUBFILE2, ":utf8";
	print SUBFILE2 XMLout($data);
	close(SUBFILE2);
    }
}

#create the folder if it doesn't already exist -
#issue will ensure if permissions on the parent folder are incorrect
sub makedir {
    my $path = shift;
    my $result = `mkdir $path 2>&1`; 
}



