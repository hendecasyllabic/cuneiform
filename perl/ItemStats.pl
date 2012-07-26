#!/usr/bin/perl -w
use warnings;
use strict;
use Carp ();
local $SIG{__WARN__} = \&Carp::cluck;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;
binmode STDOUT, ":utf8";

# PROBLEM?
#http://oracc.museum.upenn.edu/doc/builder/l2/howitworks
#The relationship between lemmatization and projects in L2 is very simple: texts are only ever lemmatized
#within their owner project. Texts may be borrowed by other projects (proxied),
#but the borrowing project cannot change the lemmatization of the text.


my $PQroot = "";
my %PQdata = ();  # data per text
my %corpusdata = (); # overview of selected metadata per corpus
my %combos = ();

my $thisCorpus = "";
my $thisText = "";

my %langmatrix; # other codes in use? ask Steve TODO
$langmatrix{"lang akk"} = "Akkadian"; $langmatrix{"lang a"} = "Akkadian"; $langmatrix{"akk"} = "Akkadian";
$langmatrix{"lang eakk"} = "Early Akkadian"; $langmatrix{"akk-x-earakk"} = "Early Akkadian"; # For pre-Sargonic Akkadian
$langmatrix{"lang oakk"} = "Old Akkadian"; $langmatrix{"akk-x-oldakk"} = "Old Akkadian";
$langmatrix{"lang ur3akk"} = "Ur III Akkadian"; $langmatrix{"akk-x-ur3akk"} = "Ur III Akkadian"; # akk-x-ur3akk may not exist ?? (check when Steve sends language list - Steve TODO)
$langmatrix{"lang oa"} = "Old Assyrian"; $langmatrix{"akk-x-oldass"} = "Old Assyrian";
$langmatrix{"lang ob"} = "Old Babylonian"; $langmatrix{"akk-x-oldbab"} = "Old Babylonian";
$langmatrix{"akk-x-obperi"} = "Peripheral Old Babylonian";
$langmatrix{"lang ma"} = "Middle Assyrian"; $langmatrix{"akk-x-midass"} = "Middle Assyrian";
$langmatrix{"lang mb"} = "Middle Babylonian"; $langmatrix{"akk-x-midbab"} = "Middle Babylonian";
$langmatrix{"lang na"} = "Neo-Assyrian"; $langmatrix{"akk-x-neoass"} = "Neo-Assyrian";
$langmatrix{"lang nb"} = "Neo-Babylonian"; $langmatrix{"akk-x-neobab"} = "Neo-Babylonian";
$langmatrix{"akk-x-ltebab"} = "Late Babylonian";
$langmatrix{"lang sb"} = "Standard Babylonian"; $langmatrix{"lang akk-x-stdbab"} = "Standard Babylonian"; $langmatrix{"akk-x-stdbab"} = "Standard Babylonian";
$langmatrix{"lang ca"} = "Conventional Akkadian"; $langmatrix{"akk-x-conakk"} = "Conventional Akkadian"; # The artificial form of Akkadian used in lemmatisation Citation Forms.

$langmatrix{"lang n"} = "normalised"; $langmatrix{"ANY-x-normal"} = "normalised"; # Used in lexical lists and restorations; try to avoid wherever possible.
$langmatrix{"lang g"} = "transliterated (graphemic) Akkadian"; # Only for use when switching from normalised Akkadian.
$langmatrix{"lang h"} = "Hittite"; $langmatrix{"lang hit"} = "Hittite"; 
$langmatrix{"lang s"} = "Sumerian"; $langmatrix{"lang sux"} = "Sumerian"; $langmatrix{"sux"} = "Sumerian"; $langmatrix{"lang eg"} = "Sumerian"; $langmatrix{"sux-x-emegir"} = "Sumerian"; # The abbreviation eg stands for Emegir (main-dialect Sumerian)

$langmatrix{"sux akk"} = "Sumerian - Akkadian";
$langmatrix{"akk-x-stdbab sux"} = "Standard Babylonian - Sumerian"; 

my %config;
$config{"typename"} = "";
$config{"filehash"} = ();
$config{"filelist"} = ();
$config{"dirlist"} = ();
my $destinationdir = "../dataoutNEW";
my $startpath = "..";
my $startdir = "datain";
my $errorfile = "../errors";
my $errorpath = "perlerrors";
my $outputtype="text";
my $resultspath = "..";
my $resultsfolder = "/dataoutNEW";

my @splitrefs; # list of xml:id/headref; keep track of the split words that have been analysed through headform, so that they're not analysed twice.

&ItemStats();

sub ItemStats{    
    &writetoerror("ItemStats.txt","starting ".localtime);
    my $ext = "xtf";
    $config{"typename"} = $ext;
    &traverseDir($startpath, $startdir,$config{"typename"},1,$ext);
    my @allfiles = @{$config{"filelist"}{$config{"typename"}}};
    
# loop over each of the xtf-files we found
    foreach(@allfiles){
        my $filename = $_;
        if($filename =~ m|/([^/]*).${ext}$|){
            #my $shortname = $1;
	    $thisText = $1;
	    &outputtext("\nShortName: ". $thisText);
            if($thisText =~ m|^Q|gsi){
                &doQstats($filename, $thisText);
            }
	    elsif($thisText =~ m|^P|gsi){
		&doPstats($filename, $thisText);
	    }
	}
    }
    
# Create corpus metadatafile for the whole corpus
    &writetofile("CORPUS_META", \%corpusdata);

# list of combos    
    &writetofile("combos", \%combos);
}

sub doQstats{
    my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes = 0;
    
    # combine P and Qstats?? TODO
    
    # xtf-file
    # Normally, Q-files have a 'composite' structure (and thus the twig_root 'composite').
    # However, for some reason, some Q-texts have an object/surface etc. structure, e.g. Q003232 (RINAP); these don't have a 'composite' root, but need 'transliteration' and 'object' instead.
    my $twigObj = XML::Twig->new(
				 twig_roots => { 'composite' => 1, 'protocols' => 1, 'mds' => 1, 'transliteration' => 1, 'object' => 1 }  
				 );
    $twigObj->parsefile($filename);
    my $root = $twigObj->root;
    $twigObj->purge;
    
    # again: 'composite' for normal Q-texts; 'transliteration' for special cases.
    my $twigPQObj = XML::Twig->new(
                                 twig_roots => { 'composite' => 1, 'transliteration' => 1, 'xcl' => 1 }
                                 );
    $twigPQObj->parsefile($filename);
    $PQroot = $twigPQObj->root;
    $twigPQObj->purge;
    
    # .xmd, metadata-file
    my $twigObjXmd = XML::Twig->new(
                                 twig_roots => { 'cat' => 1 }
                                 );
    my $xmdfile = $filename;
    $xmdfile =~ s|(\.\w*)$|.xmd|;
    $twigObjXmd->parsefile($xmdfile);
    my $rootxmd = $twigObjXmd->root;
    $twigObjXmd->purge;
    
#   Q texts: possibly divided into divs with lines, linegroups and nonx
#   get general stats, graphemes, groups and words
    for (keys %PQdata){
        delete $PQdata{$_};
    }
    
    &getMetaData($root, $rootxmd, $shortname, "Q");

    if (!defined $PQdata{"01_Structure"}) { $PQdata{"01_Structure"} = (); }

    push(@{$PQdata{"01_Structure"}}, &getStructureData($root, "Q"));

    &checkPQdataStructure;

    &writetofile($shortname, \%PQdata);
}

sub doPstats{
    my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes = 0;
    
    # xtf-file
    my $twigObj = XML::Twig->new(
                                 twig_roots => { 'transliteration' => 1, 'protocols' => 1, 'object' => 1, 'mds' => 1 }
                                 );
    $twigObj->parsefile($filename);
    my $root = $twigObj->root;
    $twigObj->purge;
    
    my $twigPQObj = XML::Twig->new(
                                 twig_roots => { 'transliteration' => 1, 'xcl' => 1 }
                                 );
    $twigPQObj->parsefile($filename);
    $PQroot = $twigPQObj->root;
    $twigPQObj->purge;
    
    # .xmd, metadata-file
    my $twigObjXmd = XML::Twig->new(
                                 twig_roots => { 'cat' => 1 }
                                 );
    my $xmdfile = $filename;
    $xmdfile =~ s|(\.\w*)$|.xmd|;
    $twigObjXmd->parsefile($xmdfile);
    my $rootxmd = $twigObjXmd->root;
    $twigObjXmd->purge;

    for (keys %PQdata){
        delete $PQdata{$_};
    }

    &getMetaData($root, $rootxmd, $shortname, "P");

    if (!(defined $PQdata{"01_Structure"})) { $PQdata{"01_Structure"} = (); }
    
    push(@{$PQdata{"01_Structure"}}, &getStructureData($root, "P"));

    &checkPQdataStructure;

    &writetofile($shortname,\%PQdata);
}


