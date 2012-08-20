#!/usr/bin/perl -w
use strict;
use CGI qw(:all *table *Tr *td);
use Data::Dumper;
use XML::Twig;
use XML::Simple;
use utf8;
#this fixes the wide warnings and the numbers not being sub script
binmode STDOUT, ":utf8";

#http://perlmeme.org/tutorials/cgi_script.html
#charts with http://www.highcharts.com/

# with logograms:
# ? plural markers (-MESZ, -ME, -DIDLI), dual (-MIN, .2), and ditto signs distinguished somehow in Oracc? not really
# TODO: logographic suffixes ***

my $projname = "***";
my $projdir = "../dataoutNEW/";
my $ogslfile = "../resources/ogsl.xml";

my $language = "Standard Babylonian";
#my $language = "Sumerian";
my $file = $projdir."SIGNS_P_LANG_".$language.".xml";

my $kind = "All_attested"; # can be any of the word categories too, e.g. Numerical_attested, etc.

my @vowels = ("a", "e", "i", "u");
my @consonants = ("\x{02BE}", "b", "d", "g", "h", "i", "k", "l", "m", "n", "p", "q", "r", "s", "\x{1E63}", "\x{0161}", "t", "\x{1E6D}", "z");
my @finalconsonants = ("\x{02BE}", "b/p", "d/t/\x{1E6D}", "g/k/q", "h", "l", "m", "n", "r", "\x{0161}", "z/s/\x{1E63}");
my @tableheaders = ("V", "CV", "CVC", "VC", "VCV", "CVC", "CVCV", "other");

my %groups = ();
my %signdata = ();
my $PQSignsRoot = "";
my $PQWordsRoot = "";

my %sylldata = (); 
my %syllsign = (); 
my %logodata = (); 
my %deterdata = (); 
my %variousSignsPerValue = ();
my %numberdata = (); # not yet, needed?
my %totals = (); # ?

#colours for the different categories in the charts
my %colours;
$colours{"logogram"} = 1; # red
$colours{"number"} = 3; # purple
$colours{"punct"} = 2; # green
$colours{"syllabic"} = 0; # blue
$colours{"uncertainReading"} = 5; # orange
$colours{"determinative"} = 7; 
$colours{"x"} = 8;
$colours{"base"} = 9;
$colours{"nonbase"} = 4;
$colours{"phonetic"} = 6;

my $logoForms = 0;
my $logoTotal = 0;
my $deterForms = 0;
my $deterTotal = 0;

# P_LANG_...xml; Q_LANG_...xml TODO

#&getGlobalSignData($projdir."SIGNS_P_global.xml");
&compileSignData;
#&getSigns($projdir."SIGNS_P_LANG_akk.xml");
#&getWords($projdir."WORDS_P_LANG_akk.xml");

print   header({-charset => 'utf-8'}),
        start_html(
                       -title => 'Cuneiform literacy',
                       -script => [ {-language=>'javascript',
                                   -src=>"http://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js"},
				    {-language=>'javascript',
                                   -src=>"../www/js/highcharts.js"},
				    {-language=>'javascript',
                                   -src=>"../www/js/genericchart.js"}
				    ]
                       ),
        h1('Corpus '.$projname),
	h2('Language:'.$language.' with data: '.$kind),
	p ('Note that only actually attested signs are taken into account (thus: preserved, damaged and excised signs); missing, supplied, implied, maybe and erased signs are not.');

#&getGlobalWordData($projdir."WORDS_P_global.xml"); # TODO: generate global file

# for each language... TODO
# all languages at the moment in CompilationSigns and CompilationWords!!!
&makeCategoryDonut($file, $kind);
&makeSignsPerCategoryDonut($file, $kind);
&makeLogogramChart($file, $kind);
&makeDeterminativeChart($file, $kind);
&prepareSyllabicTable($file, $kind);
&printSyllabicTables($file, $kind);
	#p({-style => 'text-indent:50px' },'- '.$preservedwords.' fully preserved words;'),
	#p({-style => 'text-indent:50px' },'- '.$damagedwords.' partially preserved words;'),
	#p({-style => 'text-indent:50px' },'- '.$missingwords.' restored words.'),
	#p('Disregarding the restored signs, '.$signcount.' signs are attested with '.$valuecount.' readings.');

