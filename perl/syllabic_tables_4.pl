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

my $projname = "SAA ***";
my $projdir = "../dataout/";
my $ogslfile = "../resources/ogsl.xml";

my $wordcount = 0;
my $missingwords = 0;
my $damagedwords = 0;
my $preservedwords = 0;
my $signcount = 0;
my $valuecount = 0;
my %syllcount = ();
my $sylldoubles = 0;

my @vowels = ("a", "e", "i", "u");
my @consonants = ("\x{02BE}", "b", "d", "g", "h", "i", "k", "l", "m", "n", "p", "q", "r", "s", "\x{1E63}", "\x{0161}", "t", "\x{1E6D}", "z");
my @finalconsonants = ("\x{02BE}", "b/p", "d/t/\x{1E6D}", "g/k/q", "h", "l", "m", "n", "r", "\x{0161}", "z/s/\x{1E63}");
my @tableheaders = ("V", "CV", "VC", "CVC");

my %sylldata = ();
my %syllsign = ();
my %logodata = ();
my %deterdata = ();
my %totals = ();


&tables($projdir.'P_LANG_akk-x-neoass.xml');  # depends on language and P or Q!!! ***

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
        h1('Corpus'),
	p('The analyzed corpus comprises '.$wordcount.' words:'),
	p({-style => 'text-indent:50px' },'- '.$preservedwords.' fully preserved words;'),
	p({-style => 'text-indent:50px' },'- '.$damagedwords.' partially preserved words;'),
	p({-style => 'text-indent:50px' },'- '.$missingwords.' restored words.'),
	p('Disregarding the restored signs, '.$signcount.' signs are attested with '.$valuecount.' readings.');
	
my $total = $signcount-$sylldoubles;
print	p('Rule 1: signs ending in a labial, dental or velar stop or in a sibilant (except /&#353;/) did not distinguish between voiced, voiceless and emphatic;'),
	p('Rule 2: CV signs ending in e/i and CVC signs with e/i-vowel count as one.'),
	p('Hence, the number of different readings decreases to '.$total.'.');

print	h1('General division of signs'),
	p('- according to their attestations ');

my $pieroles = "<div id='container1' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
$pieroles .= " var currentdata1 = [";

my %donut = ();
foreach my $r (keys %{$totals{"role"}}){
    my $sum = 0;
    if($totals{"role"}{$r}{"total"}){ $sum = $totals{"role"}{$r}{"total"};}
    if($r eq "logo" || $r eq "semantic"){
	$donut{"logograms"}{$r} = $sum;
    }
    elsif ($r ne "syll") {
	$donut{$r}{$r} = $sum;
    }
    else {
	my $sumcvc = 0;
	foreach my $c (keys %{$totals{"role"}{$r}{"cvc"}}) {
	    $sumcvc += $totals{"role"}{$r}{"cvc"}{$c}{"total"};
	    
	$donut{$r}{$c} = $totals{"role"}{$r}{"cvc"}{$c}{"total"};
	}
	#$donut{$r}{$r} = $sumcvc;
    }
}

my $count =0;
my @output;
my @firstcatnames;
foreach my $t (keys %donut){
    my $totalsum= 0;
    push(@firstcatnames,$t);
    my @catnames;
    my @catdata;
    foreach my $bit (keys %{$donut{$t}}){
	$totalsum = $totalsum + $donut{$t}{$bit};
	if($bit ne ""){
	    push(@catnames,$bit);
	    push(@catdata,$donut{$t}{$bit});
	}
    }
    my $writeme = "{   y: ".$totalsum.",";
    $writeme .= "      color: colors[".$count."],";
    $writeme .= "          drilldown: {";
    $writeme .= "                   name: '".$t."',";
    $writeme .= "                   categories: ['".join("','",@catnames)."'],";
    $writeme .= "                   data: [".join(",",@catdata)."],";
    $writeme .= "                   color: colors[".$count."]";
    $writeme .= "      }";
    $writeme .= "  }";
    
    push(@output,$writeme);
    $count++;
}
$pieroles .= join(",",@output);

$pieroles .= " ]";

$pieroles .= "; \$(document).ready(function() {";

my $catlist = join("','",@firstcatnames);
$pieroles .= " makeDonut(currentdata1,'Distribution across corpus (attestations)','title2', ['".$catlist."'],'container1');";

$pieroles .= "});</script>";

print $pieroles;