sub getMetaData{  # find core metadata fields and add them to each itemfile [$PQdata] + corpus metadata-file [corpusdata]
    my $root = shift;
    my $rootxmd = shift;
    my $PQnumber = shift;
    my $PorQ = shift;

    $PQdata{"name"} = $PQnumber;    
    $PQdata{"designation"} = ""; $PQdata{"genre"} = ""; $PQdata{"language"} = ""; $PQdata{"object"} = ""; 
    $PQdata{"period"} = ""; $PQdata{"project"} = ""; $PQdata{"provenance"} = ""; 
    $PQdata{"script"} = ""; $PQdata{"subgenre"} = ""; $PQdata{"writer"} = "";
    
    my $designation = "unspecified"; my $genre = "unspecified"; my $language = "unspecified"; my $object = "unspecified";
    my $period = "unspecified"; my $project = "unspecified"; my $provenance = "unspecified";
    my $script = "unspecified"; my $subgenre = "unspecified"; my $writer = "unspecified"; 
      
    # first check the mds/m fields (period, genre, subgenre and provenience) in the xtf-file    
    my @mfields = $root->get_xpath('mds/m');
    foreach my $i (@mfields){
	if($i->{att}->{k} eq "period"){   # e.g. <m k="period">Hellenistic</m>
	    $PQdata{"period"} = $i->text;
	}
	if($i->{att}->{k} eq "genre"){    # e.g. <m k="genre">administrative letter</m>
	    $PQdata{"genre"} = $i->text;
	}
	if($i->{att}->{k} eq "subgenre"){   
	    $PQdata{"subgenre"} = $i->text;
	}
	if($i->{att}->{k} eq "provenience"){   
	    $PQdata{"provenance"} = $i->text;
	}
    }
    
    if (my @temp = $root->get_xpath('object')) {
	$PQdata{"object"} = $temp[0]->{att}->{type};
    }
        
    # the mds/m fields are not always filled in even if the information is known, hence we may need to check the metadatafile.
    $PQdata{"designation"} = $rootxmd->findvalue('cat/designation');
    
    if($PQdata{"period"} eq ""){
	$PQdata{"period"} = $rootxmd->findvalue('cat/period');

	# no period in SAAo, but <date c="1000000"/> [Neo-Assyrian]
	if($PQdata{"period"} eq ""){
	    my @date = $rootxmd->get_xpath('cat/date');
	    foreach my $i (@date) {
		my $temp = $i->{att}->{c};
		if($temp eq "1000000"){   # Q: Other codes ??? [ask Steve ***]
		    $PQdata{"period"} = "Neo-Assyrian";  
		}
	    }
	}
    }
    
    if ($PQdata{"genre"} eq ""){
	$PQdata{"genre"} = $rootxmd->findvalue('cat/genre');
    }
    
    if ($PQdata{"subgenre"} eq ""){
	$PQdata{"subgenre"} = $rootxmd->findvalue('cat/subgenre');
    }
    
    if ($PQdata{"provenance"} eq ""){
	$PQdata{"provenance"} = $rootxmd->findvalue('cat/provenience');
	if ($PQdata{"provenance"} eq ""){
	    $PQdata{"provenance"} = $rootxmd->findvalue('cat/provenance');
	}
    }
    
    
#http://oracc.museum.upenn.edu/doc/builder/l2/langtags    
    my @temp = $PQroot->get_xpath('xcl');
    $PQdata{"language"} = $temp[0]->{att}->{"langs"}?$temp[0]->{att}->{"langs"}:"";  # with L2!
    if ($PQdata{"language"} eq "") {
	$PQdata{"language"} = $rootxmd->findvalue('cat/language')?$rootxmd->findvalue('cat/language'):""; 
    }
    
    my @protocols = $root->get_xpath('protocols/protocol');
	 # http://oracc.museum.upenn.edu/doc/builder/l2/languages/#Language_codes
    foreach my $i (@protocols) {
	if (($PQdata{"language"} eq "") && ($i->{att}->{type} eq "atf")) { $PQdata{"language"} = $i->text; }
	if ($i->{att}->{type} eq "project") { $PQdata{"project"} = $i->text; }
    }

    if ($langmatrix{$PQdata{"language"}}) {
        $PQdata{"language"} = $langmatrix{$PQdata{"language"}};
    }
    else {
        # append to file NewLangCodes.txt
        &writetoerror ("NewLangCodes.txt", localtime." Project: ".$PQdata{"project"}.", text ".$PQnumber.": ".$PQdata{"language"});
    }
    
#   in SAA not given in metadata, but in xtf-file under
#        <protocols scope="text">
#		<protocol type="project">saao/saa10</protocol>
#		<protocol type="atf">lang nb</protocol>
#		<protocol type="key">file=SAA10/LAS_NB.saa</protocol>
#		<protocol type="key">musno=K 00552</protocol>
#		<protocol type="key">cdli=ABL 0255</protocol>
#		<protocol type="key">writer=A@aredu</protocol>
#		<protocol type="key">L=B</protocol>
#	</protocols>
    
    $PQdata{"script"} = $rootxmd->findvalue('cat/script');
    
    $PQdata{"writer"} = $rootxmd->findvalue('cat/ancient_author'); # SAA; colophon information does not seem to be included in metadata (neither is the scribe especially marked in xtf)
    
    # For corpusdata-file: allow for quick metadata search on PQ-number, period, provenance, genre, language, etc.
    
    if ($PQdata{"designation"} ne "") { $designation = $PQdata{"designation"}; }
    if ($PQdata{"genre"} ne "") { $genre = $PQdata{"genre"}; }
    if ($PQdata{"language"} ne "") { $language = $PQdata{"language"}; }
    if ($PQdata{"object"} ne "") { $object = $PQdata{"object"}; }
    if ($PQdata{"period"} ne "") { $period = $PQdata{"period"}; }
    if ($PQdata{"project"} ne "") { $project = $PQdata{"project"}; }
    if ($PQdata{"provenance"} ne "") { $provenance = $PQdata{"provenance"}; }
    if ($PQdata{"script"} ne "") { $script = $PQdata{"script"}; }
    if ($PQdata{"subgenre"} ne "") { $subgenre = $PQdata{"subgenre"}; }
    if ($PQdata{"writer"} ne "") { $genre = $PQdata{"writer"}; }
    
    if (!defined $corpusdata{"corpus"}) { $corpusdata{"corpus"} = (); }

    push(@{$corpusdata{"corpus"}{$project}{"designation"}{$designation}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"genre"}{$genre}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"language"}{$language}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"object"}{$object}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"period"}{$period}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"provenance"}{$provenance}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"script"}{$script}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"subgenre"}{$subgenre}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"writer"}{$writer}{$PorQ}}, $PQnumber);
    
    $thisCorpus = $project;
}

sub getStructureData{
    my $root = shift;
    my $PorQ = shift;
    my %structdata = ();
    my $localdata = {};
    my $label = "";
    
    # P-texts: surfaces, columns, divisions [milestones], lines # MILESTONES/COLOPHONS ??? Steve TODO
    # Argue again with Steve about milestones. Please make them cf. divisions as then the information can also be used when the text is not yet lemmatized.
    # colophons e.g. in P363689 and P338566: in first section of xtf only stupid line: <m type="discourse" subtype="colophon" />
    # then division in xcl: <c type="discourse" subtype="colophon" xml:id="P363689.U389" level="1" bracketing_level="0">
    # in P271567: in first section: <m type="locator" subtype="colophon">colophon</m>, BUT AS THIS TEXT IS NOT LEMMATIZED, THERE IS NO 'COLOPHON' SECTION IN XCL-PART!!
    # because of this situation, milestones and colophons cannot yet be taken into account. Maybe in the future?
    
    # Q-texts: divisions, lines

    my @nonxes = $root->get_xpath('nonx');
    foreach my $n (@nonxes) {
	$localdata->{'extent'} = $n->{att}->{extent}?$n->{att}->{extent}:"";
	$localdata->{'scope'} = $n->{att}->{scope}?$n->{att}->{scope}:"";
	$localdata->{'state'} = $n->{att}->{state}?$n->{att}->{state}:"";
	$localdata->{'text'} = $n->text;
	
	push(@{$structdata{"nonx"}}, $localdata);
	$localdata = {};
    }

    my @surfaces = $root->get_xpath('object/surface');
    my $no_surfaces = scalar @surfaces;
    foreach my $s (@surfaces) {
	if (!defined $structdata{"surface"}) {
	    $structdata{"surface"} = ();
	    $structdata{"no_surfaces"} = $no_surfaces;
	}

	$localdata = &getStructureData($s, $PorQ);
	$localdata->{'type'} = $s->{att}->{type}?$s->{att}->{type}:"";    
	$localdata->{'label'} = $s->{att}->{label}?$s->{att}->{label}:"";

        push(@{$structdata{"surface"}}, $localdata);
	$localdata = {};
    }
    
    my @columns = $root->get_xpath('column');
    my $no_columns = scalar @columns;
    foreach my $c (@columns) {
	if (!defined $structdata{"column"}) {
	    $structdata{"column"} = ();
	    $structdata{"no_columns"} = $no_columns;
	}
	
	$localdata = &getStructureData($c, $PorQ);
	my $col = $c->{att}->{n}; $localdata->{'no'} = $col;
	
        push(@{$structdata{"column"}}, $localdata);
	$localdata = {};
    }
    
    my @divs = $root->get_xpath('div');
    my $no_divs = scalar @divs;
    foreach my $d (@divs) {
	if (!defined $structdata{"div"}) {
	    $structdata{"div"} = ();
	    $structdata{"no_divs"} = $no_divs;
	}
	
	$localdata = &getStructureData($d, $PorQ);
	$localdata->{'type'} = $d->{att}->{type}?$d->{att}->{type}:"";    
	$localdata->{'n'} = $d->{att}->{n}?$d->{att}->{n}:"";

	push (@{$structdata{"div"}}, $localdata);
	$localdata = {};
    }
    
    my @linegroups = $root->get_xpath('lg');
    my $no_lgs = scalar @linegroups;
    if ($no_lgs != 0) { $structdata{'no_lgs'} += $no_lgs; }
    
    #The second line in a linegroup doesn't get its own line number; however, the line is physical in the case of bilinguals and glosses.
    
    #Glosslines (Gloss Underneath Stream, GUS): 2 lines (one with normal text, one with gloss), both lines lemmed, both lines physical
    #Bilingual: 2 lines (one in standard language, one in other language), both lines lemmed, both lines physical
    
    #Linearized Grapheme Stream (LGS): order on tablet, no words, just signs, not lemmed; this is actually the physical line, whereas l is interpretation
    #Normalized Transliteration Stream (NTS): not a physical line, nts lines are interpretations; if present the lemmatization is given here
    
    foreach my $lg (@linegroups) {
	my @speciallines = $lg->get_xpath('l');
	my $type = ""; $label = ""; 
	foreach my $j (@speciallines) { # check type of lg
	    if ($type eq "") {
		if ($j->{att}->{"type"}) { $type = $j->{att}->{"type"}; }
	    }
	    if ($label eq "") {
		if ($j->{att}->{"label"}) { $label = $j->{att}->{"label"}; }
	    }
	}

	# if bil or gus -> 2 lines, read both with &getLineData
	if (($type eq "gus") || ($type eq "bil")) {
	    $structdata{'no_lines'} += scalar @speciallines; 
	    my $number = 0;
	    foreach my $j (@speciallines) {
		$number++;
		my $speciallabel = $label." (".$number.")";
		$localdata = &getLineData($j, $speciallabel, "");
		$localdata->{"type"} = $type;
		$localdata->{"label"} = $speciallabel;
		push (@{$structdata{"line"}}, $localdata);
		$localdata = {};
	    }
	}
	elsif ($type eq "lgs") { # analyse l line, disregard lgs line (even though order on tablet - there doesn't seem to be an automatic link between the elements in the lgs and the words in l) *** still to be implemented *** still has to go through getLineData TODO
	    # NOTE: this partly distorts the data as the order in which the words are written is not the order given in l (hence the note (lgs) to the label).
	    # in dcclt: P225958, P231055, P240986, P247847, P247848, P332923, Q000003, Q000014
	    #&writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": lgs");
	    foreach my $j (@speciallines) {
		my $kind = $j->{att}->{"type"}?$j->{att}->{"type"}:"";
		if ($kind ne "lgs") {
		    my $speciallabel = $label." (lgs)";
		    $localdata = &getLineData($j, $speciallabel, "");
		    $localdata->{"type"} = $type;
		    $localdata->{"label"} = $label;
		    push (@{$structdata{"line"}}, $localdata);
		    $localdata = {};
		}
	    }
	    $structdata{'no_lines'}++;
	}
	else { # nts: STEVE: does this still exist??? *** if so, still has to go through getLineData TODO
	    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": nts");
	    $localdata->{"type"} = $type;
	    $localdata->{"label"} = $label;
	    push (@{$structdata{"line"}}, $localdata);
	    $structdata{'no_lines'}++;
	    $localdata = {};
	    # still to be implemented
	}
    }
   
    my @lines = $root->get_xpath('l');
    my $no_lines = scalar @lines;
    if ($no_lines != 0) {
	$structdata{'no_lines'} += $no_lines;
	
    }
    foreach my $l (@lines) {
	if (!defined $structdata{"line"}) {
	    $structdata{"line"} = ();
	}
	
	$label = $l->{att}->{"label"};
	$localdata = &getLineData($l, $label, "");
	$localdata->{"label"} = $label;
	push (@{$structdata{"line"}}, $localdata);
	$localdata = {};
    }
    return \%structdata;
}