sub getGlobalWordData {
    my $globalWords = shift;
    
    my $twigObjWords = XML::Twig->new();
    $twigObjWords->parsefile($globalWords);
    my $globalWordsRoot = $twigObjWords->root;
    $twigObjWords->purge;
    
    my $total = ($globalWordsRoot->get_xpath('Words'))[0]->{att}->{'total'};
    my @languages = $globalWordsRoot->get_xpath('Words/lang');
    my $no_lang = scalar (@languages);
    
    if ($no_lang == 1) {
	my $lang = $languages[0]->{att}->{name};
	print	p('The analyzed corpus comprises '.$total.' words in the '.$lang.' language/dialect.');
    }
    else {
	print p('The analyzed corpus comprises '.$total.' words in '.$no_lang.' language(s)/dialect(s):');
	foreach my $l (@languages) {
	    my $lang = $l->{att}->{name};
	    my $no_words = $l->{att}->{'total'};
	    print p({-style => 'text-indent:50px' },' - '.$no_words.' words in '.$lang);
	}		
    }

    print p('Their state of preservation: '); # TODO
    
    #my @states = $PQWordsRoot->get_xpath('lang');
}

# makeCategoryDonut charts the total number of signs per category (excluding the missing ones)
# with subdivisions for syllabic signs and determinatives
sub makeCategoryDonut {
    my $file = shift;
    my $wordtype = shift; # should be possible to do! TODO
    
    my $twigCat = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigCat->parsefile($file);
    my $CatRoot = $twigCat->root;
    $twigCat->purge;

    print h2("\nGeneral distribution of the different categories of signs across the corpus");
    
    # prepare Donut    
    my $donut = "<div id='container1' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
    $donut .= " var currentdata1 = [";
    
    my @categories = $CatRoot->get_xpath('category');
    my @mainCategories;
    #my $count = 0;
    my @output;
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	my $totalCat = &totalNum ($cat, $wordtype);
	#print p("category ".$name." totalCat ".$totalCat);
	push(@mainCategories, $name);
	
	my @subCategories; # determinatives and syllabic signs may have subcategories
	my @catdata;
	if ($name eq "determinative") { # subdivision of pre- and postdeterminatives
	    my @prePost = $cat->get_xpath('prePost');
	    foreach my $p (@prePost) {
		my $n = $p->{att}->{name};
		my $t = &totalNum($p, $wordtype);
		#print p("category ".$n." totalCat ".$t);
		push(@subCategories, $n);
		push(@catdata, $t);
	    }
	}
	elsif ($name eq "syllabic") { # subdivision of different syllabic categories
	    my @types = $cat->get_xpath('type');
	    foreach my $p (@types) {
		my $n = $p->{att}->{name};
		my $t = &totalNum($p, $wordtype);
		#print p("category ".$n." totalCat ".$t);
		#if ($n eq "CVCV") { print "\nCVCV = ".$t; }
		push(@subCategories, $n);
		push(@catdata, $t);
	    }
	}
	else {
	    my $n = $cat->{att}->{name};
	    my $t = &totalNum($cat, $wordtype);
	    #print p("category ".$n." totalCat ".$t);
	    push(@subCategories, $n);
	    push(@catdata, $t);
	}
	
	# TODO: Question: for some reason really small categories are not printed on screen (e.g. category CVCV attested 0.02%)
	# TODO: how to get the actual numbers of attestations printed along the percentages?
	
	if (!($colours{$name})) { print " no colour for ".$name.". "; }
	
	my $writeme = "{   y: ".$totalCat.",";
	$writeme .= "      color: colors[".$colours{$name}."],";
	$writeme .= "          drilldown: {";
	$writeme .= "                   name: '".$cat."',";
	$writeme .= "                   categories: ['".join("','",@subCategories)."'],";
	$writeme .= "                   data: [".join(",",@catdata)."],";
	$writeme .= "                   color: colors[".$colours{$name}."]";
	$writeme .= "      }";
	$writeme .= "  }";
    
	push(@output,$writeme);
	
	#$count++;
    }
    
    #print Dumper @output;
    
    $donut .= join(",",@output);
    $donut .= " ]";
    $donut .= "; \$(document).ready(function() {";
    
    my $catlist = join("','",@mainCategories);
    $donut .= " makeDonut(currentdata1,'Distribution across corpus (attestations)','title2', ['".$catlist."'],'container1');";
    $donut .= "});</script>";

    print $donut;
}

# calculate total minus missing ones.
sub totalNum {
    my $i = shift;
    my $wordtype = shift;
    
    # total number of signs is built up as a sum of the preserved, damaged and excised signs
    # signs that are missing, implied, supplied, maybe or erased are not considered for this analysis as they're not present on the tablet
    # OK, erased signs may still be readable, but as the scribe realised his mistake in time, they were probably not meant to be written on the tablet and are thus left out of this analysis
#    my $total = 0; #$i->{att}->{"total"}; # minus missing signs! Missing signs are not taken into account
#    my @states = $i->get_xpath('state');
#    foreach my $m (@states) {
#	my $kind = $m->{att}->{name};
#	if (($kind eq "preserved") || ($kind eq "damaged") || ($kind eq "excised")) {
#	    my $temp = 0;
#	    if ($m->{att}->{'num'}) { $temp = $m->{att}->{'num'}; }
#	    elsif ($m->{att}->{'total'}) { $temp = $m->{att}->{'total'}; }
#	    $total += $temp;
#	}
#    }

    my $total = $i->{att}->{$wordtype}?$i->{att}->{$wordtype}:0;
    return $total;    
}