my $pierolescvc = "<div id='container2' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
$pierolescvc .= " var currentdata1b = [";
foreach my $c (keys %{$totals{"role"}{"syll"}{"cvc"}}) {
    my $temp = $totals{"role"}{"syll"}{"cvc"}{$c}{"total"};
    $pierolescvc .= " ['syllabic (".$c."; ".$temp.")',   ".$temp."],\n";
}
$pierolescvc = substr($pierolescvc,0,length($pierolescvc)-1);
$pierolescvc .= " ]";

$pierolescvc .= "; \$(document).ready(function() {";
$pierolescvc .= "   var alldata1b = pieoptions;";
$pierolescvc .= "   alldata1b.chart.renderTo = 'container2';"; 
$pierolescvc .= "   alldata1b.title.text = 'Distribution across corpus (syllabic attestations)';";
$pierolescvc .= "   alldata1b.series[0].data = currentdata1b;";
$pierolescvc .= "	chart1b = new Highcharts.Chart(alldata1b);";
$pierolescvc .= "});</script>";

print $pierolescvc;


print p('- according to the number of signs within each category');

my $pieroles2 = "<div id='container3' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
$pieroles2 .= " var currentdata2 = [";
foreach my $r (keys %{$totals{"role"}}){
    my $sum = 0;
    if ($r ne "syll") {
	$sum = $totals{"role"}{$r}{"diff_forms"}?$totals{"role"}{$r}{"diff_forms"}:0;
	$pieroles2 .= " ['".$r." (".$sum.")"."',   ".$sum."],";
    }
    else {
	my $sumcvc = 0;
	foreach my $c (keys %{$totals{"role"}{$r}{"cvc"}}) {
	    $sumcvc += $totals{"role"}{$r}{"cvc"}{$c}{"diff_forms"};
	}
	$sumcvc -= $sylldoubles;
	$pieroles2 .= " ['Syll (".$sumcvc.")"."',   ".$sumcvc."],";
    }
    
}
$pieroles2 = substr($pieroles2,0,length($pieroles2)-1);
$pieroles2 .= " ]";


$pieroles2 .= "; \$(document).ready(function() {";
$pieroles2 .= "   var alldata2 = pieoptions;";
$pieroles2 .= "   alldata2.chart.renderTo = 'container3';"; 
$pieroles2 .= "   alldata2.title.text = 'Distribution across corpus (categories)';";
$pieroles2 .= "   alldata2.series[0].data = currentdata2;";
$pieroles2 .= "	chart2 = new Highcharts.Chart(alldata2);";
$pieroles2 .= "});</script>";

print $pieroles2;

my $pierolescvc2 = "<div id='container4' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
$pierolescvc2 .= " var currentdata2b = [";
my $sumcvc = 0;
foreach my $c (keys %{$totals{"role"}{"syll"}{"cvc"}}) {
    my $temp = $totals{"role"}{"syll"}{"cvc"}{$c}{"diff_forms"} - $syllcount{$c};
    $pierolescvc2 .= " ['"."syllabic"." (".$c."; ".$temp.")"."',   ".$temp."],";
}

$pierolescvc2 = substr($pierolescvc2,0,length($pierolescvc2)-1);
$pierolescvc2 .= " ]";

$pierolescvc2 .= "; \$(document).ready(function() {";
$pierolescvc2 .= "   var alldata2b = pieoptions;";
$pierolescvc2 .= "   alldata2b.chart.renderTo = 'container4';"; 
$pierolescvc2 .= "   alldata2b.title.text = 'Distribution across corpus (syllabic categories)';";
$pierolescvc2 .= "   alldata2b.series[0].data = currentdata2b;";
$pierolescvc2 .= "	chart2b = new Highcharts.Chart(alldata2b);";
$pierolescvc2 .= "});</script>";

print $pierolescvc2;