sub getLineData {
    my $root = shift;
    my $label = shift;
    my $note = shift || "";
    my %linedata = ();
    my $localdata = {};
    my $writtenAs = shift || "";
    
    # cells, fields, alignment groups, l.inner
    my $sumgraphemes =0;
    
    my @cells = $root->get_xpath('c');
    foreach my $c (@cells){
	$localdata = &getLineData($c, $label, "");
	$localdata->{"span"} = $c->{att}->{"span"};
	push(@{$linedata{'cells'}}, $localdata);
	$localdata = {};
    }
    
    my @fields = $root->get_xpath('f');
    foreach my $f (@fields){
	$localdata = &getLineData($f, $label, "");
	$localdata->{"type"} = $f->{att}->{"type"};
	push(@{$linedata{'fields'}}, $localdata);
	$localdata = {};
    }
    
    my @alignmentgrp = $root->get_xpath('ag');
    foreach my $ag (@alignmentgrp) {
	$localdata = &getLineData($ag, $label, ""); 
	$localdata->{"form"} = $ag->{att}->{"form"};
	push(@{$linedata{'alignmentgroup'}}, $localdata);
	$localdata = {};
    }
   
    # l.inner
    # l.inner = (words, normwords), surro, gloss
    # surro: P271567; P363419; P363582; P363689; P404861; Q002575 (e.g. :. standing for mukinnu - 1st part treated as nonw!)
    
    my @surros = $root->get_xpath('surro');
    my $no_surros = scalar @surros;
    # if I understand this correctly, then the first element in a surro is a nonw, existing of only one element (g:p, g:s, g:v, g:c)? - TODO Chris check schema
    # the second element in a surro can exist of several elements (e.g. words)
    # (e.g. MIN - lugal; :. - mukinnu)
    foreach my $surro (@surros) { 
	my @children = $surro->children();
	my @nonw = (); my @nonwBreak = (); my $secondPart = ""; my $cnt = 0;
	my $type = ""; my @arrayNonWord = ();
	my $cf = ""; my $gw = ""; my $langsurro = ""; my $form = ""; my $nonwLang = ""; my $role = "";
	foreach my $i (@children) {
	    my $tag = $i->tag;
	    if ($tag eq 'g:nonw') { # the nonw can be a punctuation mark or a "word" 
		my @nonwElements = $i->children();
		my $no_els = scalar (@nonwElements);
		if ($no_els > 1) {
		    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.", ".$label.": more than one element in g:nonw in surro.");
		}
		$nonwLang = $i->{att}->{"xml:lang"}?$i->{att}->{"xml:lang"}:"noLang";
		my $tempdata = {};
		
		foreach my $nonwEl (@nonwElements) {
		    my $nonwTag = $nonwEl->tag; # check if there are other options than these? TODO Chris schema?
		    if ($nonwTag eq 'g:p') { # punctuation - should be only one
			$type = "punct";
			$nonw[$cnt] = $nonwEl->{att}->{"g:type"}?$nonwEl->{att}->{"g:type"}:"";
			$nonwBreak[$cnt] = $nonwEl->{att}->{"g:break"}?$nonwEl->{att}->{"g:break"}:"preserved";
		    }	
		    else {
			$type = "word"; my $position = 1;
			$role = $nonwEl->{att}->{"g:role"}?$nonwEl->{att}->{"g:role"}:"";
			($tempdata, $position) = &splitWord (\@arrayNonWord, $nonwEl, $label, $position); # resulting info in @arrayNonWord
		    }
		    $cnt++;
		}
	    }
	    else {
		# second part of surro - stands for, can be several words
		my $wordid = $i->{att}->{"xml:id"}?$i->{att}->{"xml:id"}:""; # reference of word - can then be linked to xcl data
		$langsurro = $i->{att}->{'xml:lang'}?$i->{att}->{'xml:lang'}:"noLang";
		$form = $i->{att}->{"form"}?$i->{att}->{"form"}:""; 
    		my $tempvalue = '//l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
		
		my @wordref = $PQroot->get_xpath($tempvalue); 
		foreach my $item (@wordref) {
		    if ($item->{att}->{"cf"}) {
			if ($cf eq "") { $cf = $item->{att}->{"cf"}; }
			else { $cf = $cf." ".$item->{att}->{"cf"}; }
		    }
		    if ($item->{att}->{"gw"}) {
			if ($gw eq "") { $gw = $item->{att}->{"gw"}; }
			else { $gw = $gw." ".$item->{att}->{"gw"}; }
		    }
		}
	    }
	}
	#print "\nSurrolabel: ".$label;
	if ($type eq "punct") {
	    $cnt--;
	    while (($nonw[$cnt]) && ($cnt > -1)) {
		&savePunct($nonw[$cnt], $nonwBreak[$cnt], $nonwLang, $label, "ditto", $cf, $gw);
		$cnt--;
	    }
	}
	elsif ($type eq "word") {
	    my $wordtype = "dittoword";
	    my $writtenWord = ""; my $preservedSigns = 0; my $signs = ();
	    ($writtenWord, $signs) = &formWord(\@arrayNonWord);
	    my $damagedSigns = $signs->{'damaged'}; my $missingSigns = $signs->{'missing'}; 
	    #($writtenWord, $damagedSigns, $missingSigns) = &formWord(\@arrayNonWord);
	    
	    # info in @arrayNonWord
	    my $no_signs = scalar @arrayNonWord;
	    $preservedSigns = $no_signs - $damagedSigns - $missingSigns;
    
	    my $break = "damaged";
	    if ($no_signs == $preservedSigns) { $break = "preserved"; }
	    elsif ($no_signs == $missingSigns) { $break = "missing"; }
	    
	    #form = $writtenWord without [], halfbrackets
	    $form = $writtenWord; 
	    $form =~ s|\[||g; $form =~ s|\]||g; $form =~ s|\x{2E22}||g; $form =~ s|\x{2E23}||g;
	    &saveWord($nonwLang, $form, $break, $wordtype, "", "", "", $writtenWord, $label, "", "", "", $note, $writtenAs);
	    
	    my $count = 0; my $beginpos = 0; my $endpos = $no_signs - 1; my $severalParts = 0;
	    while ($count < $no_signs) {
		if (($arrayNonWord[$count]->{'delim'}) && ($arrayNonWord[$count]->{'delim'} eq "--")) {
		    $endpos = $count; $severalParts++;
		    &determinePosition($beginpos, $endpos, \@arrayNonWord);
		    $beginpos = $endpos+1; $endpos = $no_signs - 1;
		}
		$count++;
	    }
	    &determinePosition($beginpos, $endpos, \@arrayNonWord);
	    
	    foreach my $sign (@arrayNonWord) {
		my $category = "";
		if ($role eq "logo") { $category = "logogram"; }
		else { $category = $sign->{'tag'}?$sign->{'tag'}:"unknown"; }
		my $break = $sign->{'break'}; 
		my $value = $sign->{'value'}; my $pos = $sign->{'pos'}; my $position = $sign->{'position'};
		# can these actually have base and modifier ??? TODO - CHECK
		# I'm not including gw as translation is possibly nonsensical (especially when combination of words)
		&saveSign($nonwLang, $category, $value, "", "", "", "", $position, "", $break, $label, $form, $writtenWord, $wordtype, "", "");
	    }
	}
    }

    # gloss: P348219; P348635 (e.g. hi-pi2 (esh-shu2))
    my @glosses = $root->get_xpath('g:gloss');
    my $no_glosses = scalar @glosses;
    foreach my $g (@glosses) {
	$note = "gloss";
	$localdata = &getLineData($g, $label, $note);
	push(@{$linedata{'glosses'}}, $localdata);
	$localdata = {};
    }
    
    my @nonw = $root->get_xpath('g:nonw');
    my $no_nonw = scalar @nonw;
    foreach my $nw (@nonw) {
	my $type = $nw->{att}->{"type"}?$nw->{att}->{"type"}:"";
	if (($type ne "dollar") && ($type ne "punct") && ($type ne "excised"))
	    { &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": nonw of type ".$type."."); }
    
	# "comment" | "dollar" | "excised" | "punct" | "vari" - check still 'type="comment"' and 'vari' - keep checking *** 
	# dollar: P270855; P335915; P336778; P348045; P363582; P381761; Q003232
	# excised: P296713; P334914; P348219; P363419; P363524; P363582; P365126; Q001870; Q003232
	# comment: not in CAMS/GKAB - elsewhere?
	my $sign = "";
	my $lang = $nw->{att}->{"xml:lang"}?$nw->{att}->{"xml:lang"}:"noLang";
	
	if ($type eq "dollar") { # 'dollar' seems to stand for fireholes, erasures (and other strange things: (r) in Amarna - whatever that means)
	    $sign = $nw->text;
	    $localdata->{"type"} = $type;
	    $localdata->{"sign"} = $sign;
	    push (@{$linedata{'nonw'}}, $localdata);
	    # these fireholes and erasures are NOT saved under signs or words.
	    $localdata = {};
        }
	elsif ($type eq "punct") {
	    my @children = $nw->children(); 
	    foreach my $i (@children) {
	        my $tag = $i->tag;
	        if ($tag eq 'g:p') { # punctuation
		    $sign = $i->{att}->{"g:type"}?$i->{att}->{"g:type"}:"";
		    my $break = $i->{att}->{"g:break"}?$i->{att}->{"g:break"}:"preserved";
		    &savePunct($sign, $break, $lang, $label, "", "", ""); # these signs are saved under signs.
		}	
		elsif (($tag eq 'g:v') || ($tag eq 'g:s')) { # this does not yet occur - keep checking ***
		    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": nonw of type ".$type.", with tag ".$tag);
		    $sign = $i->text;
		    # these signs are NOT collected under signs or words.
		}
		$localdata->{"type"} = $type;
		$localdata->{"sign"} = $sign;
		push (@{$linedata{'nonw'}}, $localdata);
		$localdata = {};
	    }
	}
	elsif ($type eq "excised") { # graphemes are present but must be excised for the sense
	    my @children = $nw->children();  # can be g:c too, as in P363689; or g:w
	    my $position = 1; my $localdata = {}; my $cnt = 0; my $tempdata = {}; my @arrayWord = ();
	    foreach my $i (@children) {
	        my $tag = $i->tag;
		if ($tag eq 'g:p') { # punctuation - this does not yet occur - keep checking ***
		    $sign = $i->{att}->{"g:type"}?$i->{att}->{"g:type"}:"";
		    my $break = $i->{att}->{"g:break"}?$i->{att}->{"g:break"}:"preserved";
		    &savePunct($sign, $break, $lang, $label, "excised", "", ""); # these signs are saved under signs.
		    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": excised punctuation");
		    
		}
		else { # e.g. in P365126; P363582 [g:d and g:s]; P363419; Q001870; P296713 [g:v]; Q003232; P334914 [g:d, g:v]; P348219 [g:n]; P363524
		    ($tempdata, $position) = &splitWord (\@arrayWord, $i, $label, $position);
		    $sign = $arrayWord[$cnt]->{'value'};
		    $cnt++;
		}
		$localdata->{"type"} = $type;
		$localdata->{"sign"} = $sign;
		push (@{$linedata{'nonw'}}, $localdata);
		$localdata = {};
	    }
	    my $writtenWord = ""; 
	    my $preservedSigns = 0; #my $damagedSigns = 0; my $missingSigns = 0;
	    my $signs = ();
	    #($writtenWord, $damagedSigns, $missingSigns) = &formWord(\@arrayWord);
	    ($writtenWord, $signs) = &formWord(\@arrayWord);
	    my $damagedSigns = $signs->{'damaged'}; my $missingSigns = $signs->{'missing'}; 
	    my $no_signs = scalar @arrayWord;
	    $preservedSigns = $no_signs - $damagedSigns - $missingSigns;
    
	    # fill in worddata: number of preserved signs, etc.
	    my $break = "damaged"; my %worddata = ();
	    if ($no_signs == $preservedSigns) { $break = "preserved"; $worddata{"stateWord"} = "preserved"; }
	    elsif ($no_signs == $missingSigns) { $break = "missing"; $worddata{"stateWord"} = "missing"; }
	    else { $worddata{"stateWord"} = "damaged"; }
    
	    if ($preservedSigns > 0) { $worddata{"preservedSigns"} = $preservedSigns; }
	    if ($damagedSigns > 0) { $worddata{"damagedSigns"} = $damagedSigns; }
	    if ($missingSigns > 0) { $worddata{"missingSigns"} = $missingSigns; }

	    #form = $writtenWord without [], halfbrackets
	    my $form = $writtenWord; 
	    $form =~ s|\[||g; $form =~ s|\]||g; $form =~ s|\x{2E22}||g; $form =~ s|\x{2E23}||g;
	    
	    &saveWord($lang, $form, $break, "excisedWord", "", "", "", $writtenWord, $label, "", "", "", $note, $writtenAs);
	    
	    my $count = 0; my $beginpos = 0; my $endpos = $no_signs - 1; my $severalParts = 0;
	    while ($count < $no_signs) {
	        if (($arrayWord[$count]->{'delim'}) && ($arrayWord[$count]->{'delim'} eq "--")) {
	            $endpos = $count; $severalParts++;
	            &determinePosition($beginpos, $endpos, \@arrayWord);
	            $beginpos = $endpos+1; $endpos = $no_signs - 1;
	        }
	        $count++;
	    }
	    &determinePosition($beginpos, $endpos, \@arrayWord);
    
	    my %allWordData;
	    $allWordData{"word"}->{"written"} = $writtenWord; $allWordData{"word"}->{"cf"} = "";
	    $allWordData{"word"}->{"form"} = $form; $allWordData{"word"}->{"lang"} = $lang;
	    $allWordData{"word"}->{"no_signs"} = $no_signs; $allWordData{"word"}->{"label"} = $label;
	    $allWordData{"word"}->{"wordtype"} = "excisedWord"; $allWordData{"word"}->{"wordbase"} = "";
	    $allWordData{"word"}->{"gw"} = "";
        
	    &saveSigns(\%allWordData, \@arrayWord);
	}
	else { # this does not yet occur - keep checking ***
	    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": nonw of type ".$type." check procedure"); 
	    my @children = $nw->children();  # can be g:c too, as in P363689; or g:w
	    foreach my $i (@children) {
	        my $tag = $i->tag;
	        if ($tag eq 'g:p') { # punctuation
		    $sign = $i->{att}->{"g:type"}?$i->{att}->{"g:type"}:"";
		    my $break = $i->{att}->{"g:break"}?$i->{att}->{"g:break"}:"preserved";
		    &savePunct($sign, $break, $lang, $label, "", "", ""); # these signs are saved under signs.
		}	
		else { # e.g. in excised
		    $sign = $i->text;
		    # these signs are NOT collected under signs or words.
		}
		$localdata->{"type"} = $type;
		$localdata->{"sign"} = $sign;
		push (@{$linedata{'nonw'}}, $localdata);
		$localdata = {};
	    }
	}
    }

    # Words: g:w; g:w sword.head; g:swc sword.cont; g:nonw; g:x
    # split words: (1st part) g:w headform; (2nd part) g:swc
    # find no_words, no_signs per line, no_nonwords; preserved, damaged, missing
    # plus track words, signs, etc.
    my @words = $root->get_xpath('g:w');
    my $preservedWords = 0; my $damagedWords = 0; my $missingWords = 0;
    my $preservedSigns = 0; my $damagedSigns = 0; my $missingSigns = 0;
    foreach my $word (@words) {
	my @children = $word->children(); my $no_children = scalar @children;
	my $tag = $children[0]->tag;
	if (($tag eq "g:x") && ($no_children == 1)) { # I don't want to count an ellipsis as 1 word [could be more or (even) less]
		if ($children[0]->{att}->{"g:type"}) { $localdata->{"kind"} = $children[0]->{att}->{"g:type"}; }
		if ($children[0]->{att}->{"g:break"}) { $localdata->{"break"} = $children[0]->{att}->{"g:break"}; }
		push (@{$linedata{'x'}}, $localdata);
	    }
	else  {
	    $linedata{'words'}++;
	    my $tempdata = {};
	    if ($word->{att}->{headform}) { # beginning of split word
		my $headref = $word->{att}->{"xml:id"};
		$tempdata = &analyseWord($word, $label, $note, "splithead");
		$linedata{"split"}++;
		push (@splitrefs, $headref);
	    }
	    elsif ($word->{att}->{"form"} ne "o"){ # words with form="o" are not words at all and shouldn't be considered (e.g. SAA 1 10 o 18 = P 334195)
		# normal words
		# analyse words - collect all sign information (position, kind, delim, state)
		#print "\nAnalyse ". $word->{att}->{"form"};
		$tempdata = &analyseWord($word, $label, $note);
	    }
	    if ($tempdata->{"stateWord"}) {
		if ($tempdata->{"stateWord"} eq "preserved") { $preservedWords++; }
		elsif ($tempdata->{"stateWord"} eq "damaged") { $damagedWords++; }
		elsif ($tempdata->{"stateWord"} eq "missing") { $missingWords++; }
	    }
	    if ($tempdata->{"preservedSigns"}) { $preservedSigns += $tempdata->{"preservedSigns"}; }
	    elsif ($tempdata->{"damagedSigns"}) { $damagedSigns += $tempdata->{"damagedSigns"}; }
	    elsif ($tempdata->{"missingSigns"}) { $missingSigns += $tempdata->{"missingSigns"}; }
	}
	$localdata = {};
    }
    
    my @splitends = $root->get_xpath('g:swc');
    my $no_split = scalar @splitends;
    if ($no_split > 0) {
	foreach my $split (@splitends) { # end of split word 
	    # if the beginning of this word is preserved, then this end will have been treated together with the beginning
	    # what happens here should only occur when only the end of the word is preserved (and the beginning is not reconstructed)
	    if (!($split->{att}->{"headref"})) {
		my $tempdata = {};
		$tempdata = &analyseWord($split, $label, $note, "splitend"); 
		$linedata{"split"}++;
		$linedata{'words'}++;
		if ($tempdata->{"stateWord"} eq "preserved") { $preservedWords++; }
		elsif ($tempdata->{"stateWord"} eq "damaged") { $damagedWords++; }
	        elsif ($tempdata->{"stateWord"} eq "missing") { $missingWords++; }
	        if ($tempdata->{"preservedSigns"}) { $preservedSigns += $tempdata->{"preservedSigns"}; }
	        elsif ($tempdata->{"damagedSigns"}) { $damagedSigns += $tempdata->{"damagedSigns"}; }
	        elsif ($tempdata->{"missingSigns"}) { $missingSigns += $tempdata->{"missingSigns"}; }
	    }
	    #else { print "found ".$split->{att}->{"headref"}; }
	}
    }
    
    if ($preservedWords > 0) { $linedata{'words_preserved'} = $preservedWords; }
    if ($damagedWords > 0) { $linedata{'words_damaged'} = $damagedWords; }
    if ($missingWords > 0) { $linedata{'words_missing'} = $missingWords; }
    if ($preservedSigns > 0) { $linedata{'signs_preserved'} = $preservedSigns; }
    if ($damagedSigns > 0) { $linedata{'signs_damaged'} = $damagedSigns; }
    if ($missingSigns > 0) { $linedata{'signs_missing'} = $missingSigns; }
    $linedata{'signs'} = $preservedSigns + $damagedSigns + $missingSigns;
    
    my @xes = $root->get_xpath('g:x');
    foreach my $x (@xes) {
	my $type = $x->{att}->{"g:type"};
	$localdata->{"kind"} = $type; 	# 'g:type="disambig"' |"user" | "word-absent" | "word-broken" | "word-linecont" | "empty" ??
	if (($type ne "newline") && ($type ne "ellipsis")) { # - keep checking *** not in test corpus
	    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.", ".$label.": x of type ".$type);
	}
	# OK for "newline" | "ellipsis" | 
	#empty: (only in note, so useless Q003232)
	#newline: P365126, P338366, P296713
	if ($x->{att}->{"g:break"}) { $localdata->{"break"} = $x->{att}->{"g:break"}; }
	push (@{$linedata{'x'}}, $localdata);
	$localdata = {};
    }
    
    return \%linedata;
}