# makeSignsPerCategoryDonut charts the different categories and subcategories according to the number of distinct signs in each
sub makeSignsPerCategoryDonut {
    my $file = shift;
    my $wordtype = shift; # should be possible to do! TODO
    
    my $twigCat = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigCat->parsefile($file);
    my $CatRoot = $twigCat->root;
    $twigCat->purge;
    
    print h2("\nDistribution of the different categories and subcategories according to the number of distinct signs in each");
    
    # prepare Donut    
    my $donut = "<div id='container2' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
    $donut .= " var currentdata2 = [";
    
    my @categories = $CatRoot->get_xpath('category');
    my @mainCategories;
    #my $count = 0;
    my @output;
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	push(@mainCategories, $name);
	
	my $totalForms = 0;
	my @subCategories; # determinatives and syllabic signs may have subcategories
	my @signsPerCatdata;
	
	if ($name eq "determinative") { # subdivision of pre- and postdeterminatives
	    my @prePost = $cat->get_xpath('prePost');
	    foreach my $p (@prePost) {
		my $n = $p->{att}->{name};
		my $t = &diffForms($p, $wordtype);
		$totalForms += $t;
		push(@subCategories, $n);
		push(@signsPerCatdata, $t);
		$deterForms += $totalForms;
	    }
	    $deterTotal = &totalNum($cat, $wordtype);
	    #print p("category ".$name." deterTotal ".$deterTotal);
    	}
	elsif ($name eq "syllabic") { # subdivision of different syllabic categories
	    my @types = $cat->get_xpath('type');
	    foreach my $p (@types) {
		my $n = $p->{att}->{name};
		my $t = &diffForms($p, $wordtype);
		$totalForms += $t;
		#if ($n eq "CVCV") { print "\nCVCV = ".$t; }
		push(@subCategories, $n);
		push(@signsPerCatdata, $t);
	    }
	}
	else {
	    my $n = $cat->{att}->{name};
	    my $t = &diffForms($cat, $wordtype);
	    $totalForms += $t;
	    push(@subCategories, $n);
	    push(@signsPerCatdata, $t);
	    if ($name eq "logogram") {
		$logoForms = $totalForms;
		$logoTotal = &totalNum($cat, $wordtype);
		#print p("category ".$name." totalCat ".$logoTotal);
		#print ("\n Logograms: total = ".$logoTotal." diff forms = ".$logoForms);
	    }
	}
	
	my $writeme = "{   y: ".$totalForms.",";
	$writeme .= "      color: colors[".$colours{$name}."],";
	$writeme .= "          drilldown: {";
	$writeme .= "                   name: '".$cat."',";
	$writeme .= "                   categories: ['".join("','",@subCategories)."'],";
	$writeme .= "                   data: [".join(",",@signsPerCatdata)."],";
	$writeme .= "                   color: colors[".$colours{$name}."]";
	$writeme .= "      }";
	$writeme .= "  }";
	   
	push(@output,$writeme);
	
	#$count++;
    }
    
    $donut .= join(",",@output);
    $donut .= " ]";
    $donut .= "; \$(document).ready(function() {";
    
    my $catlist = join("','",@mainCategories);
    $donut .= " makeDonut(currentdata2,'Distribution across corpus (categories)','title2', ['".$catlist."'],'container2');";
    $donut .= "});</script>";

    print $donut;
}

sub diffForms {
    my $i = shift;
    my $wordtype = shift;
    
    my $temp = $i->{att}->{name};
    
    my $no_forms = 0;
    my @forms = $i->get_xpath("value");
    #print p("\nTime: ".localtime); 
    foreach my $f (@forms) {
	if ($f->{att}->{$wordtype}) { $no_forms++; }
    }
    #print p("\nCategory ".$temp." no_forms ".$no_forms);
    return $no_forms;
}

# everything by PN, GN, etc.