# trying to get a pie-donut, but no luck. Guess I'm doing something wrong
#my $pieroles2 = "<div id='container2' style='min-width: 400px; height: 300px; margin: 0 auto'></div><script>";
#$pieroles2 .= " var currentdata2 = [";
## categories syll (V, CV, VC, CVC), logo (logo, determ), numbers
## syllabic data first
#my $sumcvc = 0;
#foreach my $c (keys %{$totals{"role"}{"syll"}{"cvc"}}) {
#    #print p($totals{"role"}{$r}{"cvc"}{$c}{"total"});
#    $sumcvc += $totals{"role"}{"syll"}{"cvc"}{$c}{"total"};
#    }
#$pieroles2 .= " { y:".$sumcvc.", drilldown: ";
#$pieroles2 .= " { name: 'Syllabic values', ";
#$pieroles2 .= " categories: ['V', 'CV', 'VC', 'CVC'], ";
#$pieroles2 .= " data: [".$totals{"role"}{"syll"}{"cvc"}{"V"}{"total"}.", ";
#$pieroles2 .= " data: [".$totals{"role"}{"syll"}{"cvc"}{"CV"}{"total"}.", ";
#$pieroles2 .= " data: [".$totals{"role"}{"syll"}{"cvc"}{"VC"}{"total"}.", ";
#$pieroles2 .= " data: [".$totals{"role"}{"syll"}{"cvc"}{"CVC"}{"total"}."] },";
#
#my $sumlogo = $totals{"role"}{"logo"}{"total"} + $totals{"role"}{"semantic"}{"total"};
#$pieroles2 .= " { y:".$sumlogo.", drilldown: ";
#$pieroles2 .= " categories: ['logo', 'determinative'], ";
#$pieroles2 .= " data: [".$totals{"role"}{"logo"}{"total"}.", ";
#$pieroles2 .= " data: [".$totals{"role"}{"semantic"}{"total"}."] }, ";
#
#$pieroles2 .= " { y:".$totals{"role"}{"number"}{"total"}.", drilldown: ";
#$pieroles2 .= " categories: ['number'], ";
#$pieroles2 .= " data: [".$totals{"role"}{"number"}{"total"}."] } ";
#
#$pieroles2 .= " }];";
#
#$pieroles2 .= " \$(document).ready(function() {";
#$pieroles2 .= "   var alldata2 = pieoptions;";
#$pieroles2 .= "   alldata2.chart.renderTo = 'container2';"; 
#$pieroles2 .= "   alldata2.title.text = 'Distribution across corpus (categories)';";
#$pieroles2 .= "   alldata2.series[0].data = currentdata2;";
#
#$pieroles2 .= "	chart2 = new Highcharts.Chart(alldata2);";
#$pieroles2 .= "});</script>";
#
#print $pieroles2;

print h1('Logographic sign use');

my $pielogo = "<div id='container5' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
$pielogo .= " var currentdata3 = [";

my $i = 0;
my $rest = $totals{"role"}{"logo"}{"total"};
my $remlogo = $totals{"role"}{"logo"}{"diff_forms"};
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

print h1('Syllabic sign use'), 
	p('Remembering Gelb&apos;s principle of the economy of the writing system...');

my $h2count = 0;
foreach my $i (@tableheaders) {
    $h2count++;
    my @test = split("",$i);
    my @alldata = ();
    my @lastone = ();
    my @lastbutone = ();
    my $cnt = 0;
    my $numcvc = scalar @test; 
    my $lastone = "";
    my $string = "";
    foreach my $j (@test){
	$string .= $j;
	$lastone = $j;
	my @tempdata = ();
	@lastbutone = ();
	if($cnt == 0){#this is the first time around
	    if($j eq 'C'){
		foreach my $c (@consonants){
		    push(@tempdata,$c);
		    push(@alldata,$c);
		}
	    }
	    elsif($j eq 'V'){
		foreach my $v (@vowels){
		    push(@tempdata,$v);
		    push(@alldata,$v);
		}
	    }
	}
	else{
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
	if($cnt == $numcvc){#this is the last but one
	    @lastbutone = @alldata;
	}
	@alldata = @tempdata;
    }
    
    $string =~ s|C|Consonant|gsi;
    $string =~ s|V|Vowel|gsi;
    print h2($h2count.". ".$string);
    print h3($i), start_table({-border=>1, -cellpadding=>3}), start_Tr, th([$i]);
    if($numcvc ==1){
	print end_Tr;
	if($lastone eq 'V'){
	    foreach my $v (@vowels) {
		print start_Tr;
		print td($v);
		my $string = ref($sylldata{$i}{$v}) eq 'ARRAY' ?join(", ",@{$sylldata{$i}{$v}}):" ";
		print td([$string]);
	    }
	}
	else {
	foreach (keys %{$sylldata{$i}}){   # this shouldn't happen
	    print start_Tr;
	    print td($_);
	    my $string = ref($sylldata{$i}{$_}) eq 'ARRAY' ?join(", ",@{$sylldata{$i}{$_}}):" ";
	    print td([$string]);
	}
	print end_Tr;
	}
    }
    else{
	if($lastone eq 'C'){
	    foreach my $c (@finalconsonants){
		print th([$c]);   # still have to get rid of aleph in CVC
	    }
	}
	elsif($lastone eq 'V'){
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
		    if (exists($sylldata{$i}{$key.$c})) {
			$thereis++;
		    }
		}
		if ($thereis != 0) {
		    print start_Tr, td([$key]);
		    foreach my $c (@finalconsonants){
			if (length($c) == 1) {
			    my $string = ref($sylldata{$i}{$key.$c}) eq 'ARRAY' ?join(", ",@{$sylldata{$i}{$key.$c}}):" ";
			    print td([$string]);
			}
			else {
			    my @letter = split("/",$c);
			    my $string = "";
			    foreach my $j (@letter){
				my $temp = ref($sylldata{$i}{$key.$j}) eq 'ARRAY' ?join(", ",@{$sylldata{$i}{$key.$j}}):" ";
				if ($temp ne " ") {
				    if ($string eq "") {
				    $string = $temp;
				    }
				    else {
				    $string = $string."; ".$temp;
				    }   
				}
				
			    }
			    print td([$string]);
			}
		    }
		}
	    }
	    elsif($lastone eq 'V'){
		print start_Tr, td([$key]);
		foreach my $v (@vowels){
		    my $string = ref($sylldata{$i}{$key.$v}) eq 'ARRAY' ?join(", ",@{$sylldata{$i}{$key.$v}}):" ";
		    print td([$string]);
		}
	    }
	    print end_Tr;
	}
    }
    print end_table;
}

