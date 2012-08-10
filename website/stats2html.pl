#!/usr/bin/perl -w
use strict;
use warnings;
use utf8;
use XML::Twig;
use XML::Simple;
use Graphics::Primitive::Driver::GD;
use Chart;

my $myhtml = "./stats/stats.html";

&stats2html();

sub stats2html{
    
    &clearfile($myhtml);
    &write2html($myhtml, "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">");
    &write2html($myhtml, "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">");
    
    &write2html($myhtml, "<head> <title>General statistics</title> </head>");
    &write2html($myhtml, "<body>General statistics");
    
    &write2html($myhtml, "</body>");
    &write2html($myhtml, "</html>");
    
}


sub clearfile{
    my $file = shift;
    open(FILE, ">".$file);
    print FILE "";
    close FILE;
}

sub write2html{
    my $htmlfile = shift; #passed in as a parameter
    my $data = shift; #passed in as a parameter
    
    if(defined $data){
    #    create a file called the shortname - allows sub sectioning of error messages
	open(FILE, ">>".$htmlfile) or die "Couldn't open: $!";
	binmode FILE, ":utf8";
	print FILE ($data);
	close(FILE);
    }
}