sub makeLogogramChart {
    my $file = shift;
    my $wordtype = shift; 
    
    my $twigLogo = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigLogo->parsefile($file);
    my $LogoRoot = $twigLogo->root;
    $twigLogo->purge;

    my $logograms = ($LogoRoot->get_xpath('category[@name="logogram"]'))[0];
    my @values = $logograms->get_xpath('value');
    foreach my $v (@values) {
	my $test = $v->{att}->{$wordtype}?$v->{att}->{$wordtype}:"no";
	if ($test ne "no") {
	    my $value = $v->{att}->{name};
	    my $number = $test;
	    push(@{$logodata{"num"}{$number}{"value"}}, $value);
	}
    }
        
    print h1('Logographic sign use');

    my $pielogo = "<div id='container5' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
    $pielogo .= " var currentdata3 = [";

    my $i = 0;
    my $rest = $logoTotal;
    my $remlogo = $logoForms;
    
    foreach my $n (sort { $b <=> $a } keys %{$logodata{"num"}}) {
        if ($i < 10) {
	    foreach my $s (@{$logodata{"num"}{$n}{"value"}}) {
		#print p($s." ".$n);
		$i++;
	    $pielogo .= " ['"."$s"." (".$n.")"."',   ".$n."],";
	    $rest -= $n;
	    }
	}
    }
    $remlogo -= $i;
    $pielogo .= " ['Remaining ".$remlogo." logograms (".$rest.")"."',   ".$rest."],";

    $pielogo = substr($pielogo,0,length($pielogo)-1);
    $pielogo .= " ]";

    $pielogo .= "; \$(document).ready(function() {";
    $pielogo .= "   var alldata3 = pieoptions;";
    $pielogo .= "   alldata3.chart.renderTo = 'container5';"; 
    $pielogo .= "   alldata3.title.text = 'Logographic distribution across corpus';";
    $pielogo .= "   alldata3.series[0].data = currentdata3;";
    $pielogo .= "	chart3 = new Highcharts.Chart(alldata3);";
    $pielogo .= "});</script>";

    print $pielogo;
}

sub makeDeterminativeChart {
    my $file = shift;
    my $wordtype = shift; 
    
    my $twigDet = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigDet->parsefile($file);
    my $DetRoot = $twigDet->root;
    $twigDet->purge;

    my $determinatives = ($DetRoot->get_xpath('category[@name="determinative"]'))[0];
    my @prePosts = $determinatives->get_xpath('prePost');
    foreach my $p (@prePosts) {
	my @values = $p->get_xpath('value');
	foreach my $v (@values) {
	    my $test = $v->{att}->{$wordtype}?$v->{att}->{$wordtype}:0;
	    if ($test > 0) {
	        my $value = $v->{att}->{name};
	        my $number = $test;
	        push(@{$deterdata{"num"}{$number}{"value"}}, $value);
	    }
	}
    }
        
    print h1('Determinative sign use');

    my $pielogo = "<div id='container4' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
    $pielogo .= " var currentdata4 = [";

    my $i = 0;
    my $rest = $deterTotal;
    my $remdeter = $deterForms;
    
    foreach my $n (sort { $b <=> $a } keys %{$deterdata{"num"}}) {
        if ($i < 10) {
	    foreach my $s (@{$deterdata{"num"}{$n}{"value"}}) {
		#print p("determinative ".$s." ".$n);
		$i++;
		$pielogo .= " ['"."$s"." (".$n.")"."',   ".$n."],";
		$rest -= $n;
	    }
	}
    }
    $remdeter -= $i;
    $pielogo .= " ['Remaining ".$remdeter." determinatives (".$rest.")"."',   ".$rest."],";

    $pielogo = substr($pielogo,0,length($pielogo)-1);
    $pielogo .= " ]";

    $pielogo .= "; \$(document).ready(function() {";
    $pielogo .= "   var alldata4 = pieoptions;";
    $pielogo .= "   alldata4.chart.renderTo = 'container4';"; 
    $pielogo .= "   alldata4.title.text = 'Determinative distribution across corpus';";
    $pielogo .= "   alldata4.series[0].data = currentdata4;";
    $pielogo .= "	chart4 = new Highcharts.Chart(alldata4);";
    $pielogo .= "});</script>";

    print $pielogo;
}