# print Others
#print h2($h2count++.". Others");
#print start_table({-border=>1, -cellpadding=>3});
#foreach my $i (sort keys %sylldata){
#    if (grep {$_ eq $i} @tableheaders) {
#  	# already done, just don't know how to negate the grep
#    }
#    else {
#	my $string = "";
#	foreach my $element (sort keys %{$sylldata{$i}}) {
#	    if ($string eq "") {
#		$string = $element;
#	    }
#	    else {
#		$string = $string.', '.$element;
#	    }
#	}
#	print start_Tr, td([$i]), td([$string]), end_Tr;
#    }
#}
#print end_table;

my $pietotals="<div id='container' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
$pietotals .= " var currentdata= [";
#my $others = 0;
#my $VVtotal = $totals{"VV"}{"total"};
foreach my $d (sort keys %totals){
    if (grep {$_ eq $d} @tableheaders) {
	my $sum = $totals{$d}{"total"};
	#if ($d eq "CV") { $sum = $sum + $VVtotal; }
	$pietotals .= " ['".$d." (".$sum.")"."',   ".$sum."],";
    }
#    elsif (($d ne "VV") && ($d ne "C")) {  # I think I got rid of these in stats8
#	# VVs are counted together with CVs while Cs are determinatives and do not belong here.
#	$others = $others + $totals{$d}{"total"};
#	}    
}
#if ($others > 0) {
#    $pietotals .= " ['Others (".$others.")',   ".$others."],";
#}

$pietotals = substr($pietotals,0,length($pietotals)-1);
$pietotals .= " ]";

$pietotals .= "; \$(document).ready(function() {";
$pietotals .= "   var alldata = pieoptions;";
$pietotals .= "   alldata.title.text = 'Distribution across corpus';";
$pietotals .= "   alldata.series[0].data = currentdata;";
$pietotals .= "	chart = new Highcharts.Chart(alldata);";
$pietotals .= "});</script>";

print $pietotals;

my $piediffvalues="<div id='container2' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
$piediffvalues .= " var currentdata2= [";
my $othercat = 0;
my $VVdiff = $totals{"VV"}{"diff_values"};
foreach my $d (sort keys %totals){
    if (grep {$_ eq $d} @tableheaders) {
	my $sum = $totals{$d}{"diff_values"};
	if ($d eq "CV") { $sum = $sum + $VVdiff; }
	$piediffvalues .= " ['".$d." (".$sum.")"."',   ".$sum."],";
    }
#    elsif (($d ne "VV") && ($d ne "C")) {
#	# VVs are counted together with CVs while Cs are determinatives and do not belong here.
#	$othercat = $othercat + $totals{$d}{"diff_values"};
#	}    
}
#if ($othercat > 0) {
#    $piediffvalues .= " ['Others (".$others.")',   ".$othercat."],";
#}

$piediffvalues = substr($piediffvalues,0,length($piediffvalues)-1);
$piediffvalues .= " ]";

