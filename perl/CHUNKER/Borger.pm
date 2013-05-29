package CHUNKER::Borger;

use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;

my %cacheogsl = ();
my %cacheborger = ();
my %allborger = ();

sub returnBorger{
    return \%allborger;
}

sub openOgslAndBorger{
    my $ogslfile = shift;
    my $Borgerfile = shift;
    &CHUNKER::generic::writetoerror("timestamping","openOgslAndBorger - starting ".localtime);
    #my $twigObj = XML::Twig->new();
    #$twigObj->parsefile($ogslfile);
    #$OgslRoot = $twigObj->root;
    #$twigObj->purge;
    
    my %ogsl = ();
    $cacheogsl{""} = ();
    $cacheogsl{""}{'signname'} = "";
    $cacheogsl{""}{'cuneicode'} = "";
    my $t= XML::Twig->new( 
	# the twig will include just the root and selected titles 
	twig_roots   => {
	    'sign' => sub {
		my $thing = $_;
		my $thing0 = $thing->{att}->{n};
		my $hexutf = "";
		if($thing->get_xpath('utf8') && ($thing->get_xpath('utf8'))[0]){
		    $hexutf = ($_->get_xpath('utf8'))[0]->text;
		}
		
		foreach my $j ($thing->get_xpath('v')) {
		    $cacheogsl{$j->{att}->{n}} = ();
		    $cacheogsl{$j->{att}->{n}}{'signname'} = $thing0;
		    $cacheogsl{$j->{att}->{n}}{'cuneicode'} = $hexutf;
		}
	    }
    #<sign n="F₅" xml:id="x2254">
    #<uphase>1</uphase>
    #<uname>CUNEIFORM NUMERIC SIGN OLD ASSYRIAN ONE SIXTH</uname>
    #<utf8 hex="x12461">𒑡</utf8>
    #<v n="1/6"></v>
    #</sign>
	}
    );
    $t->parsefile( $ogslfile);
    $t->purge;
	   
    $cacheborger{""}{'BorgerNo'} = "None";
    $cacheborger{""}{'BorgerVal'} = "";
    $cacheborger{""}{'Cuneicode'} = "";

    my $t2= XML::Twig->new( 
	# the twig will include just the root and selected titles 
	twig_roots   => {
	    'Borger' => sub {
		my $thing = $_;
		my $thing0 = $thing->{att}->{signname};
		my $thing1 = $thing->{att}->{n}?$thing->{att}->{n}:"";
		my $thing2 = $thing->{att}->{BorgerVal}?$thing->{att}->{BorgerVal}:"";
		my $thing3 = $thing->{att}->{utf8_hex};
		
		$cacheborger{$thing0}{'BorgerNo'} = $thing1;
		$cacheborger{$thing0}{'BorgerVal'} = $thing2;
		$cacheborger{$thing0}{'Cuneicode'} = $thing3;
	    }
    #  <Borger n="MZL868" signname="ILIMMU" BorgerVal="ILIMMU (9)" utf8_hex="&#x12446;"/>
	}
    );
    $t2->parsefile($Borgerfile);
    $t2->purge;
    
    #my $twigObj2 = XML::Twig->new();
    #$twigObj2->parsefile($Borgerfile);
    #$BorgerRoot = $twigObj2->root;
    #$twigObj2->purge;
    
    &CHUNKER::generic::writetoerror("timestamping","openOgslAndBorger - ending ".localtime);
}