sub savePunct { 
    my $sign = shift;
    my $break = shift;
    my $lang = shift;
    my $label = shift;
    my $ditto = shift | ""; # ditto or excised?
    my $cf = shift | "";
    my $gw = shift | "";
    my $category = "punct";
    
    $PQdata{"02_Signs"}{'total'}++; # total number of signs
    $PQdata{"02_Signs"}{"ztotal_state"}{$break}{'total'}++;
    $PQdata{"02_Signs"}{$lang}{'total'}++; # total number of signs per language
    $PQdata{"02_Signs"}{$lang}{"zlang_total_state"}{$break}{'total'}++;
    $PQdata{"02_Signs"}{$lang}{"category"}{$category}{'total'}++; # total number of signs per language and category
    $PQdata{"02_Signs"}{$lang}{"category"}{$category}{"state"}{$break}{'total'}++;
    if ($ditto eq "") {
	push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"value"}{$sign}{"state"}{$break}{"line"}}, $label);
	}
    else { # as gw can be a bit nonsensical (esp. if existing of several words), I'm not yet including it. Don't yet know if there's any need. Maybe check again later ***
	push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"value"}{$sign}{$ditto}{$cf}{"state"}{$break}{"line"}}, $label);
    }
}

sub checkPQdataStructure{
    my $no_surfaces = 0; my $no_columns = 0; 
    if ($PQdata{"01_Structure"}[0]{"no_surfaces"}) {
	$no_surfaces = $PQdata{"01_Structure"}[0]{"no_surfaces"};
	my $cnt = 0; my $no_lines_surface = 0;
	while ($cnt < $no_surfaces) {
	    if ($PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"no_columns"}) {
		$no_columns = $PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"no_columns"};
		my $cnt2 = 0; my $no_lines = 0;
		while ($cnt2 < $no_columns) {
		    if ($PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"column"}[$cnt2]{"no_lines"}) {
			$no_lines += $PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"column"}[$cnt2]{"no_lines"};
		    }
		    $cnt2++;
		}
		$PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"no_lines"} = $no_lines;
		$no_lines_surface += $no_lines;
	    }
	    $cnt++;
	    $PQdata{"01_Structure"}[0]{"no_lines"} = $no_lines_surface;
	}
    }
    
    my $no_divs = 0;
    if ($PQdata{"01_Structure"}[0]{"no_divs"}) {
	$no_divs = $PQdata{"01_Structure"}[0]{"no_divs"};
	my $cnt = 0; my $no_lines_div = 0;
	while ($cnt < $no_divs) {
	    if ($PQdata{"01_Structure"}[0]{"div"}[$cnt]{"no_lines"}) {
		$no_lines_div += $PQdata{"01_Structure"}[0]{"div"}[$cnt]{"no_lines"}
	    }
	    $cnt++;
	}
	if ($PQdata{"01_Structure"}[0]{"no_lines"}) {
	    $PQdata{"01_Structure"}[0]{"no_lines"} += $no_lines_div;
	}
	else {
	    $PQdata{"01_Structure"}[0]{"no_lines"} = $no_lines_div;
	}
    }
}