$piediffvalues .= "; \$(document).ready(function() {";
$piediffvalues .= "   var alldata2 = pieoptions;";
$piediffvalues .= "   alldata2.chart.renderTo = 'container2';"; 
$piediffvalues .= "   alldata2.title.text = 'Different values per category';";
$piediffvalues .= "   alldata2.series[0].data = currentdata2;";
$piediffvalues .= "	chart2 = new Highcharts.Chart(alldata2);";
$piediffvalues .= "});</script>";

print $piediffvalues;


print end_html;


sub tables{
    my $filename = shift;
    my $twigObj = XML::Twig->new();
    $twigObj->parsefile($filename);
    my $root = $twigObj->root;
    $twigObj->purge;

    my $counter = 0;
    my %alldata;
    
    # get signinfo from ogsl
    my $twigObjCun = XML::Twig->new();
    $twigObjCun->parsefile($ogslfile);
    my $rootCun = $twigObjCun->root;
    $twigObjCun->purge;
    
    my %signdata = ();

    my @signs = $rootCun->get_xpath('sign');
    foreach my $sign (@signs){
	my @utf8 = $sign->get_xpath("utf8");
	my $hex = $utf8[0]->{att}->{"hex"};
	#my $cunsign = $sign->findvalue('utf8');
	#print p($cunsign);
	my @vs = $sign->get_xpath("v");
	foreach my $thing (@vs){
	    $signdata{$thing->{att}->{"n"}} = $hex;
	}
    }

    
    # process datafile
    # collect data
    
    my @roles = $root->get_xpath("graphemes/type/role");
    my $totalcvc = 0;
    foreach my $i (@roles){
	my $role = $i->{att}->{name};
	if ($role ne "") {
	    if ($role ne "syll") {
		my @forms = $i->get_xpath("form");
		my $no_forms = 0;
		my $tot_forms = 0;
		if (defined($totals{"role"}{$role}{"total"})) {
		    $tot_forms = $totals{"role"}{$role}{"total"};
		}
		else {$tot_forms = 0;}
		if (defined($totals{"role"}{$role}{"diff_forms"})) {
		    $no_forms = $totals{"role"}{$role}{"diff_forms"};
		}
		else {$no_forms = 0;}
		
		foreach my $j (@forms) {
		    my $value = $j->{att}->{'name'}; # sign value
		    #push(@{$alldata{$value}},$value);
		    #push(@{$formdata{$role}{$value}},$value);
		    my @states = $j->get_xpath("state");
		    my $number = 0;
		    foreach my $k (@states) {
		        if (($k->{att}->{'name'} eq "preserved") || ($k->{att}->{'name'} eq "damaged")) { $number = $number + $k->{att}->{'num'}; }
		    }
		    if ($number > 0) {
		        $no_forms++;
			$tot_forms+= $number;
			if ($role eq "logo") { push(@{$logodata{"num"}{$number}{"value"}},$value); }
			if ($role eq "semantic") { push(@{$deterdata{"num"}{$number}{"value"}},$value); }
		    }
		    
		$totals{"role"}{$role}{"total"} = $tot_forms;
		$totals{"role"}{$role}{"diff_forms"} = $no_forms;
		}
		$signcount+= $no_forms;
		$valuecount+= $tot_forms;
		#print p("Role ".$role." total ".$totals{"role"}{$role}{"total"}." diff ".$totals{"role"}{$role}{"diff_forms"});
	    }
	    else {
		my @cvcs = $i->get_xpath("cvc");
		foreach my $j (@cvcs) {
		    my $cvc = $j->{att}->{'name'};
		    
		    my @cvcforms = $j->get_xpath("form");
		    my $no_cvcs = 0;
		    my $tot_cvcs = 0;
		    foreach my $k (@cvcforms) {
		        my $formname = $k->{att}->{'name'}; # sign value
			
			#push(@{$formdata{$role}{$k}{$value}},$value);
		        my @states = $k->get_xpath("state");
		        my $number = 0;
		        foreach my $l (@states) {
		            if (($l->{att}->{'name'} eq "preserved") || ($l->{att}->{'name'} eq "damaged")) { $number = $number + $l->{att}->{'num'}; }
		        }
		        if ($number > 0) {
			    $no_cvcs++;
			    $tot_cvcs+= $number;
			    push(@{$alldata{$cvc}},$formname);
			    
			    my $first = substr($formname, 0, 1);
	    
			    my $second = "";
			    if(length($cvc) >= 2){   # length of $value, not of $formname!
				$second = substr($formname, 1, 1);
			       }
			    my $third = "";
			    if(length($cvc) >= 3){   # length of $value, not of $formname!
				$third = substr($formname, 2, 1);
			    }
			    my $fourth = "";
			    if(length($cvc) >= 4){   # length of $value, not of $formname!
				$fourth = substr($formname, 3, 2);
			    }
			    push(@{$sylldata{$cvc}{$first.$second.$third.$fourth}},$formname);
			    my $cunhex = $signdata{$formname};
			    #print $cunhex;
			    push(@{$syllsign{$cvc}{"sign"}{$cunhex}{"value"}},$formname);
		        }
#			$sylldata{$k}{"value"}{$formname}{"num"} = $number;
		    }
	            $totals{"role"}{$role}{"cvc"}{$cvc}{"total"} = $tot_cvcs;
		    $totals{"role"}{$role}{"cvc"}{$cvc}{"diff_forms"} = $no_cvcs;
		    $signcount+= $no_cvcs;
		    $valuecount+= $tot_cvcs;
		    
		    #print p("Role ".$role." total ".$totals{"role"}{$role}{"cvc"}{$cvc}{"total"}." diff ".$totals{"role"}{$role}{"cvc"}{$cvc}{"diff_forms"});
		}
	    }
        }
    }

    
    foreach (sort keys %syllsign) {
	my $i = $_;
	#print p($i);
	$syllcount{$i} = 0;
	foreach my $sign (keys %{$syllsign{$i}{"sign"}}) {
	    #print p({-'font face' => "verdana"}, "print");
	    my $number = scalar @{$syllsign{$i}{"sign"}{$sign}{"value"}};
	    #print p('Number '.$number);
	    if ($number > 1) {  # several values belong to the same sign
		# signs ending in a labial, dental or velar stop or in a sibilant (except /š/) did not distinguish between voiced, voiceless and emphatic
		my %temp = ();
		foreach my $value (@{$syllsign{$i}{"sign"}{$sign}{"value"}}) {
		#if ($value=~m|^|) # beginning with b/p, etc. - not yet implemented as this is no fixed rule
		    $value = substr($value,0,length ($i)); # get rid of index numbers
		    if (($i eq "CV") || ($i eq "CVC")) {
			$value =~ s/[ie]/I/gsi;
			#print p($value);
		    }
		    if ($i eq "VC") {
		        my $cons = substr($value,1,1);
			$value =~ s/[bp]/B/;
			$value =~ s/[gkq]/G/;
			$value =~ s/[dt\x{1E6D}]/D/;
			$value =~ s/[z\x{1E63}s]/Z/;
			#print p($value);
		    }
		    if ($i eq "CVC") {
			my $cons = substr($value,2,1);
			$cons =~ s/[bp]/B/;
			$cons =~ s/[gkq]/G/;
			$cons =~ s/[dt\x{1E6D}]/D/;
			$cons =~ s/[z\x{1E63}s]/Z/;
			substr($value, 2, 1) = $cons; 
			#print p($value);
		    }
		#print p($value);
		$temp{$value}++;
		}
		if (($i eq "CV") || ($i eq "VC") || ($i eq "CVC")) {
		    my $cnt = 0;
		    foreach my $r (keys %temp) {
			#print ('el '.$r);
			$cnt++;
		    }
		    #print p('Keys temp '.$cnt);
		    if ($cnt != $number) {
			$cnt = $number - $cnt;
		        $syllcount{$i} += $cnt;
		        #print p($i." ".$syllcount{$i}); }
			$sylldoubles += $cnt;
		    }
		    #print p('Syllcount '.$syllcount{$i});
		}
		
		
	    }
	
	}
    }
    
    # word stats
    my @words = $root->get_xpath("words");
    $wordcount = $words[0]->{att}->{count};
    my @missing = $words[0]->get_xpath('type/total_grapheme[@name="missing"]');
    $missingwords = $missing[0]->{att}->{num}?$missing[0]->{att}->{num}:0;
    my @damaged = $words[0]->get_xpath('type/total_grapheme[@name="damaged"]');
    $damagedwords = $damaged[0]->{att}->{num}?$damaged[0]->{att}->{num}:0;
    my @preserved = $words[0]->get_xpath('type/total_grapheme[@name="preserved"]');
    
    $preservedwords = $preserved[0]->{att}->{num}?$preserved[0]->{att}->{num}:0;
    
    my $no_present_words = $wordcount;
    if($missingwords){
	$no_present_words = $wordcount - $missingwords;
    }

}      