sub saveBorger { 
    my $lang = shift;
    my $category = shift;
    my $value = shift;
    my $base = shift;
    my $allo = shift;
    my $formvar = shift;
    my $modif = shift;
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
    my $thisText = shift || "";
    &CHUNKER::generic::writetoerror("timestamping","saveBorger - starting ".localtime);
    
    if (($value ne "x") && ($value ne "X") && ($value ne ";")) { # split word with ;
	my $BorgerNo=""; my $BorgerVal=""; my $Cuneicode = "-"; my $signname = "-";
	my $basis = ($base ne "")?$base:$value;
	if (looks_like_number($basis)) {
	    $BorgerNo = "Number";
	    $BorgerVal = $value; 
	} 
	else {
	    # find out signname in ogsl.xml ($OgslRoot)
	    # Start from value without modifiers etc. = $base
	    
	    my $smallValue = lc ($basis); # and convert capital tsade, shin and thet to small ones
	    $smallValue =~ s/\x{1E62}/\x{1E63}/g;
	    $smallValue =~ s/\x{0160}/\x{0161}/g;
	    $smallValue =~ s/\x{1E6C}/\x{1E6D}/g;
	    $smallValue =~ s/\@/\\@/gsi;
	    $smallValue =~ s/"//gsi;
	    
	    my $ogsls = &getOgslValue($smallValue);
	    $signname = $ogsls->{'signname'};
	    $Cuneicode = $ogsls->{'cuneicode'};
	    
	    # combine with data from Borger.xml ($BorgerRoot)
	    $BorgerNo = "None";
	    if ($signname ne "-") {
		my $borgdata  = &getBorgerValues($signname);
		$BorgerNo = $borgdata->{'BorgerNo'}?$borgdata->{'BorgerNo'}:"";
		$BorgerVal = $borgdata->{'BorgerVal'}?$borgdata->{'BorgerVal'}:"";
		$Cuneicode = $borgdata->{'Cuneicode'}?$borgdata->{'Cuneicode'}:"";
	    }
	    # save the data in structure C_Borger
	    # also works on punctuation 
	    $allborger{"totalValues"}++;
	    $allborger{'BorgerNo'}{$BorgerNo}{'BorgerVal'} = $BorgerVal;
	    $allborger{'BorgerNo'}{$BorgerNo}{'Cuneicode'} = $Cuneicode;
	    $allborger{'BorgerNo'}{$BorgerNo}{'Signname'} = $signname;
	    $allborger{'BorgerNo'}{$BorgerNo}{'lang'}{$lang}{'category'}{$category}{'total'}++;
	    
	    if ($category eq "syllabic") {
		my $abstract = $value;
		
		if (($syllabic eq "CV") || ($syllabic eq "CVC") || ($syllabic eq "V") || ($syllabic eq "VC")) {
		    if ($syllabic eq "CV") {
			if (($abstract eq "ia") || ($abstract eq "ie") || ($abstract eq "ii") || ($abstract eq "iu")) {
			    $abstract = "IA";
			}
			if (($abstract eq "\x{02BE}a") || ($abstract eq "\x{02BE}e") || ($abstract eq "\x{02BE}i") || ($abstract eq "\x{02BE}u")) {
			    $abstract = "\x{02BE}A";
			}
			if (($abstract eq "a\x{02BE}") || ($abstract eq "e\x{02BE}") || ($abstract eq "i\x{02BE}") || ($abstract eq "u\x{02BE}")) {
			    $abstract = "A\x{02BE}";
			}
		    }
		
		    # nuke the subscripts like numbers (unicode 2080 - 2089) 
		    $abstract =~ s|(\x{2080})||g; $abstract =~ s|(\x{2081})||g; $abstract =~ s|(\x{2082})||g; $abstract =~ s|(\x{2083})||g; $abstract =~ s|(\x{2084})||g;
		    $abstract =~ s|(\x{2085})||g; $abstract =~ s|(\x{2086})||g; $abstract =~ s|(\x{2087})||g; $abstract =~ s|(\x{2088})||g; $abstract =~ s|(\x{2089})||g;
		    $abstract =~ s|(\x{2093})||g; # subscript x
		
		    # make abstract value for signs ending in labial, dental or velar stop or in a sibilant (except /š/): b/p => B, d/t/thet => D, g/k/q => G, z/s/tsade => Z
		    $abstract =~ s/[bp]$/B/;
		    $abstract =~ s/[dt\x{1E6D}]$/D/;
		    $abstract =~ s/[gkq]$/G/;
		    $abstract =~ s/[z\x{1E63}s]/Z/;
	    
		    # i and e not always distinguished either
		    $abstract =~ s/[ie]/I/gsi;
		
		    # abstract also beginning C - combine b/p, d/t/thet, g/k/q, s/shin, tsade/z 
		    $abstract =~ s/^[bp]/B/;
		    $abstract =~ s/^[dt\x{1E6D}]/D/;
		    $abstract =~ s/^[gkq]/G/;
		    $abstract =~ s/^[s\x{0161}]/S/;
		    $abstract =~ s/^[z\x{1E63}]/Z/;
		}
	    
		&BorgerSigndata(\%{$allborger{'BorgerNo'}{$BorgerNo}{'lang'}{$lang}{'category'}{$category}{'abstract'}{$abstract}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
		if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
		   $allborger{'BorgerNo'}{$BorgerNo}{'lang'}{$lang}{'category'}{$category}{'abstract'}{$abstract}{'attested'}{'All_attested'}{'total'}++;
		   $allborger{'BorgerNo'}{$BorgerNo}{'lang'}{$lang}{'category'}{$category}{'abstract'}{$abstract}{'attested'}{$wordtype.'_attested'}{'total'}++;
		   $allborger{'BorgerNo'}{$BorgerNo}{'lang'}{$lang}{'category'}{$category}{'abstract'}{$abstract}{'attested'}{'All_attested'}{$pos}++;
		   $allborger{'BorgerNo'}{$BorgerNo}{'lang'}{$lang}{'category'}{$category}{'abstract'}{$abstract}{'attested'}{$wordtype.'_attested'}{$pos}++;
		}
	    }
	    else {
		&BorgerSigndata(\%{$allborger{'BorgerNo'}{$BorgerNo}{'lang'}{$lang}{'category'}{$category}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
	    }
	}
    }
    else {
	$allborger{'splitWords'}{'num'}++; 
	if (($wordtype ne '') && ($gw ne '') && ($cf ne '')) {
	    push(@{$allborger{'splitWords'}{'lang'}{$lang}{'category'}{$category}{'wordtype'}{$wordtype}{'gw'}{$gw}{'cf'}{$cf}{'writtenWord'}{$writtenWord}{'label'}},$thisText.$label);
	}
	elsif (($wordtype ne '') && ($gw ne '') && ($cf eq '')) {
	    push(@{$allborger{'splitWords'}{'lang'}{$lang}{'category'}{$category}{'wordtype'}{$wordtype}{'gw'}{$gw}{'writtenWord'}{$writtenWord}{'label'}},$thisText.$label);
	}
	elsif (($wordtype ne '') && ($gw eq '') && ($cf ne '')) {
	    push(@{$allborger{'splitWords'}{'lang'}{$lang}{'category'}{$category}{'wordtype'}{$wordtype}{'cf'}{$cf}{'writtenWord'}{$writtenWord}{'label'}},$thisText.$label);
	}
	elsif (($wordtype ne '') && ($gw eq '') && ($cf eq '')) {
	    push(@{$allborger{'splitWords'}{'lang'}{$lang}{'category'}{$category}{'wordtype'}{$wordtype}{'writtenWord'}{$writtenWord}{'label'}},$thisText.$label);
	}
    }
    # Signs that are not in Borger should be accounted for, but keep checking.
    # x'es don't get any presence.
    &CHUNKER::generic::writetoerror("timestamping","saveBorger - ending ".localtime);
}

sub BorgerSigndata{ 
    my $data = shift;
    my $value = shift;
    my $base = shift;
    my $allo = shift;
    my $formvar = shift;
    my $modif = shift;
    my $wordtype = shift;
    my $pos = shift;
    my $gw = shift;
    my $cf = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $label = shift;
    my $group = shift || "";
    my $for = shift || "";
    
    &CHUNKER::generic::writetoerror("timestamping","BorgerSigndata - starting ".localtime);
    #if ($gw eq "1") { $gw = ""; } # personal names etc.

    # An allograph, or systemic sign variant, is introduced by the tilde-prefix (~)
    # The at-sign (@) precedes each modifier
    # Form variants is the GDL name for minor differences in the construction of signs which may be of interest in analysis of a corpus for handwritings, but which are not important enough to be displayed or included in the version of the writing used for linguistic analysis. Form variants are preceded by the backslash character (\) and consist of lowercase letters and or digits.
    
    my $variantType = ""; my $variantMod = $base; # first allograph, then modifier, then formvar...
    # can be a combination!!! eg P314339
    # in form, however, the formvars are not marked. Hence I make my own form existing of the base + allograph (preceded by tilde) + modifier (preceded by at-sign) + formvar (preceded by backslash)
    if ($base ne "") {
	if ($allo ne "") { $variantType = "allograph"; $variantMod .= "~".$allo; }
	if ($modif ne "") {
	    if ($variantType ne "") { $variantType .= "_and_"; }
	    $variantType .= "modifier";
	    $variantMod .= "@".$modif;
	}
	if ($formvar ne "") {
	    if ($variantType ne "") { $variantType .= "_and_"; }
	    $variantType .= "formvar";
	    $variantMod .= "\\".$formvar;
	}
    }
    
    if ($base eq "") { # normal values
        $data->{"value"}{$value}{'num'}++;
	$data->{"value"}{$value}{"state"}{$break}{'num'}++;
	
	if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	   $data->{"value"}{$value}{'attested'}{'All_attested'}{'total'}++;
	   $data->{"value"}{$value}{'attested'}{$wordtype.'_attested'}{'total'}++;
	   $data->{"value"}{$value}{'attested'}{'All_attested'}{$pos}++;
	   $data->{"value"}{$value}{'attested'}{$wordtype.'_attested'}{$pos}++;
	}
	&CHUNKER::punct::abstractSigndata2(\%{$data->{"value"}{$value}{"standard"}{$value}{"pos"}{$pos}{"wordtype"}{$wordtype}}, $cf, $gw, $break, $writtenWord, $label, $group, $for); 
    }
    else { # variant values; treat base as value and work with variants: allograph, modifier, formvar
	$data->{"value"}{$base}{'num'}++;
	$data->{"value"}{$base}{"state"}{$break}{'num'}++;
	if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	   $data->{"value"}{$base}{'attested'}{'All_attested'}{'total'}++;
	   $data->{"value"}{$base}{'attested'}{$wordtype.'_attested'}{'total'}++;
	   $data->{"value"}{$base}{'attested'}{'All_attested'}{$pos}++;
	   $data->{"value"}{$base}{'attested'}{$wordtype.'_attested'}{$pos}++;
	}
	# variant types...: form; allo, modif and/or formvar
	&CHUNKER::punct::abstractSigndata2(\%{$data->{"value"}{$base}{$variantType}{$variantMod}{"pos"}{$pos}{"wordtype"}{$wordtype}}, $cf, $gw, $break, $writtenWord, $label, $group, $for); 
    }

    &CHUNKER::generic::writetoerror("timestamping","BorgerSigndata - ending ".localtime);
}
# use a cache to speed up checking of ogsls    
sub getOgslValue{
    my $smallValue = shift;
    if($cacheogsl{$smallValue}){ #create local cache so don't have to do expensive xpath look up each time.
	&CHUNKER::generic::writetoerror("timestamping","getOgslValue - cached ".$smallValue." ".localtime);
    }
    else {
	&CHUNKER::generic::writetoerror("timestamping","getOgslValue - getting ".$smallValue." ".localtime);
	$cacheogsl{$smallValue} = ();
	$cacheogsl{$smallValue}{'cuneicode'} = "";
	$cacheogsl{$smallValue}{'signname'} = "-";
    }
    return $cacheogsl{$smallValue};
}
# use a cache to speed up checking of borger   
sub getBorgerValues{
    my $manipulate = shift;
    if($cacheborger{$manipulate}){#use cached version if it exists
	&CHUNKER::generic::writetoerror("timestamping","getBorgerValues - cached ".$manipulate." ".localtime);
    }
    else{
	&CHUNKER::generic::writetoerror("timestamping","getBorgerValues - getting ".$manipulate." ".localtime);
	$cacheborger{$manipulate} = ();
	$cacheborger{$manipulate}{'BorgerNo'} = "None";
	$cacheborger{$manipulate}{'BorgerVal'} = $manipulate;
	$cacheborger{$manipulate}{'Cuneicode'} = "";
	
	my $newmanu = $manipulate;
	$newmanu =~ s/@/\\@/g;
	$newmanu =~ s/\|//g;
	$newmanu =~ s/\.\S*//gsi;
	$newmanu =~ s/\&\S*//gsi;
	if($cacheborger{$newmanu}){
	    $cacheborger{$manipulate} = $cacheborger{$newmanu};
	    $cacheborger{$manipulate}{'BorgerNo'} .= "_combi";
	    return $cacheborger{$manipulate};
	    &CHUNKER::generic::writetoerror("timestamping","getBorgerValues - cached ".$manipulate." ".localtime);
    	}
	else{
	    return $cacheborger{$manipulate};
	}
    }
    return $cacheborger{$manipulate};
}

1;