sub formWord{
    my @arrayWord = @{$_[0]};;
    
    my $writtenWord = "";
    my $signs = ();
    $signs->{'preserved'} = scalar @arrayWord;
    $signs->{'missing'} = 0; $signs->{'damaged'} = 0;
    $signs->{'maybe'} = 0; $signs->{'implied'} = 0; $signs->{'supplied'} = 0; $signs->{'erased'} = 0; $signs->{'excised'} = 0;
    my $lastdelim = ""; my $lastend = "";
    
    # g:status: "ok" - g:o and g:c 
    # "maybe": (...) # in breaks
    # "excised": <<...>> : &lt;&lt;    &gt;&gt; # superfluous sign on tablet
    # "supplied": <...> # forgotten by the scribe, not on tablet
    # "erased": <{...}>
    # "implied": <(...)> #  graphemes are implied because the scribe has left a blank space on the tablet. Right, this means that there's actually nothing on the tablet, just blank space. Ignore?
    
    #my $open = ""; my $closed = "";
    
    my $noSign = 0; my $previousStatus = "ok";
    my $previousClosedSym = "";
    #my $print = "no";
    my $no_elements = scalar @arrayWord;
    
    foreach(@arrayWord){
	my $thing = $_;
	my $status = $thing->{'status'}?$thing->{'status'}:""; 
	
	my $openSym = ""; my $closedSym = ""; 
	if ($status ne "ok") {
	    #$print = "yes";
	    #&writetoerror ("Words", "Project: ".$thisCorpus.", text ".$thisText.": status: ".$status);
	    if ($status eq "maybe") { $signs->{'maybe'}++; $openSym = "("; $closedSym = ")"; }
	    elsif ($status eq "implied") { $signs->{'implied'}++; $openSym = "&lt;("; $closedSym = ")&gt;"; }
	    elsif ($status eq "supplied") { $signs->{'supplied'}++; $openSym = "&lt;"; $closedSym = "&gt;"; }
	    elsif ($status eq "erased") { $signs->{'erased'}++; $openSym = "&lt;{"; $closedSym = "}&gt;"; }
	    elsif ($status eq "excised") { $signs->{'excised'}++; $openSym = "&lt;&lt;"; $closedSym = "&gt;&gt;"; }
	}
	
	my $startbit = ""; my $endbit = "";
	my $value = $thing->{'value'};
	if ($value eq "") { $noSign++; } # signs with no value shouldn't be counted (are probably newlines!!!) 
	
	if ($thing->{"type"} && ( $thing->{"type"} eq "semantic" || $thing->{"type"} eq "phonetic")) { # determinatives and phonetic complements get {}
	    $value = "{".$value."}";
	}
	
	if (($previousStatus eq "ok") && ($status eq "ok")) {
	    # nothing needs to happen
	}
	elsif (($previousStatus eq "ok") && ($status ne "ok")) {
	    # we need openSym before word
	    $value = $openSym.$value;
	}
	
	if($thing->{"break"} && $thing->{"break"} eq "missing"){ # value gets []
	    if ($lastend ne "]") { $startbit = "[" ; }
	    else { $lastend = ""; }
	    $endbit = "]";
	    $signs->{'missing'}++;
	}
	elsif ($thing->{"break"} && $thing->{"break"} eq "damaged"){ # value gets half[]
	    if ($lastend ne "\x{2E23}") { $startbit = "\x{2E22}" ; }
	    else { $lastend = ""; }
	    $endbit = "\x{2E23}";
	    $signs->{'damaged'}++;
	}
	
	if (($previousStatus ne "ok") && ($status eq "ok")) {
	    # we need to close before next sign with $previousClosedSym, adding $lastend before that
	    $lastend = $previousClosedSym.$lastend;
	}
	elsif (($previousStatus ne "ok") && ($status ne "ok")) {
	    # same or different status?
	    if ($previousStatus eq $status) {
		# nothing happens [maybe not true: how about break?] # TODO: check again with other examples
	    }
	    else {
		# close first bit; and next value will need opening after delim if not ok
		$lastend = $previousClosedSym.$lastend;
		$lastdelim .= $openSym;
	    }
	}
	
	
	my $delim = "";
	if ($thing->{"delim"}) { $delim = $thing->{"delim"}; }
	$writtenWord .= $lastend.$lastdelim.$startbit.$value;
	$lastend = $endbit;
	$lastdelim = $delim;
	$previousClosedSym = $closedSym;
	$previousStatus = $status;
    }
    
    # always correct? OK for all my examples so far. # TODO check again
    if ($no_elements > 1) { $writtenWord .= $lastend.$previousClosedSym.$lastdelim; }
    else { $writtenWord .= $previousClosedSym.$lastend.$lastdelim; }
    
    
    $signs->{'preserved'} = $signs->{'preserved'} - $signs->{'missing'} - $signs->{'damaged'};
    
    #if ($print eq "yes") { &writetoerror ("Words", "Project: ".$thisCorpus.", text ".$thisText.": word: ".$writtenWord); }
    return ($writtenWord, $signs);
}

sub analyseWord{
    my $word = shift;
    my $label = shift;
    my $note = shift;
    my $split = shift || "";
    my %worddata = ();
    
# return data as number of words, number of signs etc.
# save data as words, signs, etc. in PQdata{"words"} and PQdata{"signs"}
    my $lang = $word->{att}->{'xml:lang'}?$word->{att}->{'xml:lang'}:"noLang";
    my $form = $word->{att}->{"form"}?$word->{att}->{"form"}:""; 
    my $wordid = $word->{att}->{"xml:id"}?$word->{att}->{"xml:id"}:"";
    my $tempvalue = '//l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
    my $cf = ""; my $pofs = ""; my $epos = ""; my $wordbase = ""; my $gw = "";
            
    # xtf-file
    #print "\n".$tempvalue."\n";
    my @wordref = $PQroot->get_xpath($tempvalue); 
    foreach my $item (@wordref) {
        $cf = $item->{att}->{"cf"}?$item->{att}->{"cf"}:"";
        $pofs = $item->{att}->{"pos"}?$item->{att}->{"pos"}:""; # pofs = part-of-speech (pos is used already for position)
        $epos = $item->{att}->{"epos"}?$item->{att}->{"epos"}:"";
	$gw = $item->{att}->{"gw"}?$item->{att}->{"gw"}:"";
	$wordbase = $item->{att}->{"base"}?$item->{att}->{"base"}:"";
    }
    
    my $wordtype = $pofs;
    # PERSONAL and ROYAL NAMES
    if (($wordtype eq "RN") || ($wordtype eq "PN")) { $wordtype = "PersonalNames"; } 
    
    # http://oracc.museum.upenn.edu/doc/builder/linganno/QPN/
    # GEOGRAPHICAL DATA: GN, WATERCOURSE, ETHNIC (GENTILICS), AGRICULTURAL, FIELD, QUARTER, SETTLEMENT, LINE, TEMPLE 
    if (($wordtype eq "GN") || ($wordtype eq "WN") || ($wordtype eq "EN") || ($wordtype eq "AN") || ($wordtype eq "FN") || ($wordtype eq "QN") || ($wordtype eq "SN") || ($wordtype eq "LN") || ($wordtype eq "TN")) {
	$wordtype = "Geography";
    }
    
    # DIVINE and CELESTIAL NAMES
    if (($wordtype eq "DN") || ($wordtype eq "CN")) {
	$wordtype = "DivineCelestial"; 
    }
    
    # ROUGH CLASSIFICATION IF NOT LEMMATIZED
    if (($wordtype eq "") && ($form ne "")) { 
	my $formsmall = lc ($form);
	if ($formsmall =~ /(^\{1\})|(^\{m\})|(^\{f\})/) { $wordtype = "PersonalNames"; }
	if (($formsmall =~ /(^\{d\})/) || ($formsmall =~ /(^\{mul\})/) || ($formsmall =~ /(^\{mul\x{2082}\})/)) { $wordtype = "DivineCelestial"; }  
	if (($formsmall =~ /(\{ki\})/) || ($formsmall =~ /(\{kur\})/) || ($formsmall =~ /(\{uru\})/) || ($formsmall =~ /(\{iri\})/) || ($formsmall =~ /(\{id\x{2082}\})/))  { $wordtype = "Geography"; }
	if ($formsmall =~ /^\d/) { $wordtype = "Numerical"; }
    }    

    if (($wordtype ne "PersonalNames") && ($wordtype ne "DivineCelestial") && ($wordtype ne "Geography") && ($wordtype ne "Numerical")) {
	if ($form =~ /^\$/) { $wordtype = "UncertainReading"; }
	else { $wordtype = "OtherWords"; }
    }
    
#Split: d
#Split: AMARUTU
#$VAR1 = {
#          'value' => 'd',
#          'type' => 'semantic',
#          'tag' => 'g:v',
#          'pos' => 1,
#          'prePost' => 'pre',
#          'break' => 'damaged'
#        };
#$VAR2 = {
#          'group' => 'logo',
#          'value' => 'AMAR',
#          'tag' => 'g:s',
#          'pos' => 2,
#          'delim' => '.',
#          'break' => 'damaged'
#        };
#$VAR3 = {
#          'group' => 'logo',
#          'value' => 'UTU',
#          'tag' => 'g:s',
#          'pos' => 3,
#          'break' => 'damaged'
#        };
    
    my @arrayWord = ();
    
    my @children = $word->children();
 
    my $no_children = scalar @children;
    my $position = 1; my $localdata = {}; my $cnt = 0; my $tempdata = {};
    foreach my $i (@children) { # check each element of a word
	($tempdata, $position) = &splitWord (\@arrayWord, $i, $label, $position);
	$cnt++;
    }
    
    if ($split eq "splithead") {
	my $ref = $word->{att}->{"xml:id"};
	# look for splitend
	my $tempvalue = '//g:swc[@headref="'.$ref.'"]'; 
	my @splitenz = $PQroot->findnodes($tempvalue); 
	if (@splitenz) {
	    my $lastSoFar = scalar @arrayWord;
	    $arrayWord[$lastSoFar - 1]->{"split"} = "split";
	    my @endchildren = $splitenz[0]->children();
	    $localdata = {}; $cnt = 0;
	    foreach my $j (@endchildren) { 
	        ($tempdata, $position) = &splitWord (\@arrayWord, $j, $label, $position);
	        $cnt++;
	    }
	    # add extra line number; find parent of swc
	    my $parent = $splitenz[0]->parent();
	    if ($parent->{att}->{"label"}) { my $extraLabel = $parent->{att}->{"label"}; $label .= "-".$extraLabel; }
	}
	#print Dumper @arrayWord;
    }
    
    my $writtenWord = ""; 
    my $preservedSigns = 0; #my $damagedSigns = 0; my $missingSigns = 0;
    my $signs = ();
    ($writtenWord, $signs) = &formWord(\@arrayWord);
    my $damagedSigns = $signs->{'damaged'}; my $missingSigns = $signs->{'missing'};
    #($writtenWord, $damagedSigns, $missingSigns) = &formWord(\@arrayWord);
    my $no_signs = scalar @arrayWord;
    $preservedSigns = $no_signs - $damagedSigns - $missingSigns;
    
    # fill in worddata: number of preserved signs, etc.
    my $break = "damaged";
    if ($no_signs == $preservedSigns) { $break = "preserved"; $worddata{"stateWord"} = "preserved"; }
    elsif ($no_signs == $missingSigns) { $break = "missing"; $worddata{"stateWord"} = "missing"; }
    else { $worddata{"stateWord"} = "damaged"; }
    
    if ($preservedSigns > 0) { $worddata{"preservedSigns"} = $preservedSigns; }
    if ($damagedSigns > 0) { $worddata{"damagedSigns"} = $damagedSigns; }
    if ($missingSigns > 0) { $worddata{"missingSigns"} = $missingSigns; }

    my $writtenAs = "";
    foreach my $i (@arrayWord) {
	if ($i->{'group'}) {
	    $note = $i->{'group'};
	    if ($note eq "correction") {
		#$writtenAs = $writtenWord without brackets
		$writtenAs = $writtenWord; 
		$writtenAs =~ s|\[||g; $writtenAs =~ s|\]||g; $writtenAs =~ s|\x{2E22}||g; $writtenAs =~ s|\x{2E23}||g;
	    }
	}
	if ($i->{'newline'}) {
	    $note = "newline";
	}
    }

    &saveWord($lang, $form, $break, $wordtype, $cf, $pofs, $epos, $writtenWord, $label, $split, $wordbase, $gw, $note, $writtenAs);

    # words that comprise several parts should be treated as such e.g. KUR--MAR.TU{ki} and personal names
    
    my $count = 0; my $beginpos = 0; my $endpos = $no_signs - 1; my $severalParts = 0;
    while ($count < $no_signs) {
	if (($arrayWord[$count]->{'delim'}) && ($arrayWord[$count]->{'delim'} eq "--")) {
	    $endpos = $count; $severalParts++;
	    &determinePosition($beginpos, $endpos, \@arrayWord);
	    $beginpos = $endpos+1; $endpos = $no_signs - 1;
	}
	$count++;
    }
    &determinePosition($beginpos, $endpos, \@arrayWord);
    
    my %allWordData;
    $allWordData{"word"}->{"written"} = $writtenWord; $allWordData{"word"}->{"cf"} = $cf;
    $allWordData{"word"}->{"form"} = $form; $allWordData{"word"}->{"lang"} = $lang;
    $allWordData{"word"}->{"no_signs"} = $no_signs; $allWordData{"word"}->{"label"} = $label;
    $allWordData{"word"}->{"wordtype"} = $wordtype; $allWordData{"word"}->{"wordbase"} = $wordbase;
    $allWordData{"word"}->{"gw"} = $gw;
    #$allWordData{"signs"} = \@arrayWord; 
    
    #push (@{$localdata->{"word"}}, \%allWordData);
#    if ($wordtype ne "OtherWords") {
#	print "\n\nArrayWord";
#	print Dumper (@arrayWord);
#    }
#    
    &saveSigns(\%allWordData, \@arrayWord);
    
    # make temporary array of each word including information about determinative [det]/phonetic [phon], syllabic [syll], logographic [logo], logographic suffixes [logosuff]

    return \%worddata;
}

