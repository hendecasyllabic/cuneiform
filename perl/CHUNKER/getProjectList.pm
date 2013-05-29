package CHUNKER::getProjectList;
# loop over all the meta data files and create the project list
use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;


#<data name="" designation="ATU 6, pl. 64, W 15772,p"
#genre="Administrative" language="ERROR"
#object="tablet" period="Uruk III" project=""
#provenance="Uruk" script="" subgenre=""
#writer="" />

sub makeFile{
    my $directory = shift;
    my $baseresults = shift;
    my $comps;
    #    loop over signs folder:
    opendir (DIR, $directory) or die $!;
    while (my $file = readdir(DIR)) {
        # We only want files
        next unless (-f "$directory/$file");
        # Use a regular expression to find files ending in .txt
        next unless ($file =~ m/\.xml$/);
        
        $comps = &makeList($directory, $file, $comps);
    }
    closedir(DIR);
    
    my %all;
    foreach my $item (keys %{$comps}){
        my %corpus;
        $corpus{"name"} = $item;
        if ($item eq "") {
            $corpus{"name"} = "None Specified";
        }
        
        foreach my $section (keys %{$comps->{$item}}){
            $corpus{$section}{"item"} = [];
            foreach my $sitem (keys %{$comps->{$item}{$section}{"item"}}){
                my %sim;
                $sim{"name"}[0] = $sitem;
                if ($sitem eq "") {
                    $sim{"name"}[0] = "None Specified";
                }
                
                foreach my $pq (@{$comps->{$item}{$section}{"item"}{$sitem}{"ps"}}){
                    my $len = 0;
                    my $PQ = substr($pq, 0, 1);#is this a P or a Q
                    if ($sim{"ps"}{$PQ}) {
                       $len = scalar @{$sim{"ps"}{$PQ}};
                    }
                    my $endpq = substr($pq, 0, -4);#remove .xml bit
                    $sim{"ps"}{$PQ}[$len] = $endpq;
                }
                push(@{$corpus{$section}{"item"}},\%sim);
            }
        }
        push (@{$all{"opt"}{"corpus"}},\%corpus);

    }
    &CHUNKER::generic::writetojson("CORPUS_META", \%all, "projectList", $baseresults);
    &CHUNKER::generic::writetofile("CORPUS_META", \%all, "projectList", $baseresults);
}

sub makeList{
    my $directory = shift;
    my $file = shift;
    my $comps = shift;
    
    my $xs = new XML::Simple(keeproot => 1,forcecontent => 1,forcearray => 1, keyattr =>  ['name', 'key', 'id']);
    my $xml = $xs->XMLin($directory."/".$file);
    my $corpname =  $xml->{"data"}{""}{"project"};
   
    foreach my $item (keys %{$xml->{"data"}{""}}){
        if($item ne "project"){
            push (@{$comps->{$corpname}{$item}{"item"}{$xml->{"data"}{""}{$item}}{"ps"}},$file);
        }  
    }
    return $comps;
}


1;
