#!/usr/bin/perl -w
use strict;
use CHUNKER::generic;
use CHUNKER::singlefilestats;
use CHUNKER::Borger;
use CHUNKER::metadata;
use CHUNKER::punct;
use CHUNKER::getProjectList;

my $base = "/home/qlab/02www/cuneiform";#/Users/csm22/Work/Cuneiform/git/cuneiform";

#/home/varoracc/local/oracc/bld
my $basepath = $base."/datain";
my $baseresults = $base."/dataout4";

use CGI qw(:all *table *Tr *td);
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;

&CHUNKER::generic::writetoerror("timemarking","starting ".localtime);
# first get a list of all the texts 
&CHUNKER::getcorpus::getthetexts($baseresults, $basepath);

#initialise Borger and osl

my $ogslfile = $base."/resources/ogsl.xml";
my $Borgerfile = $base."/resources/Borger.xml";
&CHUNKER::Borger::openOgslAndBorger($ogslfile, $Borgerfile);


#second loop over those texts and do the stats stuff
&CHUNKER::singlefilestats::statasinglefile($base."/datain/Q002575/Q002575.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P224395/P224395.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P002296/P002296.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P336398/P336398.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P224395/P224395.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P224431/P224431.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P235724/P235724.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P338326/P338326.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P338462/P338462.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P338499/P338499.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P338566/P338566.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P345960/P345960.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P348776/P348776.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile($base."/datain/P382687/P382687.xtf", $baseresults);

# get the compilations needed for the bar charts.
&CHUNKER::compilationLang::makeFiles($baseresults."/signs",$baseresults);

# get a sub section compilation for bar charts
#&CHUNKER::compilationLang::useFiles($baseresults."/signs",$baseresults,["P002296","P345960"],"sub1");


#make the CORPUS_META file used to select the sections to search against
&CHUNKER::getProjectList::makeFile($baseresults."/metadata",$baseresults);

&CHUNKER::generic::writetoerror("timemarking","ending ".localtime);
