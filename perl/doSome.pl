#!/usr/bin/perl -w
use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path $0 );
use lib "/home/varoracc/local/oracc/www/qlab/cuneiform/perl/lib/lib/perl5/";


#can run from command line: perl doSome.pl num_test P249253 /home/varoracc/local/oracc/www/qlab/cuneiform
# where num_test is an arbitrary name for the file. 
use CHUNKER::generic;
use CHUNKER::singlefilestats;
use CHUNKER::Borger;
use CHUNKER::metadata;
use CHUNKER::punct;
use CHUNKER::getcorpus;
use CHUNKER::getProjectList;
use CHUNKER::configit;

my $config = CHUNKER::configit::getConfigItems();
my $base = $config->{"base"};

my $basepath = $config->{"basepath"};
my $baseresults = $config->{"baseresults"};

use CGI qw(:all *table *Tr *td);
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;


&CHUNKER::generic::writetoerror("timemarking","starting ".localtime);
# first get a list of all the texts and some basic meta data
#&CHUNKER::getcorpus::getthetexts($baseresults, $basepath);

#initialise Borger and osl

my $ogslfile = $base."/resources/ogsl.xml";
my $Borgerfile = $base."/resources/Borger.xml";
&CHUNKER::Borger::openOgslAndBorger($ogslfile, $Borgerfile);


if($#ARGV==2){
    my $filepath =  $ARGV[0];
    my @files = split(/,/, $ARGV[1]);
    my $sysdir = $ARGV[2];
    
#    make sure we have the data initially parsed
    foreach my $f (@files){
        &CHUNKER::singlefilestats::statasinglefile($basepath."/".$f."/".$f.".xtf", $baseresults);
    }
    
    # get a sub section compilation for bar charts
    &CHUNKER::compilationLang::useFiles($baseresults."/signs",$baseresults,\@files,$filepath);
    
    
    #make the CORPUS_META file used to select the sections to search against
    &CHUNKER::getProjectList::makeFile($baseresults."/metadata",$baseresults);
    print "finished";
}