sub prepareSyllabicTable {
    my $file = shift;
    my $wordtype = shift; 
    
    my $twigCat = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigCat->parsefile($file);
    my $CatRoot = $twigCat->root;
    $twigCat->purge;
    
    my @categories = $CatRoot->get_xpath('category');
    my @types = ("V", "CV", "VC", "VCV", "CVC", "CVCV", "other");
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	if ($name eq "syllabic") {
	    # make tables of all types of syllabic values in the order given in @types
	    foreach my $type (@types) {
		#my $tempvalue = '//l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
		my $tempvalue = '//type[@name="'.$type.'"]'; 
		my @nodes = $cat->get_xpath($tempvalue);
		foreach my $node (@nodes) {
		    my @values = $node->get_xpath('value');
		    foreach my $i (@values) {
		        if ($i->{att}->{$wordtype}) {
			    # put values in table 
			    my $value = $i->{att}->{'name'};
			    my $syllable = $value; # without index number and without distinction of I and E in CV and CVC(V)
			    # nuke the subscripts like numbers (unicode 2080 - 2089) 
			    $syllable =~ s|(\x{2080})||g; $syllable =~ s|(\x{2081})||g; $syllable =~ s|(\x{2082})||g; $syllable =~ s|(\x{2083})||g; $syllable =~ s|(\x{2084})||g;
			    $syllable =~ s|(\x{2085})||g; $syllable =~ s|(\x{2086})||g; $syllable =~ s|(\x{2087})||g; $syllable =~ s|(\x{2088})||g; $syllable =~ s|(\x{2089})||g;
			    $syllable =~ s|(\x{2093})||g; # subscript x
			    if (($type eq "CV") || ($type eq "CVC") || ($type eq "CVCV")) {
				$syllable =~ s/[ie]/I/gsi;
			    }
			    
			    my $first = substr($value, 0, 1);
			    my $second = (length($type)>=2)?substr($value,1,1):"";
			    my $third = (length($type)>=3)?substr($value,2,1):"";
			    my $fourth = (length($type)>=4)?substr($value,3,1):"";
			    if (length($type)<=4) {
				push(@{$sylldata{$type}{$first.$second.$third.$fourth}},$value);
			    }
			    else {
				push(@{$sylldata{$type}{$value}},$value);
			    }
			    #my $cunname = $signdata{$value};
			    #print $cunhex;
			    #push(@{$syllsign{$type}{"sign"}{$cunname}{"value"}},$value);
			    push (@{$variousSignsPerValue{$type}{"syllable"}{$syllable}{"value"}}, $value);
			}
		    }
		}
	    }
	}
    }
    
}