sub splitWord {
    my $splitdata = shift;
    my $root = shift;
    my $label = shift;
    my $position = shift;
    my $type = shift || "";
    my $prepost = shift || "";
    my $break = shift || "preserved";
    my $delim = shift || "";
    my $group = shift || "";
    my $for = shift || "";
    my $status = shift || "";
    
    my $localdata = {};
    my $tag = $root->tag;
    
    my $value = "";
    my $base = ""; my $allo = ""; my $formvar = ""; my $modif = ""; 
    my $newline = "";
    my $open = ""; my $closed = "";
    # http://oracc.museum.upenn.edu/ns/gdl/1.0/grapheme.rnc.html
    
    # Single elements: g:x (missing), g:n (number), g:v (small letters), g:s (capital)
    if (($tag eq "g:x") || ($tag eq "g:n") || ($tag eq "g:v") || ($tag eq "g:s")) {
	$localdata = {};
	
	if ($tag eq "g:x") {
	    $newline = $root->{att}->{'g:type'};
	}
	$value = $root->{att}->{form}?$root->{att}->{form}:"";
	my @bases = $root->get_xpath("g:b");
	$base = $bases[0]?$bases[0]->text:"";
	# variants with g:a (allograph), g:f (formvar) or g:m (modifier) ??? TODO
	# see http://oracc.museum.upenn.edu/ns/gdl/1.0/#schemawords
	my @allos = $root->get_xpath("g:a");
	$allo = $allos[0]?$allos[0]->text:"";
	my @formvars = $root->get_xpath("g:f");
	$formvar = $formvars[0]?$formvars[0]->text:"";
	my @mods = $root->get_xpath("g:m");
	$modif = $mods[0]?$mods[0]->text:"";
	
	if (($value eq "") && ($root->text)) { $value = $root->text; }
	if ($status eq "") {
	    $status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:"";
	    #if ($status ne "ok") { &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": sign status ".$status." value ".$value); }
	    }
	if ($status ne "ok") {
	    $open = $root->{att}->{'g:o'}?$root->{att}->{'g:o'}:"";
	    $closed = $root->{att}->{'g:c'}?$root->{att}->{'g:c'}:"";
	}

	if ($root->{att}->{"g:delim"}) { $delim = $root->{att}->{"g:delim"}; }
	if ($root->{att}->{"g:break"}) { $break = $root->{att}->{"g:break"}; }
	
	# g:break = missing or damaged (otherwise not present)
	# g:status = ok, excised, supplied, maybe, implied, erased -> ok, excised and erased are present on the tablet; maybe may be too. 
	# supplied are, however, forgotten signs; and implied is blank space.
	# SO: state = preserved (ok, excised), damaged, missing (incl. maybe, supplied and implied?), erased
	
	$localdata->{"pos"} = $position; $localdata->{"tag"} = $tag; $localdata->{"value"} = $value; $localdata->{"break"} = $break;
	if ($base ne "") { $localdata->{"base"} = $base; }
	if ($allo ne "") { $localdata->{"allograph"} = $allo; }
	if ($formvar ne "") { $localdata->{"formvar"} = $formvar; }
	if ($modif ne "") { $localdata->{"modifier"} = $modif; }
	if ($prepost ne "") { $localdata->{"prePost"} = $prepost; }
	if ($type ne "") { $localdata->{"type"} = $type; }
	if ($delim ne "") { $localdata->{"delim"} = $delim; }
	if ($group ne "") { $localdata->{"group"} = $group; }
	if ($for ne "") { $localdata->{"for"} = $for; }
	if ($status ne "") { $localdata->{"status"} = $status; }
	if ($newline eq "newline") { $localdata->{"newline"} = $newline; }
	if ($open ne "") { $localdata->{"open"} = $open; }
	if ($closed ne "") { $localdata->{"closed"} = $closed; }

	push(@{$splitdata},$localdata);
	$position++;
	return ($splitdata, $position);
    }

    # Determinatives and phonetic complements: g:d with g:role and g:pos
    if ($tag eq "g:d") {
	$status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; 
	my @det_elements = $root->children();
	$type = $root->{att}->{"g:role"};
	$prepost = $root->{att}->{"g:pos"};
	$delim = $root->{att}->{"g:delim"};
	my @temp = ();
	foreach my $j (@det_elements) {
	    ($splitdata, $position) = &splitWord($splitdata, $j, $label, $position, $type, $prepost, "", $delim, $group, $for, $status);
	}
    }
    
    # Compounds: g:c { form? , g.meta , c.model , mods* }
    # and: g:g { g.meta , c.model , mods* }
    # -> n | s | c | (g,mods*) | q
    #	    <g:c form="|BAD?DI?@t|" xml:id="Q000003.12.2.0" g:status="ok">
#                <g:s>BAD</g:s>
#                <g:o g:type="containing"/> 
#                <g:s form="DI?@t">
#                    <g:b>DI?</g:b>
#                    <g:m>t</g:m>
#                </g:s>
#            </g:c>

#	    <g:c form="|EN.PAP.IGI@g.NUN.ME.EZEN?KASKAL|">
#                    <g:s>EN</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>PAP</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s form="IGI@g">
#                        <g:b>IGI</g:b>
#                        <g:m>g</g:m>
#                    </g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>NUN</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>ME</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>EZEN</g:s>
#                    <g:o g:type="containing"/>
#                    <g:s>KASKAL</g:s>
#                </g:c>

#	g:g ??   
#	    <g:c form="|(SAL.TUG..).PAP.IGI@g.ME.EZEN?KASKAL|">
#                    <g:g>
#                        <g:s>SAL</g:s>
#                        <g:o g:type="beside"/>
#                        <g:s g:accented="T?G">TUG..</g:s>
#                    </g:g>
#                    <g:o g:type="beside"/>
#                    <g:s>PAP</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s form="IGI@g">
#                        <g:b>IGI</g:b>
#                        <g:m>g</g:m>
#                    </g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>ME</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>EZEN</g:s>
#                    <g:o g:type="containing"/>
#                    <g:s>KASKAL</g:s>
#                </g:c>
	    
#	    <g:c form="|MU?&amp;KAK&amp;MU?|" xml:id="Q000003.121.1.0" g:status="ok">
#                    <g:s>MU?</g:s>
#                    <g:o g:type="above"/>
#                    <g:s>KAK</g:s>
#                    <g:o g:type="above"/>
#                    <g:s>MU?</g:s>
#                </g:c>

    if (($tag eq "g:c") || ($tag eq "g:g")) {
	my @c_elements = $root->children();
	my $c_delim = $root->{att}->{"g:delim"}?$root->{att}->{"g:delim"}:""; 
	$break = $root->{att}->{"g:break"}?$root->{att}->{"g:break"}:"";
	if ($status eq "") { $status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; }

	my $cnt = 0; my $no_els = scalar @c_elements;
	foreach my $c (@c_elements) { 
	    if ($c->tag eq "g:o") {
		my $punct = "";
		my $type = $c->{att}->{"g:type"};
		if ($type eq "beside") { $punct = "."; }
		elsif ($type eq "containing") { $punct = "x"; } # should elements with containing have the same position?? ***
		elsif ($type eq "above") { $punct = "&amp;"; }  # other types = joining, reordered, crossing, opposing; how marked ??
		# add info to previous element
		my $lastone = scalar @{$splitdata};
		$splitdata->[$lastone - 1]->{"delim"} = $punct;
		$splitdata->[$lastone - 1]->{"combo"} = $type;
		}
	    else {
		($splitdata, $position) = &splitWord($splitdata, $c, $label, $position, "", "", $break, $delim, $group, $for, $status);
	    }
	    $cnt++;
	    if ($cnt == $no_els) {
		if ($c_delim ne "") {
		    my $lastone = scalar @{$splitdata};
		    $splitdata->[$lastone - 1]->{"delim"} = $c_delim;
		}
	    }
	}
	&listCombos($root, $label);
    }
    
    # Qualified graphemes: g:q { form? , g.meta , (v|s|c) , (s|c|n) }
    # 2 parts: interpretation and sign combination
    # g:q -> take $value = form ["NERGALx(|U.GUR|)"]; $type = type of first element [g:s]
	    # <g:q form="NERGALx(|U.GUR|)" xml:id="P363524.30.1.1" g:status="ok"> # unicode lower x
              #  <g:s>NERGALx</g:s>
              #  <g:c form="|U.GUR|">
              #    <g:s>U</g:s>
              #    <g:o g:type="beside"/>
              #    <g:s>GUR</g:s>
              #  </g:c>
              #</g:q>
    if ($tag eq "g:q") {
	$status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; 
        my $firstpart = $root->getFirstChild();
	if ($firstpart->{att}->{"g:delim"}) { $delim = $firstpart->{att}->{"g:delim"}; }
	if ($firstpart->{att}->{"g:break"}) { $break = $firstpart->{att}->{"g:break"}; }
	($splitdata, $position) = &splitWord($splitdata, $firstpart, $label, $position, "", "", $break, $delim, $group, $for, $status);
	
	my $secondpart = $firstpart->getNextSibling();
	&listCombos($root, $label);
    }
    
    # Groups: g:gg
    # http://oracc.museum.upenn.edu/ns/gdl/1.0/words.rnc.html
#    group = element g:gg {
#			attribute g:type { 
#					"correction" | "alternation" | "group" | "reordering" | "ligature" | "implicit-ligature" | "logo" | "numword"
#			} ,
#	    g.meta , (group | grapheme)+   }

# g:gg -> all elements matter; type of gg may matter 
#	    <g:gg g:type="correction" g:status="ok" g:hc="1">
#              <g:v g:accented="?" g:utf8=" xml:id="P338566.6.2.0" g:break="damaged" g:remarked="1" g:ho="1">u...</g:v>
#              <g:c form="|DI.LU|" g:utf8="">
#                <g:s>DI</g:s>
#                <g:o g:type="beside"/>
#                <g:s>LU</g:s>
#              </g:c>
#            </g:gg>

#	    <g:gg g:type="reordering">
#                <g:v xml:id="Q000003.13.1.0" g:status="ok" g:delim=":">en</g:v>
#                <g:s xml:id="Q000003.13.1.1" g:status="ok">IB</g:s>
#            </g:gg>

#	    <g:gg g:type="logo">
#              <g:s xml:id="P338566.6.4.0" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">IGI</g:s>
#              <g:s xml:id="P338566.6.4.1" g:status="ok" g:role="logo" g:logolang="sux">IGI</g:s>
#              <g:d g:role="phonetic" g:pos="post">
#                <g:v g:utf8="" xml:id="P338566.6.4.2" g:status="ok">mar</g:v>
#              </g:d>
#            </g:gg>

#	gg within gg!
#	    <g:gg g:type="logo">
#                <g:s g:accented="..." xml:id="P363524.24.4.0" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">E...</g:s>
#                <g:s xml:id="P363524.24.4.1" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">I</g:s>
#                <g:s g:accented="..." xml:id="P363524.24.4.2" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">BI...</g:s>
#                <g:d g:role="semantic" g:pos="pre">
#                  <g:v xml:id="P363524.24.4.3" g:status="ok">d</g:v>
#                </g:d>
#                <g:gg g:type="correction" g:status="ok">
#                  <g:c form="|A.NUM|" xml:id="P363524.24.4.4" g:remarked="1" g:role="logo" g:logolang="sux">
#                    <g:s>A</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>NUM</g:s>
#                  </g:c>
#                  <g:s>RU</g:s>
#                </g:gg>
#              </g:gg>

    if ($tag eq "g:gg") { # "correction" | "alternation" | "group" | "reordering" | "ligature" | "implicit-ligature" | "logo" | "numword" 
	# ligature: P336601; P313917; P313837; P335915 # strange ligatures - only x+x # 
	# logo: P336601; P348706; P313917; P365126; P335915
	# correction: P348706; P365126; P363582
	# reordering: P335915; Q000003
	
	$status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; 
	my @gg_elements = $root->children();
	$group = $root->{att}->{"g:type"};
	
	if (($group ne "logo") && ($group ne "correction") && ($group ne "reordering") && ($group ne "ligature")) {
	    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": g:gg of type ".$group); # - keep checking ***
	}
	
	if ($root->{att}->{"g:delim"}) { $delim = $root->{att}->{"g:delim"}; }
	if ($root->{att}->{"g:break"}) { $break = $root->{att}->{"g:break"}; }
	my @temp = ();
	if ($group eq "correction") { # only second(!) element matters 
	    # e.g. written RI instead of rum
	    #	<g:gg g:type="correction" g:status="ok">
            #		<g:v xml:id="P365126.5.1.2" g:remarked="1">rum</g:v>
            #    	<g:s>RI</g:s>
            #	</g:gg>
	    
#	<g:w xml:id="P365126.48.4" xml:lang="akk-x-oldbab" form="UNUG{ki}">
#		<g:gg g:type="correction" g:status="ok">
#			<g:s xml:id="P365126.48.4.0" g:remarked="1" g:role="logo" g:logolang="sux">UNUG</g:s>
#			<g:c form="|TAB.BA|">
#				<g:s>TAB</g:s>
#				<g:o g:type="beside" />
#				<g:s>BA</g:s>
#			</g:c>
#		</g:gg>
#		<g:d g:role="semantic" g:pos="post">
#			<g:v xml:id="P365126.48.4.1" g:status="ok">ki</g:v>
#		</g:d>
#	</g:w>
	    my $gg1 = $root->getFirstChild(); # corrected reading
	    $for = $gg1->text;
	    my $gg2 = $gg1->getNextSibling(); # written sign
	    ($splitdata, $position) = &splitWord($splitdata, $gg2, $label, $position, "", "", $break, $delim, $group, $for, $status);
	}
	elsif (($group eq "logo") || ($group eq "reordering")) {
	    $for = "";
	    foreach my $gg (@gg_elements) {
	        ($splitdata, $position) = &splitWord($splitdata, $gg, $label, $position, "", "", $break, $delim, $group, $for, $status);
	    }
	}
	elsif ($group eq "ligature") { # this may be OK, but check with more normal ligatures...
	    $for = "";
	    foreach my $gg (@gg_elements) {
	        ($splitdata, $position) = &splitWord($splitdata, $gg, $label, $position, "", "", $break, $delim, $group, $for, $status);
	    }
	}
	else { # some uncovered situation?
	    &writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": group of type ".$group); # - keep checking ***
	}
	&listCombos($root, $label);
    }
    
    return ($splitdata, $position);
}
   

