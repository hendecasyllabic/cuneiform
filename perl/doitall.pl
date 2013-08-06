#!/usr/bin/perl -w
use strict;
use CHUNKER::configit;
use CHUNKER::generic;
use CHUNKER::singlefilestats;
use CHUNKER::Borger;
use CHUNKER::metadata;
use CHUNKER::getcorpus;
use CHUNKER::punct;
use CHUNKER::getProjectList;
# this file allows us to build up the corpus lists to be used later

my $config = CHUNKER::configit::getConfigItems();
my $base = $config->{"base"};
my $basepath = $config->{"basepath"};
my $baseresults = $config->{"baseresults"};

use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;

&CHUNKER::generic::writetoerror("timemarking","starting ".localtime);
# first get a list of all the texts 
&CHUNKER::getcorpus::getthetexts($baseresults, $config->{"buildpath"});

#initialise Borger and osl

my $ogslfile = $base."/resources/ogsl.xml";
my $Borgerfile = $base."/resources/Borger.xml";
&CHUNKER::Borger::openOgslAndBorger($ogslfile, $Borgerfile);

#loop over all files in fulllist
&CHUNKER::getcorpus::processtexts($baseresults);

#if you want to specify individual files instead...
#&CHUNKER::singlefilestats::statasinglefile($base."/datain/Q002575/Q002575.xtf", $baseresults);
#&CHUNKER::singlefilestats::statasinglefile($base."/datain/P224395/P224395.xtf", $baseresults);
#&CHUNKER::singlefilestats::statasinglefile($base."/datain/P002296/P002296.xtf", $baseresults);
#&CHUNKER::singlefilestats::statasinglefile($base."/datain/P336398/P336398.xtf", $baseresults);
#&CHUNKER::singlefilestats::statasinglefile($base."/datain/P224395/P224395.xtf", $baseresults);
#&CHUNKER::singlefilestats::statasinglefile($base."/datain/P224431/P224431.xtf", $baseresults);

# get the compilations needed for the bar charts.
&CHUNKER::compilationLang::makeFiles($baseresults."/signs",$baseresults);

# get a sub section compilation for bar charts
#&CHUNKER::compilationLang::useFiles($baseresults."/signs",$baseresults,["P002296","P345960"],"sub1");


#make the CORPUS_META file used to select the sections to search against
&CHUNKER::getProjectList::makeFile($baseresults."/metadata",$baseresults);

&CHUNKER::generic::writetoerror("timemarking","ending ".localtime);
