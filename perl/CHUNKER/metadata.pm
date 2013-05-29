package CHUNKER::metadata;

use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;

# get all the meta data associated with a file
my %metadata = initialiseMetaData();

sub initialiseMetaData{
    return (
            name => "",
            designation => "",
            genre => "",
            language => "",
            object => "",
            period => "",
            project => "",
            provenance => "",
            script => "",
            subgenre => "",
            writer => "");
}

sub getCorpus{
    return $metadata{"project"};
}

#&getMetaData($root, $rootxmd, $shortname, "P");
#return and reinitialize metadata;
sub returnMetaData{
    #    fix langauge
    $metadata{"language"} = &CHUNKER::generic::langmatrix($metadata{"language"});
    return \%metadata;;
}

sub getMDSM{
    my $i = $_;
    my %data = ();
    if($i->{att}->{k} eq "period"){   # e.g. <m k="period">Hellenistic</m>
        $metadata{"period"} = $i->text;
    }
    if($i->{att}->{k} eq "genre"){    # e.g. <m k="genre">administrative letter</m>
        $metadata{"genre"} = $i->text;
    }
    if($i->{att}->{k} eq "subgenre"){   
        $metadata{"subgenre"} = $i->text;
    }
    if($i->{att}->{k} eq "provenience"){   
        $metadata{"provenance"} = $i->text;
    }
    return 1;
}

#get object information
sub getObjM{
    if($_ && $_->{att}->{type}){
        $metadata{"object"} = $_->{att}->{type};
    }
}

#get protocol information
sub getProtM{
    my $i = $_;
# http://oracc.museum.upenn.edu/doc/builder/l2/languages/#Language_codes
    if (($metadata{"language"} eq "") && ($i->{att}->{type} eq "atf")) { $metadata{"language"} = $i->text; }
    if ($i->{att}->{type} eq "project") { $metadata{"project"} = $i->text; }
    
    if($i->{att}->{type} eq 'key' && $i->text=~m|=|){
        my @bits = split(/=/,$i->text);
        if(exists $metadata{$bits[0]}){#only do for keys that are real
            $metadata{$bits[0]} = $bits[1];
        }
    }
       ##   in SAA not given in metadata, but in xtf-file under
##        <protocols scope="text">
##		<protocol type="project">saao/saa10</protocol>
##		<protocol type="atf">lang nb</protocol>
##		<protocol type="key">file=SAA10/LAS_NB.saa</protocol>
##		<protocol type="key">musno=K 00552</protocol>
##		<protocol type="key">cdli=ABL 0255</protocol>
##		<protocol type="key">writer=A@aredu</protocol>
##		<protocol type="key">L=B</protocol>
##	</protocols>

}



sub getXclM{
    my $i = $_;
    #http://oracc.museum.upenn.edu/doc/builder/l2/langtags   
    $metadata{"language"} = $i->{att}->{"langs"}?$i->{att}->{"langs"}:"";  # with L2!
}

sub getCatM{
    my $cat = $_;
    # no period in SAAo, but <date c="1000000"/> [Neo-Assyrian]
    foreach my $i ($cat->get_xpath('date')) {
        my $temp = $i->{att}->{c};
        if($temp eq "1000000"){   # Q: Other codes ??? [ask Steve ***]
            $metadata{"period"} = "Neo-Assyrian";  
        }
    }
##http://oracc.museum.upenn.edu/doc/builder/l2/langtags  
    if ($metadata{"language"} eq "" && $cat->findvalue('language')) {
	$metadata{"language"} = $cat->findvalue('language'); 
    }
    
    $metadata{"period"} = $cat->findvalue('period');
    $metadata{"designation"} = $cat->findvalue('designation');
    $metadata{"genre"} = $cat->findvalue('genre');
    $metadata{"subgenre"} = $cat->findvalue('subgenre');
    $metadata{"provenance"} = $cat->findvalue('provenance');
    $metadata{"provenance"} = $cat->findvalue('provenience');
    $metadata{"script"} = $cat->findvalue('script');
    $metadata{"writer"} = $cat->findvalue('ancient_author');
    # SAA; colophon information does not seem to be included in metadata (neither is the scribe especially marked in xtf)

}

#
#sub getMetaData{
#    # find core metadata fields and add them to each itemfile [$PQdata] + corpus metadata-file [corpusdata]
#    my $root = shift;
#    my $rootxmd = shift;
#    my $PQnumber = shift;
#    my $PorQ = shift;
#    my %PQdata = ();
#

#    $PQdata{"name"} = $PQnumber;    

#    
#    my $designation = "unspecified"; my $genre = "unspecified"; my $language = "unspecified"; my $object = "unspecified";
#    my $period = "unspecified"; my $project = "unspecified"; my $provenance = "unspecified";
#    my $script = "unspecified"; my $subgenre = "unspecified"; my $writer = "unspecified"; 
#      
   
 



#    # For corpusdata-file: allow for quick metadata search on PQ-number, period, provenance, genre, language, etc.
#    
#    #$PQdataBorger{"name"} = $PQnumber;
#    
#    if ($PQdata{"designation"} ne "") { $designation = $PQdata{"designation"}; } #$PQdataBorger{"designation"} = $designation; }
#    if ($PQdata{"genre"} ne "") { $genre = $PQdata{"genre"}; } #$PQdataBorger{"genre"} = $genre; }
#    if ($PQdata{"language"} ne "") { $language = $PQdata{"language"}; } #$PQdataBorger{"language"} = $language; }
#    if ($PQdata{"object"} ne "") { $object = $PQdata{"object"}; } #$PQdataBorger{"object"} = $object; }
#    if ($PQdata{"period"} ne "") { $period = $PQdata{"period"}; } #$PQdataBorger{"period"} = $period; }
#    if ($PQdata{"project"} ne "") { $project = $PQdata{"project"}; } #$PQdataBorger{"project"} = $project; }
#    if ($PQdata{"provenance"} ne "") { $provenance = $PQdata{"provenance"}; } #$PQdataBorger{"provenance"} = $provenance; }
#    if ($PQdata{"script"} ne "") { $script = $PQdata{"script"}; } #$PQdataBorger{"script"} = $script; }
#    if ($PQdata{"subgenre"} ne "") { $subgenre = $PQdata{"subgenre"}; } #$PQdataBorger{"subgenre"} = $subgenre; }
#    if ($PQdata{"writer"} ne "") { $writer = $PQdata{"writer"}; } #$PQdataBorger{"writer"} = $writer; }
#    
#    if (!defined $corpusdata{"corpus"}) { $corpusdata{"corpus"} = (); }
#
#    push(@{$corpusdata{"corpus"}{$project}{"designation"}{$designation}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"genre"}{$genre}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"language"}{$language}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"object"}{$object}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"period"}{$period}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"provenance"}{$provenance}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"script"}{$script}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"subgenre"}{$subgenre}{$PorQ}}, $PQnumber);
#    push(@{$corpusdata{"corpus"}{$project}{"writer"}{$writer}{$PorQ}}, $PQnumber);
#    
#    $thisCorpus = $project;
#    $corpusdesignation = $thisCorpus."_".$genre;
#    if ($subgenre ne "") { $corpusdesignation = $corpusdesignation."_".$subgenre; }
#    $corpusdesignation =~ s/\//_/gsi;
#    $corpusdesignation =~ s/ /_/gsi;
#}

1;