sub determinePosition { # seems to work with words with 2 determinatives in a row; what about several phonetic complements (a word longer than 1 sign) *** TODO check (not in my examples so far)
    my $beginpos = shift;
    my $endpos = shift;
    my @arrayWord = @{$_[0]};
    
    my $cnt = $beginpos; my $no_signs = $endpos - $beginpos + 1;
    my $no_pre = 0; my $no_post = 0;
    while ($cnt < $endpos + 1) {
	if ($arrayWord[$cnt]->{'prePost'}) {
	   if  ($arrayWord[$cnt]->{'prePost'} eq "pre") { $no_pre++; }
	   else { $no_post++; }
	}
	$cnt++;
    }
    
    $cnt = $beginpos;
    if (($no_pre == 0) && ($no_post == 0)) { # word without determinatives or phonetic complements
	while ($cnt < $endpos + 1) {
	    my $pos = $arrayWord[$cnt]->{'pos'}; 
	    if ($no_signs == 1) { $arrayWord[$cnt]->{'position'} = 'alone'; }
	    elsif ($pos == $beginpos + 1) { $arrayWord[$cnt]->{'position'} = 'initial'; }
	    elsif ($pos == $endpos + 1) { $arrayWord[$cnt]->{'position'} = 'final'; }
	    else { $arrayWord[$cnt]->{'position'} = 'medial'; }
	    $cnt++;
	}
    }
    elsif ($no_signs - $no_pre - $no_post == 1) { # only one sign with determinative(s) or phonetic complement(s)
	while ($cnt < $endpos + 1) {
	    $arrayWord[$cnt]->{'position'} = "alone";
	    $cnt++;
	}
    }
    else {
        $cnt = $beginpos; my $earlierPrePost = "";
        while ($cnt < $endpos + 1) {
	    my $pos = $arrayWord[$cnt]->{'pos'}; 
	    my $prePost = $arrayWord[$cnt]->{'prePost'}?$arrayWord[$cnt]->{'prePost'}:""; # pre or post-position
	    if (!($arrayWord[$cnt]->{'position'})) {
	        if ($pos == $beginpos + 1) { $arrayWord[$cnt]->{'position'} = 'initial'; }
	        elsif ($pos == $endpos + 1) { $arrayWord[$cnt]->{'position'} = 'final'; }
	        else { $arrayWord[$cnt]->{'position'} = 'medial'; }
	    }
	    if ($earlierPrePost eq "pre") { $arrayWord[$cnt]->{'position'} = $arrayWord[$cnt-1]->{'position'}; $earlierPrePost = ""; }
	    
	    if ($prePost) {
	        if ($prePost eq "pre") { $earlierPrePost = "pre"; } 
	        else { $arrayWord[$cnt-1]->{'position'} = $arrayWord[$cnt]->{'position'};
		}
	    }
	    $cnt++;
	}
    }
}

sub listCombos { # Chris: how can I get the root structure saved in combos ????
    my $root = shift;
    my $label = shift;
    my $realLabel = $thisCorpus.".".$thisText." ".$label;
    #push (@{$combos{"combo"}{$root}{"label"}}, $realLabel);
}

sub saveWord { 
    my $lang = shift;
    my $form = shift;
    my $break = shift;
    my $wordtype = shift;
    my $cf = shift;
    my $pofs = shift;
    my $epos = shift;
    my $writtenWord = shift;  
    my $label = shift;
    my $split = shift;
    my $wordbase = shift;  
    my $gw = shift; 
    my $note = shift || "";
    my $writtenAs = shift || "";
    
    if($lang eq "") { $lang = "noLang"; }
    if ($note eq "logo") { $note = ""; }
    
    my $totaltype = "total_".$wordtype;
    $PQdata{"03_Words"}{$lang}{$wordtype}{$totaltype}{'total'}++;
    $PQdata{"03_Words"}{$lang}{$wordtype}{$totaltype}{$break}{'num'}++;
    
    if ($form ne "") {
	$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'total'}++;
	if ($cf ne "") { $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'cf'} = $cf; }
	if ($gw ne "") { $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'gw'} = $gw; }
	if ($wordbase ne "") { $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'wordbase'} = $wordbase; }
	if ($pofs ne "") { $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'pofs'} = $pofs; }
	if ($epos ne "") { $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'epos'} = $epos; }
	if ($split ne "") {
	    #&writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.", ".$label.": split words.");
	    $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'splitWord'}++; } 
	if (($note ne "") && ($note ne "correction")) {
	    if ($note eq "gloss") { $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'num_gloss'}++; }
	    $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'note'}{$note}{'num'}++;
	    }
	
	if ($note eq "") {
	    &abstractWorddata(\%{$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}}, $break, $writtenWord, $label);
	}
	elsif (($note eq "correction") && ($writtenAs ne "")) {
	    &abstractWorddata(\%{$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'wronglyWrittenAs'}{$writtenAs}}, $break, $writtenWord, $label);
	}
	else { 
	    &abstractWorddata(\%{$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'note'}{$note}}, $break, $writtenWord, $label);
	}
    }
    $PQdata{"03_Words"}{'total'}++;
}

sub abstractWorddata{ 
    my $data = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $label = shift;
    
    if ($break eq "damaged") {
	$data->{'break'}{$break}{'writtenform'}{$writtenWord}{'num'}++;
	push (@{$data->{'break'}{$break}{'writtenform'}{$writtenWord}{'line'}}, $label);
    }
    else {
	push (@{$data->{'break'}{$break}{'line'}}, $label);
    }
    $data->{'break'}{$break}{'num'}++;
}

