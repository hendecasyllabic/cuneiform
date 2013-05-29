package CHUNKER::linedata;

use strict;
use CHUNKER::word;
use CHUNKER::punct;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;

my $thisCorpus = "";
my $thisText = "";
my @splitrefs = ();

sub initialise{
    $thisCorpus = shift;
    $thisText = shift;
    @splitrefs = ();
}


sub getLineData {
    my $root = shift;
    my $label = shift;
    my $note = shift || "";
    my $writtenAs = shift || "";
    &CHUNKER::generic::writetoerror("timestamping","getLineData - starting ".localtime); 
    
    
    my %linedata = ();
    my $localdata = {};
    
    # cells, fields, alignment groups, l.inner
    my $sumgraphemes =0;
    
    my @cells = $root->get_xpath('c');
    foreach my $c (@cells){
	$localdata = &getLineData($c, $label, "","");
	$localdata->{"span"} = $c->{att}->{"span"};
	push(@{$linedata{'cells'}}, $localdata);
	$localdata = {};
    }
    
    my @fields = $root->get_xpath('f');
    foreach my $f (@fields){
	$localdata = &getLineData($f, $label, "","");
	$localdata->{"type"} = $f->{att}->{"type"};
	push(@{$linedata{'fields'}}, $localdata);
	$localdata = {};
    }
    
    my @alignmentgrp = $root->get_xpath('ag');
    foreach my $ag (@alignmentgrp) {
	$localdata = &getLineData($ag, $label, "",""); 
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
		    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.", ".$label.": more than one element in g:nonw in surro.");
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
			($tempdata, $position) = &CHUNKER::word::splitWord (\@arrayNonWord, $nonwEl, $label, $position); # resulting info in @arrayNonWord
		    }
		    $cnt++;
		}
	    }
	    else {
		# second part of surro - stands for, can be several words
		my $wordid = $i->{att}->{"xml:id"}?$i->{att}->{"xml:id"}:""; # reference of word - can then be linked to xcl data
		$langsurro = $i->{att}->{'xml:lang'}?$i->{att}->{'xml:lang'}:"noLang";
		$form = $i->{att}->{"form"}?$i->{att}->{"form"}:""; 
    		my $tempvalue = './/l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
		
		my @wordref = $root->get_xpath($tempvalue); 
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
		&CHUNKER::punct::savePunct($nonw[$cnt], $nonwBreak[$cnt], $nonwLang, $label, "ditto", $cf, $gw, $thisText);
		$cnt--;
	    }
	}
	elsif ($type eq "word") {
	    my $wordtype = "dittoword";
	    my $writtenWord = ""; my $preservedSigns = 0; my $signs = ();
	    my $conditionWord = "";
	    ($writtenWord, $signs, $conditionWord) = &CHUNKER::word::formWord(\@arrayNonWord);
	    $linedata{$conditionWord}++;
	    my $damagedSigns = $signs->{'damaged'}; my $missingSigns = $signs->{'missing'}; 
	    
	    # info in @arrayNonWord
	    my $no_signs = scalar @arrayNonWord;
	    $preservedSigns = $signs->{'preserved'};
    
	    #form = $writtenWord without [], halfbrackets
	    $form = $writtenWord; 
	    $form =~ s|\[||g; $form =~ s|\]||g; $form =~ s|\x{2E22}||g; $form =~ s|\x{2E23}||g;
	    &CHUNKER::word::saveWord($nonwLang, $form, $conditionWord, $wordtype, "", "", "", $writtenWord, $label, "", "", "", $note, $writtenAs);
	    
	    my $count = 0; my $beginpos = 0; my $endpos = $no_signs - 1; my $severalParts = 0;
	    while ($count < $no_signs) {
		if (($arrayNonWord[$count]->{'delim'}) && ($arrayNonWord[$count]->{'delim'} eq "--")) {
		    $endpos = $count; $severalParts++;
		    &determinePosition($beginpos, $endpos, \@arrayNonWord);
		    $beginpos = $endpos+1; $endpos = $no_signs - 1;
		}
		$count++;
	    }
	    &CHUNKER::word::determinePosition($beginpos, $endpos, \@arrayNonWord);
	    
	    foreach my $sign (@arrayNonWord) {
		my $category = "";
		if ($role eq "logo") { $category = "logogram"; }
		else { $category = $sign->{'tag'}?$sign->{'tag'}:"unknown"; }
		
		# condition of sign:
		# preserved: no break and status = ok
		# erased: status = erased
		# excised: status = excised
		# supplied: status = supplied
		# implied: status = implied
		# missing: break = missing and not "erased", "excised", "supplied" or "implied"
		# damaged: break = damaged (or rarely maybe with no break, so essentially the rest)
		
		my $condition = $sign->{'status'}?$sign->{'status'}:"";
		my $break = $sign->{'break'}?$sign->{'break'}:""; 
		if (($condition ne "erased") && ($condition ne "excised") && ($condition ne "supplied") && ($condition ne "implied")) {
		    if ($break eq "missing") { $condition = "missing"; }
		    elsif (($break eq "damaged") || ($condition eq "maybe")) { $condition = "damaged"; }
		    else { $condition = "preserved"; }
		}
		my $value = $sign->{'value'}; my $pos = $sign->{'pos'}; my $position = $sign->{'position'};
		# can these actually have base and modifier ??? TODO - CHECK
		# I'm not including gw as translation is possibly nonsensical (especially when combination of words)
		&CHUNKER::punct::saveSign($nonwLang, $category, $value, "", "", "", "", "", "", $position, "", $condition, $label, $form, $writtenWord, $wordtype, "", "");
	    }
	}
    }

    # gloss: P348219; P348635 (e.g. hi-pi2 (esh-shu2))
    my @glosses = $root->get_xpath('g:gloss');
    my $no_glosses = scalar @glosses;
    foreach my $g (@glosses) {
	$note = "gloss";
	$localdata = &getLineData($g, $label, $note,"");
	push(@{$linedata{'glosses'}}, $localdata);
	$localdata = {};
    }
    
    my @nonw = $root->get_xpath('g:nonw');
    my $no_nonw = scalar @nonw;
    foreach my $nw (@nonw) {
	my $type = $nw->{att}->{"type"}?$nw->{att}->{"type"}:"";
	if (($type ne "dollar") && ($type ne "punct") && ($type ne "excised"))
	    { &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": nonw of type ".$type."."); }
    
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
		    &CHUNKER::punct::savePunct($sign, $break, $lang, $label, "", "", "", $thisText); # these signs are saved under signs.
		}	
		elsif (($tag eq 'g:v') || ($tag eq 'g:s')) { # this does not yet occur - keep checking ***
		    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": nonw of type ".$type.", with tag ".$tag);
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
		    &CHUNKER::punct::savePunct($sign, $break, $lang, $label, "excised", "", "", $thisText); # these signs are saved under signs.
		    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": excised punctuation");
		    
		}
		else { # e.g. in P365126; P363582 [g:d and g:s]; P363419; Q001870; P296713 [g:v]; Q003232; P334914 [g:d, g:v]; P348219 [g:n]; P363524
		    ($tempdata, $position) = &CHUNKER::word::splitWord (\@arrayWord, $i, $label, $position);
		    $sign = $arrayWord[$cnt]->{'value'};
		    $cnt++;
		}
		$localdata->{"type"} = $type;
		$localdata->{"sign"} = $sign;
		push (@{$linedata{'nonw'}}, $localdata);
		$localdata = {};
	    }
	    my $writtenWord = ""; 
	    my $preservedSigns = 0; 
	    my $signs = (); my $conditionWord = "";
	    ($writtenWord, $signs, $conditionWord) = &CHUNKER::word::formWord(\@arrayWord);
	    $linedata{$conditionWord}++;
	    
	    if ($signs->{'preserved'}) { $linedata{"preservedSigns"} += $signs->{'preserved'}; $linedata{'totalSigns'} += $signs->{'preserved'}; }
	    if ($signs->{'damaged'}) { $linedata{"damagedSigns"} += $signs->{'damaged'}; $linedata{'totalSigns'} += $signs->{'damaged'}; }
	    if ($signs->{'missing'}) { $linedata{"missingSigns"} += $signs->{'missing'}; $linedata{'totalSigns'} += $signs->{'missing'}; }
	    if ($signs->{'implied'}) { $linedata{"impliedSigns"} += $signs->{'implied'}; $linedata{'totalSigns'} += $signs->{'implied'}; }
	    if ($signs->{'supplied'}) { $linedata{"suppliedSigns"} += $signs->{'supplied'}; $linedata{'totalSigns'} += $signs->{'supplied'}; }
	    if ($signs->{'erased'}) { $linedata{"erasedSigns"} += $signs->{'erased'}; $linedata{'totalSigns'} += $signs->{'erased'}; }
	    if ($signs->{'excised'}) { $linedata{"excisedSigns"} += $signs->{'excised'}; $linedata{'totalSigns'} += $signs->{'excised'}; }
	    
	    my $no_signs = scalar @arrayWord;
    
	    #form = $writtenWord without [], halfbrackets, <>, (), {}
	    my $form = $writtenWord; 
	    $form =~ s|\[||g; $form =~ s|\]||g; $form =~ s|\x{2E22}||g; $form =~ s|\x{2E23}||g;
	    $form =~ s|\(||g; $form =~ s|\)||g; $form =~ s|\&lt;||g; $form =~ s|\&gt;||g; $form =~ s|\&lt;\{||g; $form =~ s|\}\&gt;||g;
	    
	    my $wordtype = &CHUNKER::word::typeWord ($form, "");
	    #&writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": nonw of form ".$form." type ".$wordtype); 
	    
	    &CHUNKER::word::saveWord($lang, $form, $conditionWord, $wordtype, "", "", "", $writtenWord, $label, "", "", "", $note, $writtenAs); 
	    
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
	    $allWordData{"word"}->{"wordtype"} = $wordtype; $allWordData{"word"}->{"wordbase"} = "";
	    $allWordData{"word"}->{"gw"} = "";
        
	    &saveSigns($thisText, \%allWordData, \@arrayWord);
	}
	else { # this does not yet occur - keep checking ***
	    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": nonw of type ".$type." check procedure"); 
	    my @children = $nw->children();  # can be g:c too, as in P363689; or g:w
	    foreach my $i (@children) {
	        my $tag = $i->tag;
	        if ($tag eq 'g:p') { # punctuation
		    $sign = $i->{att}->{"g:type"}?$i->{att}->{"g:type"}:"";
		    my $break = $i->{att}->{"g:break"}?$i->{att}->{"g:break"}:"preserved";
		    &CHUNKER::punct::savePunct($sign, $break, $lang, $label, "", "", "", $thisText); # these signs are saved under signs.
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
    my $preservedSigns = 0; my $damagedSigns = 0; my $missingSigns = 0; my $impliedSigns = 0; my $suppliedSigns = 0; my $erasedSigns = 0; my $excisedSigns = 0;
    $linedata{'totalSigns'} = 0; # needed ??? HIER
    foreach my $word (@words) {
	my @children = $word->children(); my $no_children = scalar @children;
	my $tag = $children[0]->tag;
	if (($tag eq "g:x") && ($no_children == 1)) { # I don't want to count an ellipsis as 1 word [could be more or (even) less]
		if ($children[0]->{att}->{"g:type"}) { $localdata->{"kind"} = $children[0]->{att}->{"g:type"}; }
		if ($children[0]->{att}->{"g:break"}) { $localdata->{"break"} = $children[0]->{att}->{"g:break"}; }
		push (@{$linedata{'x'}}, $localdata);
	    }
	else  {
	    my $tempdata = {};
	    if ($word->{att}->{headform}) { # beginning of split word
		
		my $headref = $word->{att}->{"xml:id"};
		#print "\nheadform".$headref;
		$tempdata = &CHUNKER::word::analyseWord($root, $word, $label, $note, "splithead");
		$linedata{"splitWord"}++;
		push (@splitrefs, $headref);
	    }
	    elsif ($word->{att}->{"form"} ne "o"){ # words with form="o" are not words at all and shouldn't be considered (e.g. SAA 1 10 o 18 = P 334195)
		# normal words
		# analyse words - collect all sign information (position, kind, delim, state)
		#print "\nAnalyse ". $word->{att}->{"form"};
		$tempdata = &CHUNKER::word::analyseWord($root, $word, $label, $note,"");
	    }
	    
	    if ($tempdata->{"conditionWord"}) { $linedata{$tempdata->{"conditionWord"}}++; }
	
	    if ($tempdata->{"preservedSigns"}) { $linedata{"preservedSigns"} += $tempdata->{"preservedSigns"}; $linedata{'totalSigns'} += $tempdata->{"preservedSigns"}; }
	    if ($tempdata->{"damagedSigns"}) { $linedata{"damagedSigns"} += $tempdata->{"damagedSigns"}; $linedata{'totalSigns'} += $tempdata->{"damagedSigns"}; }
	    if ($tempdata->{"missingSigns"}) { $linedata{"missingSigns"} += $tempdata->{"missingSigns"}; $linedata{'totalSigns'} += $tempdata->{"missingSigns"}; }
	    if ($tempdata->{"impliedSigns"}) { $linedata{"impliedSigns"} += $tempdata->{'impliedSigns'}; $linedata{'totalSigns'} += $tempdata->{'impliedSigns'}; }
	    if ($tempdata->{"suppliedSigns"}) { $linedata{"suppliedSigns"} += $tempdata->{'suppliedSigns'}; $linedata{'totalSigns'} += $tempdata->{'suppliedSigns'}; }
	    if ($tempdata->{"erasedSigns"}) { $linedata{"erasedSigns"} += $tempdata->{'erasedSigns'}; $linedata{'totalSigns'} += $tempdata->{'erasedSigns'}; }
	    if ($tempdata->{"excisedSigns"}) { $linedata{"excisedSigns"} += $tempdata->{'excisedSigns'}; $linedata{'totalSigns'} += $tempdata->{'excisedSigns'}; }
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
		$tempdata = &CHUNKER::word::analyseWord($root, $split, $label, $note, "splitend");
		$linedata{"splitWord"}++;
		if ($tempdata->{"conditionWord"}) { $linedata{$tempdata->{"conditionWord"}}++; }
	
	        if ($tempdata->{"preservedSigns"}) { $linedata{"preservedSigns"} += $tempdata->{"preservedSigns"}; $linedata{'totalSigns'} += $tempdata->{"preservedSigns"}; }
		if ($tempdata->{"damagedSigns"}) { $linedata{"damagedSigns"} += $tempdata->{"damagedSigns"}; $linedata{'totalSigns'} += $tempdata->{"damagedSigns"}; }
		if ($tempdata->{"missingSigns"}) { $linedata{"missingSigns"} += $tempdata->{"missingSigns"}; $linedata{'totalSigns'} += $tempdata->{"missingSigns"}; }
		if ($tempdata->{"impliedSigns"}) { $linedata{"impliedSigns"} += $tempdata->{'impliedSigns'}; $linedata{'totalSigns'} += $tempdata->{'impliedSigns'}; }
		if ($tempdata->{"suppliedSigns"}) { $linedata{"suppliedSigns"} += $tempdata->{'suppliedSigns'}; $linedata{'totalSigns'} += $tempdata->{'suppliedSigns'}; }
		if ($tempdata->{"erasedSigns"}) { $linedata{"erasedSigns"} += $tempdata->{'erasedSigns'}; $linedata{'totalSigns'} += $tempdata->{'erasedSigns'}; }
		if ($tempdata->{"excisedSigns"}) { $linedata{"excisedSigns"} += $tempdata->{'excisedSigns'}; $linedata{'totalSigns'} += $tempdata->{'excisedSigns'}; }
	    }
	    #else { print "found ".$split->{att}->{"headref"}; }
	}
    }
    
    my @xes = $root->get_xpath('g:x');
    foreach my $x (@xes) {
	my $type = $x->{att}->{"g:type"};
	$localdata->{"kind"} = $type; 	# 'g:type="disambig"' |"user" | "word-absent" | "word-broken" | "word-linecont" | "empty" ??
	if (($type ne "newline") && ($type ne "ellipsis")) { # - keep checking *** not in test corpus
	    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.", ".$label.": x of type ".$type);
	}
	# OK for "newline" | "ellipsis" | 
	#empty: (only in note, so useless Q003232)
	#newline: P365126, P338366, P296713
	if ($type eq "newline") {
	    $linedata{"splitNewLine"}++;
	}
	if ($x->{att}->{"g:break"}) { $localdata->{"break"} = $x->{att}->{"g:break"}; }
	
	push (@{$linedata{'x'}}, $localdata);
	$localdata = {};
    }
    
    
    &CHUNKER::generic::writetoerror("timestamping","getLineData - ending ".localtime);
    return \%linedata;
}

1;