sub printSyllabicTables {
    my $file = shift;
    my $wordtype = shift; 
    
    my @types = ("V", "CV", "VC", "VCV", "CVC", "CVCV", "other");
    
    print h1('Syllabic sign use');

    foreach my $t (@types) {
	if ($sylldata{$t}) {
	    my @type = split("",$t);
	    my $numSyll = scalar (@type);
	    
	    my @alldata = ();
	    my @lastone = ();
	    my @lastbutone = ();
	    my $cnt = 0;
	    my $lastone = "";
	    my $string = "";
	    foreach my $j (@type){
		$string .= $j;
		$lastone = $j;
		my @tempdata = ();
		@lastbutone = ();
		if ($cnt == 0){#this is the first time around
		    if ($j eq 'C'){
			foreach my $c (@consonants){
			    push(@tempdata,$c);
			    push(@alldata,$c);
			}
		    }
		    elsif ($j eq 'V'){
		        foreach my $v (@vowels){
		            push(@tempdata,$v);
		            push(@alldata,$v);
		        }
		    }
		}
		else {
		    foreach my $key (@alldata){
			if($j eq 'C'){
			    foreach my $c (@consonants){
			        push(@tempdata,$key.$c);
			    }
			}
			elsif($j eq 'V'){
			    foreach my $v (@vowels){
			        push(@tempdata,$key.$v);
			    }
			}
		    }
		}
	
		$cnt++;
		if ($cnt == $numSyll){#this is the last but one
		    @lastbutone = @alldata;
		}
		@alldata = @tempdata;
	    }
    
	    if (($numSyll <= 3) && ($t ne "VCV")) {
		print h2($t);
	        print start_table({-border=>1, -cellpadding=>3}), start_Tr, th([$t]);
	        if ($numSyll == 1) {
		    print end_Tr;
		    foreach my $v (@vowels) {
		        print start_Tr, td($v);
		        my $string = ref($sylldata{$t}{$v}) eq 'ARRAY' ? join(", ",@{$sylldata{$t}{$v}}):" ";
		        print td([$string]);
		    }
		    print end_Tr;
		}
		else {
		    if ($lastone eq 'C'){
			foreach my $c (@finalconsonants){
			    print th([$c]);   # still have to get rid of aleph in CVC
			}
		    }
		    elsif ($lastone eq 'V'){
			foreach my $v (@vowels){
			    print th([$v]);
			}
		    }
		    print end_Tr;
    		    foreach my $key (@lastbutone){
		        if($lastone eq 'C'){
			    # check if there are values beginning with $key when checking CVCs, otherwise no use to print them
			    my $thereis = 0;
			    foreach my $c (@consonants){  # must be possible to do this easier
			        if (exists($sylldata{$t}{$key.$c})) {
				    $thereis++;
				}
			    }
			    if ($thereis != 0) {
			        print start_Tr, td([$key]);
				foreach my $c (@finalconsonants){
				    if (length($c) == 1) {
					my $string = ref($sylldata{$t}{$key.$c}) eq 'ARRAY' ?join(", ",@{$sylldata{$t}{$key.$c}}):" ";
					print td([$string]);
				    }
				    else {
					my @letter = split("/",$c);
					my $string = "";
					foreach my $j (@letter){
					    my $temp = ref($sylldata{$t}{$key.$j}) eq 'ARRAY' ?join(", ",@{$sylldata{$t}{$key.$j}}):" ";
					    if ($temp ne " ") {
						if ($string eq "") { $string = $temp; }
						else { $string = $string."; ".$temp; }   
					    }
					}
					print td([$string]);
				}
			    }
			}
			}
			elsif ($lastone eq 'V'){
			    print start_Tr, td([$key]);
			    foreach my $v (@vowels){
			        my $string = ref($sylldata{$t}{$key.$v}) eq 'ARRAY' ?join(", ",@{$sylldata{$t}{$key.$v}}):" ";
			        print td([$string]);
			    }
			}
		    }
		    
		}
		print end_table;
	    }
	    else { # CVCV and others are given as a list instead of a table
		print h2($t);
	        foreach my $value (sort keys %{$sylldata{$t}}) {
		    print p($value);
		}
	    }
	    
	    foreach my $l (sort keys %{$variousSignsPerValue{$t}{"syllable"}}) {
		my $number = scalar @{$variousSignsPerValue{$t}{"syllable"}{$l}{"value"}};
		if ($number > 1) { # several signs used to write this syllable
		    print p();
		    print start_table({-border=>1, -cellpadding=>3}), start_Tr, th([$l]), th(['initial']), th(['medial']), th(['final']), th(['alone']);
		    #print p("Syllable ".$l." written as ");
		    my %tempdata = ();
		    foreach my $v (@{$variousSignsPerValue{$t}{"syllable"}{$l}{"value"}}) {
			$tempdata{$v} = &findPositionData($file, $wordtype, $t, $v);
			#if ($number > 1) { print $v." and "; }
			#else { print $v."."; }
			#$number--;
		    }
		    print end_table;
		    print p();
		    my @positions = ("initial", "medial", "final", "alone");
		    #foreach my $v (sort keys %tempdata) {
			#print h4($v);
			#while ((my $key, my $val) = each %tempdata) {
			#    print "key = ".$key;
			#    foreach my $z (%{$val}) {
			#	print "z = ".$z;
			#    }
			#    
			#}
			#foreach my $q (keys %{$tempdata{$v}}) {
			#    #print $q;
			#    foreach my $y (keys %{$tempdata{$v}{$q}}) {
			#	print "y = ".$y;
			#    }
			#}
			
			#foreach my $pos (@positions) {
			#    print h5("Position: ".$pos);
			#    #print p($tempdata{$v}{$pos});
			#    foreach my $wt (sort keys %{$tempdata{$v}{$pos}}) {
			#	print p($wt);
			#	print p($tempdata{$v}{$pos}{$wt});
			#	#foreach my $q (sort keys %{$tempdata{$i}{$pos}{$wt}{"gw"}}) {
				#    print $q;
				#}
				#print Dumper(%tempdata);
				#die;
				#foreach my $q (sort keys $tempdata{$i}{$wt}) {
				 #   print $q;
				#}
				#my @gw = @{$tempdata{$i}{$wt}{$pos}{"gw"}};
				#print Dumper(@{$tempdata{$i}{$wt}}->{$pos});
				#foreach my $w ($tempdata{$i}{$wt}{$pos}{"gw"}) {
				#    print p(" - ".$wt." : ".$w.", references: ");    
				#}
				
				    
				
			    #}
			#}
			#die;
		    #}
		}
		
	    }
	    
	    
	#    foreach my $j (sort keys %{$syllsign{$t}{"sign"}}) {
	#	my $number = scalar @{$syllsign{$t}{"sign"}{$j}{"value"}};
	#	if ($number > 1) { # several values belong to the same sign
	#	    my %temp = ();
	#	    foreach my $value (@{$syllsign{$t}{"sign"}{$j}{"value"}}) {
	#		#if ($value=~m|^|) # beginning with b/p, etc. - not yet implemented as this is no fixed rule
	#	        $value = substr($value,0,length ($t)); # get rid of index numbers
	#		if (($t eq "CV") || ($t eq "CVC") || ($t eq "CVCV")) {
	#		    $value =~ s/[ie]/I/gsi;
	#		    #print p($value);
	#		}
	#		if ($t eq "VC") {
	#		    my $cons = substr($value,1,1);
	#		    $value =~ s/[bp]/B/;
	#		    $value =~ s/[gkq]/G/;
	#		    $value =~ s/[dt\x{1E6D}]/D/;
	#		    $value =~ s/[z\x{1E63}s]/Z/;
	#		    #print p($value);
	#		}
	#		if (($t eq "CVC") || ($t eq "CVCV")) {
	#		    my $cons = substr($value,2,1);
	#		    $cons =~ s/[bp]/B/;
	#		    $cons =~ s/[gkq]/G/;
	#		    $cons =~ s/[dt\x{1E6D}]/D/;
	#		    $cons =~ s/[z\x{1E63}s]/Z/;
	#		    substr($value, 2, 1) = $cons; 
	#		    #print p($value);
	#		}
	#	    print p($value);
	#	    $temp{$value}++;
	#	    }
	#	    if (($t eq "CV") || ($t eq "VC") || ($t eq "CVC") || ($t eq "CVCV")) {
	#		my $cnt = 0;
	#		foreach my $r (keys %temp) {
	#		    #print ('el '.$r);
	#		    $cnt++;
	#		}
	#		print p('Keys temp '.$cnt);
	#		if ($cnt != $number) { 
	#		    $cnt = $number - $cnt;
	#		#    $syllcount{$t} += $cnt;
	#		    #print p($i." ".$syllcount{$i}); }
	#		#    $sylldoubles += $cnt;
	#		}
	#		#print p('Syllcount '.$syllcount{$i});
	#	    }
	#	}
	#    }
	}
    }
}