sub saveSigns { 
    my $allWordData = shift;
    my @arrayWord = @{$_[0]};

    my $writtenWord = $allWordData->{"word"}->{"written"}?$allWordData->{"word"}->{"written"}:"";
    my $cf = $allWordData->{"word"}->{"cf"}?$allWordData->{"word"}->{"cf"}:"";
    my $form = $allWordData->{"word"}->{"form"}?$allWordData->{"word"}->{"form"}:"";
    my $lang = $allWordData->{"word"}->{"lang"}?$allWordData->{"word"}->{"lang"}:"noLang";
    my $no_signs = $allWordData->{"word"}->{"no_signs"}?$allWordData->{"word"}->{"no_signs"}:0;
    my $label = $allWordData->{"word"}->{"label"}?$allWordData->{"word"}->{"label"}:"";
    my $wordtype = $allWordData->{"word"}->{"wordtype"}?$allWordData->{"word"}->{"wordtype"}:"";
    my $wordbase = $allWordData->{"word"}->{"wordbase"}?$allWordData->{"word"}->{"wordbase"}:"";
    
    my $gw = $allWordData->{"word"}->{"gw"}?$allWordData->{"word"}->{"gw"}:""; 
    my $category = "";
    
    if ($form =~ m|^\$|gsi) { $category = "uncertainReading"; }
    
    my $group = ""; my $for = "";
    # Greta: what happens to unclear readings? $BA etc.? not marked in SAAo - ask Mikko *** TODO
    # TODO: logographic suffixes ***
    foreach my $sign (@arrayWord) {
	if ($category eq "") { $category = $sign->{'tag'}?$sign->{'tag'}:"unknown"; }
	my $break = $sign->{'break'}; 
	my $value = $sign->{'value'}; my $pos = $sign->{'pos'}; my $position = $sign->{'position'};
	my $role = $sign->{'type'}?$sign->{'type'}:""; # semantic or phonetic
	my $prePost = $sign->{'prePost'}?$sign->{'prePost'}:""; # pre or post-position
	my $base = $sign->{'base'}?$sign->{'base'}:""; # baseform if present
	my $allo = $sign->{'allograph'}?$sign->{'allograph'}:""; # variant forms if present
	my $formvar = $sign->{'formvar'}?$sign->{'formvar'}:"";
	my $modif = $sign->{'modifier'}?$sign->{'modifier'}:"";
	
	my $variantType = "";
	if ($base ne "") {
	    if ($allo ne "") { $variantType = "allograph"; }
	    elsif ($modif ne "") { $variantType = "modif"; }
	    elsif ($formvar ne "") { $variantType = "formvar"; }
	}
	
	$group = $sign->{'group'}?$sign->{'group'}:"";
	$for = $sign->{'for'}?$sign->{'for'}:"";
	
	my $syllabic = "";
	
	if ($category eq 'g:n') {
	    $category = "number";
	}
	
	elsif ($category eq 'g:x') {
	    #print "\n Value = ".$value." label = ".$label;
	    $category = "x";
	}
	
	elsif ($lang =~ m|^akk|) {
	    if ($category eq 'g:v') { # syllabic signs, unless {d}, {m}
		$category = "syllabic";
		my %syllables = ();
		$syllables{"V"} = 1; $syllables{"VC"} = 1;
		$syllables{"CV"} = 1; $syllables{"CVC"} = 1;

		my $tempvalue = $sign->{'base'}?$sign->{'base'}:$value;
		
		$syllabic = lc($tempvalue);
		
		# determine what kind of syllabic sign we're dealing with: V, CV, VC, CVC, other (ana/ina/arba/CVCV)
		$syllabic =~ s|(\d)||g;
		$syllabic =~ s|([aeiou])|V|g;
		# nuke the subscripts like numbers (unicode 2080 - 2089) 
		$syllabic =~ s|(\x{2080})||g; $syllabic =~ s|(\x{2081})||g; $syllabic =~ s|(\x{2082})||g; $syllabic =~ s|(\x{2083})||g; $syllabic =~ s|(\x{2084})||g;
		$syllabic =~ s|(\x{2085})||g; $syllabic =~ s|(\x{2086})||g; $syllabic =~ s|(\x{2087})||g; $syllabic =~ s|(\x{2088})||g; $syllabic =~ s|(\x{2089})||g;
		$syllabic =~ s|(\x{2093})||g; # subscript x
		$syllabic =~ s|([^V])|C|g;
		
		if ($syllabic eq "VV") { # e.g., ia
		    $syllabic = "CV";
		}
		
		
	    # I'm treating CVCV and VCV together with CVC and VC to avoid confusion (then there won't be too much problem with the differing opinions of scholars).
	    # Moreover, on CVC instead of CVCV in NA, cf. Hämeen-Anttila par. 1.2.1
		if (($syllabic eq "CVCV") && (substr($tempvalue, 1, 1) eq substr($tempvalue, 3, 1))){  
		    $syllabic = "CVC";
		    #print "\nCVCV: ".$tempvalue;
		}
		
		if (($syllabic eq "VCV") && (substr($tempvalue, 0, 1) eq substr($tempvalue, 2, 1))){ 
		    if ($tempvalue ne "ana") { $syllabic = "VC"; }
		    #print "\nVCV".$tempvalue;
		# check IGI as ini *** TODO cf. Hämeen-Anttila
		}
		
		if ($role eq "semantic") {
		    $syllabic = ""; $category = "determinative";
		}
		
		if (!($syllables{$syllabic})) { # not V, CV, VC, or CVC
		    if ($syllabic eq "C") {
			if (($tempvalue eq "d") || ($tempvalue eq "m") || ($tempvalue eq "f")) { $category = "determinative"; $syllabic = ""; }
			else { $category = "x"; $syllabic = ""; } # then the value should be x, so unreadable sign, treat as "x"
		    } 
		    else { $category = "logogram"; $syllabic = ""; } # logosyllabic/syllabic-other ?? Mikko *** TODO, eg. ana/ina/arba/CVCV
		}
		else {
		    if ($tempvalue eq "o") { $category = ""; $syllabic = ""; }  
		}
	    }
	    elsif ($category eq 'g:s') {
		$category = "logogram";
	    }
	}
        elsif ($lang =~ m|^sux|) {
	    if ($category eq 'g:v') {
		# check if part of wordbase or not.
		# how about base/different signs in base with their position? somehow done, but may be improved TODO (?)
		if ($wordbase =~ /$value/) { $category = "base"; }
		else { $category = "nonbase"; }
	    }
	    if ($role eq "semantic") { 	$category = "determinative"; }
        }
        else {
	# TODO different languages ***
        }
    
    &saveSign($lang, $category, $value, $base, $variantType, $role, $prePost, $position, $syllabic, $break, $label, $cf, $writtenWord, $wordtype, $gw, $wordbase, $group, $for);
    if ($category ne "uncertainReading") { $category = ""; }
    }
}

sub saveSign { 
    my $lang = shift;
    my $category = shift;
    my $value = shift;
    my $base = shift;
    my $variantType = shift;
    my $role = shift;
    my $prePost = shift;
    my $pos = shift;
    my $syllabic = shift;
    my $break = shift;
    my $label = shift;
    my $cf = shift;
    my $writtenWord = shift;
    my $wordtype = shift;
    my $gw = shift; 
    my $wordbase = shift;
    my $group = shift || "";
    my $for = shift || "";
    my %temp = ();
    
    if($lang eq ""){ $lang = "noLang"; }
    if ($role eq "semantic") { $category = "determinative"; }
    
    $PQdata{"02_Signs"}{'total'}++; # total number of signs
    $PQdata{"02_Signs"}{"ztotal_state"}{$break}{'total'}++;
    $PQdata{"02_Signs"}{$lang}{'total'}++; # total number of signs per language
    $PQdata{"02_Signs"}{$lang}{"zlang_total_state"}{$break}{'total'}++;
    $PQdata{"02_Signs"}{$lang}{"category"}{$category}{'total'}++; # total number of signs per language and category
    $PQdata{"02_Signs"}{$lang}{"category"}{$category}{"state"}{$break}{'num'}++;
    
    if (($category eq "syllabic") && ($syllabic ne "")) {
	$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"type"}{$syllabic}{'total'}++; # total number of signs
        $PQdata{"02_Signs"}{$lang}{"category"}{$category}{"type"}{$syllabic}{"state"}{$break}{'num'}++;
	&abstractSigndata(\%{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"type"}{$syllabic}}, $value, $base, $variantType, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
    }
    elsif (($role eq "semantic") || ($role eq "phonetic")) {
	$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"total"}++;
	$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"state"}{$break}{"num"}++;
	&abstractSigndata(\%{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"prePost"}{$prePost}}, $value, $base, $variantType, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
    }
    else {
	# wordbase only here if Sumerian
	if (($wordbase eq "") || ($category eq "nonbase")) { &abstractSigndata(\%{$PQdata{"02_Signs"}{$lang}{"category"}{$category}}, $value, $base, $variantType, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for); }
	else { &abstractSigndata(\%{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"wordbase"}{$wordbase}}, $value, $base, $variantType, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for); }
    }
}    

sub abstractSigndata{ 
    my $data = shift;
    my $value = shift;
    my $base = shift;
    my $variantType = shift;
    my $wordtype = shift;
    my $pos = shift;
    my $gw = shift;
    my $cf = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $label = shift;
    my $group = shift || "";
    my $for = shift || "";
    
    if ($gw eq "1") { $gw = ""; } # personal names etc.
    
    if ($base eq "") {
        $data->{"value"}{$value}{'num'}++;
        if (($gw ne "") && ($cf ne "")) { &abstractSigndata2(\%{$data->{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}{"gw"}{$gw}}, $break, $writtenWord, $label, $group, $for); }
        elsif ($gw ne "") { &abstractSigndata2(\%{$data->{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gw}}, $break, $writtenWord, $label, $group, $for); }
        elsif ($cf ne "") { &abstractSigndata2(\%{$data->{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}}, $break, $writtenWord, $label, $group, $for); }
        else { &abstractSigndata2(\%{$data->{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}}, $break, $writtenWord, $label, $group, $for); }
    }
    else { # treat base as value and work with variants: allograph, modifier, formvar
	$data->{"value"}{$base}{'num'}++;
        if (($gw ne "") && ($cf ne "")) { &abstractSigndata2(\%{$data->{"value"}{$base}{$variantType}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}{"gw"}{$gw}}, $break, $writtenWord, $label, $group, $for); }
        elsif ($gw ne "") { &abstractSigndata2(\%{$data->{"value"}{$base}{$variantType}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gw}}, $break, $writtenWord, $label, $group, $for); }
        elsif ($cf ne "") { &abstractSigndata2(\%{$data->{"value"}{$base}{$variantType}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}}, $break, $writtenWord, $label, $group, $for); }
        else { &abstractSigndata2(\%{$data->{"value"}{$base}{$variantType}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}}, $break, $writtenWord, $label, $group, $for); }
    }
}

sub abstractSigndata2{
    my $data = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $label = shift;
    my $group = shift || "";
    my $for = shift || "";
    my $standsfor = "";
    
    if ($group eq "logo") { $group = ""; }
    elsif (($group eq "correction") && ($for ne "")) { $standsfor = $for; }
    
    if ($group eq "") {
	$data->{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'state'}{$break}{"line"}}, $label); }
    }
    elsif ($standsfor ne "") {
	$data->{'standsFor'}{$standsfor}{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'standsFor'}{$standsfor}{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'standsFor'}{$standsfor}{'state'}{$break}{"line"}}, $label); }
    }
    elsif ($group eq "reordering") {
	$data->{'group'}{$group}{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'group'}{$group}{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'group'}{$group}{'state'}{$break}{"line"}}, $label); }
    }
    else { # ??
	$data->{'group'}{$group}{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'group'}{$group}{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'group'}{$group}{'state'}{$break}{"line"}}, $label); }
    }
}

sub outputtext{
    my $data = shift;
    if($outputtype eq "text"){
	print $data;
    }
}

#create the folder if it doesn't already exist -
#issue will ensure if permissions on the parent folder are incorrect
sub makefile{
    my $path = shift;
    my $result = `mkdir $path 2>&1`; 
}

#generic function to write to an file somewhere
sub writetofile{
    my $shortname = shift; #passed in as a parameter
    my $data = shift; #passed in as a parameter
    my $startpath = $resultspath."/".$resultsfolder;
    &makefile($startpath); #pass to function
    my $destinationdir = $startpath;
    print $destinationdir."/".$shortname;
    if((defined $data) && ($data ne "")){
    #    create a file called the shortname - allows sub sectioning of error messages
	&outputtext("\n");
	open(SUBFILE2, ">".$destinationdir."/".$shortname.".xml") or die "Couldn't open: $!";
	binmode SUBFILE2, ":utf8";
	print SUBFILE2 XMLout($data);  
	close(SUBFILE2);
	&outputtext("\n");
    }
}

#generic function to write to an error file somewhere
sub writetoerror{
    my $shortname = shift; #passed in as a parameter
    my $error = shift; #passed in as a parameter
    my $startpath = $errorfile."/".$errorpath;
    &makefile($startpath); #pass to function
    
    my $destinationdir = $startpath;
    print $destinationdir."/".$shortname;
#    create a file called the shortname - allows sub sectioning of error messages
    open(SUBFILE2, ">>".$destinationdir."/".$shortname) or die "Couldn't open: $!";
    binmode SUBFILE2, ":utf8";
    print SUBFILE2 $error."\n";
    close(SUBFILE2);
}
#iterate over folder
# xtf and xmd-files: /home/varoracc/local/oracc/bld/saao/saa19/P224/P224381/P224381.xtf and .xmd
sub traverseDir{  # TODO: check if this works over directory structure
    my $path = shift; # filepath to start the search
    my $dirname = shift; #directory to start the search
    my $typename = shift; # parameter used in the global hash %config to save info
    my $ext = shift; # parameter to specify the file extension e.g. xml/ xtf we are interested in 
    my $checkforchildren = shift; # parameter to set whether or not to devel into any folders found
    my @childdir; #this is a local param as it is only useful in the context of it's parent directory
    
    my $dir = $path."/".$dirname;
    
    opendir(DIR, $dir) or die $!;
    while (my $file = readdir(DIR)) {

        # Use a regular expression to ignore files beginning with a period as they aren't important
        next if ($file =~ m/^\./);
        
        # Use -f to test for a file
        if(-f "$dir/$file"){
            # Ignore all files which don't have the extension we are interested in
            next if($file !~m|\.${ext}$|);
            push(@{$config{"filelist"}{$typename}}, "$dir/$file");# places in the global config so we can use the info later
            $config{"filehash"}{$typename}{"$file"} = 1;
        }
            
        # use -d to test for a directory
        elsif(-d "$dir/$file" && $checkforchildren){
            push(@{$config{"dirlist"}{$typename}}, "$dir/$file"); # places in the global config so we can use the info later
            push(@childdir, "$file");
        }
    }

    closedir(DIR);
    
    #recursively drop into folders and get more files
    foreach(@childdir){
        my $thisdir = $_;
    	&traverseDir($dir, $thisdir, $typename, $checkforchildren); #use all same parameters except for child dir.
    }
}