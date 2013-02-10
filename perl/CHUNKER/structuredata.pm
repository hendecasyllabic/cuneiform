package CHUNKER::structuredata;

use CHUNKER::linedata;
use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;


sub getStructureData{
    my $root = shift;
    my $PorQ = shift;
    my $thisText = shift;
    my $baseresults = shift; 
    my $filepath = shift;
    my %structdata = ();
    my $localdata = {};
    my $label = "";
    
    
    &CHUNKER::generic::writetoerror("timestamping","getStructureData - starting ".localtime); 
    
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
    #print $no_surfaces;
    #die ;
    foreach my $s (@surfaces) {
	if (!defined $structdata{"surface"}) {
	    $structdata{"surface"} = ();
	    $structdata{"no_surfaces"} = $no_surfaces;
	}

	$localdata = &getStructureData($s, $PorQ, $thisText, $baseresults, $filepath);
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
	
	$localdata = &getStructureData($c, $PorQ, $thisText, $baseresults, $filepath);
	#print  $c->{att}->{'n'};
	my $col = $c->{att}->{'n'};
	#print Dumper($localdata);
	$localdata->{'no'} = $col;
	
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
	
	$localdata = &getStructureData($d, $PorQ, $thisText, $baseresults, $filepath);
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
		$localdata = &CHUNKER::linedata::getLineData($j, $speciallabel, "","");
		$localdata->{"type"} = $type;
		$localdata->{"label"} = $speciallabel;
		push (@{$structdata{"line"}}, $localdata);
		$localdata = {};
	    }
	}
	elsif ($type eq "lgs") { # analyse l line, disregard lgs line (even though order on tablet - there doesn't seem to be an automatic link between the elements in the lgs and the words in l) 
	    # NOTE: this partly distorts the data as the order in which the words are written is not the order given in l (hence the note (lgs) to the label).
	    # in dcclt: P225958, P231055, P240986, P247847, P247848, P332923, Q000003, Q000014
	    #&writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": lgs");
	    foreach my $j (@speciallines) {
		my $kind = $j->{att}->{"type"}?$j->{att}->{"type"}:"";
		if ($kind ne "lgs") {
		    my $speciallabel = $label." (lgs)";
		    $localdata = &CHUNKER::linedata::getLineData($j, $speciallabel, "","");
		    $localdata->{"type"} = $type;
		    $localdata->{"label"} = $label;
		    push (@{$structdata{"line"}}, $localdata);
		    $localdata = {};
		}
	    }
	    $structdata{'no_lines'}++;
	}
	else { # nts: STEVE: does this still exist??? *** if so, still has to go through getLineData
	    #CHUNKER::generic::writetoerror("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": nts");
	    CHUNKER::generic::writetoerror("PossibleProblems.txt", localtime(time)."Project: , text ".$thisText.": nts");
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
	$localdata = &CHUNKER::linedata::getLineData($l, $label, "","");
	$localdata->{"label"} = $label;
	push (@{$structdata{"line"}}, $localdata);
	$localdata = {};
    }
    #print Dumper \%structdata;
    &CHUNKER::generic::writetoerror("timestamping","getStructureData - ending ".localtime); 
    return \%structdata;
}

1;