sub findPositionData {
    my $file = shift;
    my $wordtype = shift; 
    my $type = shift; # CV, etc.
    my $value = shift;
    
    my @positions = ("initial", "medial", "final", "alone");
    #my $tempvalue = '//type[@name="'.$type.'"]'; 
    
    my $twigType = XML::Twig->new(
				twig_roots => { 'type' => 1 }
				);
    $twigType->parsefile($file);
    my $TypeRoot = $twigType->root;
    $twigType->purge;
    
    my @start = $TypeRoot->get_xpath('type');
    my %data = ();
    $data{"initial"} = " "; $data{"medial"} = " "; $data{"final"} = " "; $data{"alone"} = " ";
    my %attestations = ();
    
    print start_Tr, td([$value]);
    foreach my $s (@start) {
	if ($s->{att}->{name} eq $type) {
	    my $tempvalue = 'value[@name="'.$value.'"]';
	    my $valueNode = ($s->get_xpath($tempvalue))[0];
	    my @results = $valueNode->get_xpath('pos');
	    foreach my $r (@results) {
		my $position = $r->{att}->{name};
		my $total = $r->{att}->{$wordtype}?$r->{att}->{$wordtype}:" ";
		$data{$position} = $total;
		#print "Type ".$type." value ".$value." position ".$position." total ".$total;
	    }
	
# PROBLEMS with following - FIX TODO
	    # store the data per position and wordtype (if "All_attested")
	#    if ($wordtype ne "All_attested") { # data gathered for one specific $wordtype
	#	my $tempvalue = '//wordtype[@name"'.$wordtype.'"]';
	#	my @nodes = $valueNode->get_xpath($tempvalue);
	#	foreach my $n (@nodes) {
	#	    my %temp = ();
	#	    $temp{$wordtype} = &findAttestations ($n);
	#	    push (@{$attestations{$wordtype}}, $temp{$wordtype});
	#	}
	#    }
	#    else {
	#	my @wordtypes = $valueNode->get_xpath('//wordtype');
	#	foreach my $w (@wordtypes) {
	#	    my $i = $w->{att}->{name};
	#	    #print p("Value = ".$value."; wordtype ".$i);
	#	    my @positions = $w->get_xpath('pos');
	#	    foreach my $x (@positions) {
	#		my @gws = $x->get_xpath('gw');
	#		my $toPrint = "";
	#		if ($gws[0]) {
	#		    foreach my $gw (@gws) {
	#			my $gwName = $gws[0]->{att}->{name};
	#			my @states = $gw->get_xpath('state');
	#			foreach my $s (@states) {
	#			    my $sName = $s->{att}->{name};
	#			    if (($sName eq "preserved") || ($sName eq "damaged") || ($sName eq "excised")) {
	#				my @writtens = $s->get_xpath('writtenWord');
	#				foreach my $w (@writtens) {
	#				    my $spelling = $w->{att}->{name};
	#				    #print $spelling;
	#				    my @lines = $w->get_xpath('line');
	#				    my $string = "";
	#				    foreach my $l (@lines) {
	#					my $lineNo = $l->text;
	#					$string .= $lineNo.", ";
	#					#print p("Gw ".$gwName." written ".$spelling." line ".$lineNo);
	#				    }
	#				    $string = substr($string, 0, length($string)-2);
	#				    $toPrint .= $gwName.": ".$spelling.", reference(s): ".$string."; ";
	#				    #print p("Gw ".$gwName." written ".$spelling." line ".$string);
	#				    #push (@{$temp{$position}{"gw"}{$gwName}{"written"}{$spelling}->{"line"}}, $string);
	#				    #die;
	#				}
	#			    #push (@{$temp{$position}{"word"}}, $toPrint);
	#			    }
	#			$toPrint = substr($toPrint, 0, length($toPrint)-2);
	#			}
	#		    }
	#		}
	#		$attestations{$x} = $toPrint;
	#	    }
	#	}
	#    }
        }
		    
		#    my %temp = ();
		#    $temp{$i} = &findAttestations ($w);
		#    
		#    
		#    foreach my $pos (keys %{$temp{$i}}) {
		#	#print $pos;
		#	print p("Value = ".$value."; pos = ".$pos."; wordtype = ".$i);
		#	print $temp{$i}{$pos};
		#	push (@{$attestationdata{$pos}{$i}}, $temp{$i}{$pos}); 
		#    }
    }

    foreach my $p (@positions) {
	print td([$data{$p}]);
    }
    
    return \%attestations;
}

