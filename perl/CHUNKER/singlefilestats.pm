package CHUNKER::singlefilestats;
use base 'CHUNKER';

use CHUNKER::metadata;
use CHUNKER::extra;
use CHUNKER::structuredata;
use CHUNKER::compilationLang;
use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;

my $thisText = "";
my $thisCorpus = "";
my $root = "";
my %compilationERSigns = ();
my %compilationERWords = ();
my %PQdata = ();
my %PQdataBorger = ();
my $OgslRoot = "";
my $BorgerRoot = "";

#loop over everything in dataout/fullist and analyse it
sub statallfiles{
    &CHUNKER::generic::writetoerror("timestamping","statallfiles - starting ".localtime); 
    &CHUNKER::generic::writetoerror("timestamping","statallfiles - ending ".localtime); 
}

#loop over everythign in dataout/fulllist that hasn't been anaylsed and do it.
sub statmissingfiles{
    &CHUNKER::generic::writetoerror("timestamping","statmissingfiles - starting ".localtime); 
    &CHUNKER::generic::writetoerror("timestamping","statmissingfiles - ending ".localtime); 
}

sub doesthisfileexits{
    my $test = shift;
    if (-e $test) {
	return 1;
    }
    return 0;
}

sub statasinglefile{
    my $filepath = shift;
    my $baseresults = shift;
    print "PROCESS ".$filepath."\n";
    
    &CHUNKER::generic::writetoerror("timestamping","statasinglefile - starting ".localtime); 
    #is this a P or Q
    if($filepath =~ m|/([^/]*)\.[^\.]*$|){
        #my $shortname = $1;
        $thisText = $1;
	my $shortname = $thisText;
	my $xmdfile = $filepath;
        $xmdfile =~ s|(\.\w*)$|.xmd|;
#does file exist
	if(-e $filepath && -e $xmdfile){	
	if (&doesthisfileexits($baseresults."/structure/".$shortname.".xml")) {
	    print "finished as already exists\n";
	}
	else{
	    if($thisText =~ m|^Q|gsi){
		#&doQstats($filepath, $thisText);
	    }
	    elsif($thisText =~ m|^P|gsi){
		
		# .xmd, metadata-file
		my $twigObjXmd = XML::Twig->new(
					     twig_roots => { 'cat' => \&CHUNKER::metadata::getCatM }
					     );
		$twigObjXmd->parsefile($xmdfile);
		my $rootxmd = $twigObjXmd->root;
		$twigObjXmd->purge;
		$twigObjXmd->dispose;
		
		# xtf-file
		my $twigObj = XML::Twig->new(
					     twig_roots => {
							    'transliteration' => 1,
							    'protocols' => 1,
							    'object' => 1,
							    'mds' => 1,
							    'xcl' => \&CHUNKER::metadata::getXclM,
							    'protocols/protocol' => \&CHUNKER::metadata::getProtM,
							    'mds/m' =>\&CHUNKER::metadata::getMDSM,
							    'object' => \&CHUNKER::metadata::getObjM,
							    'g:swc' => \&CHUNKER::extra::getHeadref
							    }
					     );
		$twigObj->parsefile($filepath);
		$root = $twigObj->root;
		$twigObj->purge;
		$twigObj->dispose;
		
		
		my $metadata = &CHUNKER::metadata::returnMetaData;
		my $data = ();
		$data->{"metadata"} = $metadata;
		&CHUNKER::word::initialise(&CHUNKER::metadata::getCorpus(), $thisText);
		&CHUNKER::punct::initialise(&CHUNKER::metadata::getCorpus(), $thisText);
		&CHUNKER::linedata::initialise(&CHUNKER::metadata::getCorpus(), $thisText);
		
		my $allstructs = &CHUNKER::structuredata::getStructureData($root, "P", $thisText, $baseresults, $filepath, &CHUNKER::metadata::getCorpus());
		$data->{"A_Structure"} = $allstructs;
		my $signs = &CHUNKER::punct::returnPunct();
		my $words = &CHUNKER::word::returnData();
		my $borger = &CHUNKER::Borger::returnBorger();
		$data->{"B_Signs"}=$signs;
		$data->{"C_Borger"}=$borger;
		$data->{"D_Words"}=$words;
		
		
		&CHUNKER::generic::writetofile($shortname, $allstructs, "structure", $baseresults);
		&CHUNKER::generic::writetofile($shortname, $metadata, "metadata", $baseresults);
		&CHUNKER::generic::writetofile($shortname, $data, "files", $baseresults);
		&CHUNKER::generic::writetofile($shortname, $words, "words", $baseresults);
		&CHUNKER::generic::writetofile($shortname, $borger, "borger", $baseresults);
		&CHUNKER::generic::writetofile($shortname, $signs, "signs", $baseresults);
	    }
	}	
	}
    }
    &CHUNKER::generic::writetoerror("timestamping","statasinglefile - ending ".localtime); 
}









1;