sub findAttestations {
    my $wordtypeNode = shift;
    
    #my %temp = ();
    my %data = ();
    $data{"initial"} = ""; $data{"medial"} = ""; $data{"final"} = ""; $data{"alone"} = "";
    my @pos = $wordtypeNode->get_xpath('pos');
    foreach my $p (@pos) {
	my $position = $p->{att}->{name};
	my @gws = $p->get_xpath('gw');
	my $toPrint = "";
	if ($gws[0]) {
	    foreach my $gw (@gws) {
		my $gwName = $gws[0]->{att}->{name};
		my @states = $gw->get_xpath('state');
		foreach my $s (@states) {
		    my $sName = $s->{att}->{name};
		    if (($sName eq "preserved") || ($sName eq "damaged") || ($sName eq "excised")) {
			my @writtens = $s->get_xpath('writtenWord');
			foreach my $w (@writtens) {
			    my $spelling = $w->{att}->{name};
			    #print $spelling;
			    my @lines = $w->get_xpath('line');
			    my $string = "";
			    foreach my $l (@lines) {
				my $lineNo = $l->text;
				$string .= $lineNo.", ";
				#print p("Gw ".$gwName." written ".$spelling." line ".$lineNo);
			    }
			    $string = substr($string, 0, length($string)-2);
			    $toPrint .= $gwName.": ".$spelling.", reference(s): ".$string."; ";
			    #print p("Gw ".$gwName." written ".$spelling." line ".$string);
			    #push (@{$temp{$position}{"gw"}{$gwName}{"written"}{$spelling}->{"line"}}, $string);
			    #die;
			}
			
			#push (@{$temp{$position}{"word"}}, $toPrint);
		    }
		    $toPrint = substr($toPrint, 0, length($toPrint)-2);
		}
	    }
        }
	$data{$position} = $toPrint;
    }
    #print Dumper (%temp);
    #return \%temp;
    return \%data;
}
    

sub getGlobalSignData {
    my $globalSigns = shift;
    
    my $twigObjSigns = XML::Twig->new();
    $twigObjSigns->parsefile($globalSigns);
    my $globalSignsRoot = $twigObjSigns->root;
    $twigObjSigns->purge;
    
    
    
}


sub compileSignData{
    # get signinfo from ogsl
    my $twigObjCun = XML::Twig->new();
    $twigObjCun->parsefile($ogslfile);
    my $rootCun = $twigObjCun->root;
    $twigObjCun->purge;
    
    my @signs = $rootCun->get_xpath('sign');
    foreach my $sign (@signs){
	#my @utf8 = $sign->get_xpath("utf8");
	my @unames = $sign->get_xpath("uname"); # why doesn't this work??? HIER
	my $uname = "undef";
	if (scalar (@unames) > 0) {
	    $uname = $unames[0]->text;
	}
	else {
	    $uname = $sign->{att}->{"n"};
	}
	
	#my $hex = $utf8[0]->{att}->{"hex"};
	#my $cunsign = $sign->findvalue('utf8');
	#print p($cunsign);
	my @vs = $sign->get_xpath("v");
	foreach my $thing (@vs){
	    #$signdata{$thing->{att}->{"n"}} = $hex;
	    $signdata{$thing->{att}->{"n"}} = $uname;
	}
#	print p("uname ".$uname);
    }
}

sub getSigns{
    my $filename = shift;
   
    # get data from SIGNS datafile
    my $twigObj = XML::Twig->new();
    $twigObj->parsefile($filename);
    $PQSignsRoot = $twigObj->root;
    $twigObj->purge;
    
    my %alldata;
    
    my @categories = $PQSignsRoot->get_xpath('category');
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	my $tot = $cat->{att}->{'total'};
	
    }
}

sub getWords{
    my $filename = shift;
   
    # get data from SIGNS datafile
    my $twigObj = XML::Twig->new();
    $twigObj->parsefile($filename);
    $PQWordsRoot = $twigObj->root;
    $twigObj->purge;
    
    my %wordData;
}
