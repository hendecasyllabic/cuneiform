package CHUNKER::compilationLang;
use Data::Dumper;


#&CHUNKER::compilationLang::useFiles($baseresults."/signs",$baseresults,["P002296","P345960"],"sub1");
## use a list of files to create a bespoke selection
sub useFiles{
    my $directory = shift;
    my $baseresults = shift;
    my $files =shift;
    my $groupname = shift;
    
    foreach my $file (@{$files}){
	my $filename = $directory."/".$file.".xml";
	if (-e $filename) {
	    $comps = &makeComp($directory, $file.".xml", $comps);
	}
	else{
	    print "missing file ".$filename ; die;
	}
    }
    #loop over all the compilationERSigns stuff and split by lang
    foreach my $PQ (keys %{$comps}) {
	foreach my $lang (keys %{$comps->{$PQ}{'lang'}}){
	    my $newlang = $lang;
	    $newlang=~s| |_|g;
            print "\nPROCESSING LANG ".$newlang;
            &CHUNKER::generic::writetofile("".$groupname."SIGNS_".$PQ."_LANG_".$newlang, $comps->{$PQ}{'lang'}{$lang}, "compilation/subset", $baseresults);
	    #&writetofile("SIGNS_".$PQ."_LANG_".$newlang, $compilationERSigns{$PQ}{'lang'}{$lang}, $filepath);
	}
    }
    &CHUNKER::generic::writetofile("".$groupname, $comps, "compilation/subset", $baseresults);
    
}


#loop over the Borger lang stuff and make big totals file...
#
sub makeFiles{
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
        
        $comps = &makeComp($directory, $file, $comps);
    }
    closedir(DIR);
    
    #loop over all the compilationERSigns stuff and split by lang
    foreach my $PQ (keys %{$comps}) {
	foreach my $lang (keys %{$comps->{$PQ}{'lang'}}){
	    my $newlang = $lang;
	    $newlang=~s| |_|g;
            print "\nPROCESSING LANG ".$newlang;
            &CHUNKER::generic::writetofile("SIGNS_".$PQ."_LANG_".$newlang, $comps->{$PQ}{'lang'}{$lang}, "compilation", $baseresults);
	    #&writetofile("SIGNS_".$PQ."_LANG_".$newlang, $compilationERSigns{$PQ}{'lang'}{$lang}, $filepath);
	}
    }
    &CHUNKER::generic::writetofile("all", $comps, "compilation", $baseresults);
}

# make some totals up
sub makeComp{
    my $directory = shift;
    my $file = shift;
    my $comps = shift;
    
    my $PQ = substr($file, 0, 1);#is this a P or a Q
    my $xs = new XML::Simple(keeproot => 1,forcecontent => 1,forcearray => 1, keyattr =>  ['name', 'key', 'id']);
    my $xml = $xs->XMLin($directory."/".$file);
    
    foreach my $x (@{$xml->{'data'}}){
        my $lang = "";
        foreach my $y (keys %{$x->{'lang'}}){
            $lang = $y;
        }
        foreach my $totals (keys %{$x->{'lang'}{$lang}}){
            if ($totals=~m|^total|) {
                if ($comps->{$PQ}{'lang'}{$lang}[0]{$totals}) {
                    $comps->{$PQ}{'lang'}{$lang}[0]{$totals} += $x->{'lang'}{$lang}{$totals};
                }
                else{
                    $comps->{$PQ}{'lang'}{$lang}[0]{$totals} = $x->{'lang'}{$lang}{$totals};
                }
            }
        }
        
        if (!$comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'damaged'}{"num"}) {
            $comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'damaged'}{"num"} = 0;
        }
        if (!$comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'excised'}{"num"}) {
            $comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'excised'}{"num"} = 0;
        }
        if (!$comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'missing'}{"num"}) {
            $comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'missing'}{"num"} = 0;
        }
        if (!$comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'preserved'}{"num"}) {
            $comps->{$PQ}{'lang'}{$lang}[0]{"state"}{'preserved'}{"num"} = 0;
        }
        foreach my $category (keys %{$x->{'lang'}{$lang}{"category"}}){
#            place holders for totals
            if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'damaged'}{"num"}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'damaged'}{"num"} = 0;
            }
            if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'excised'}{"num"}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'excised'}{"num"} = 0;
            }
            if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'missing'}{"num"}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'missing'}{"num"} = 0;
            }
            if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'preserved'}{"num"}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{'preserved'}{"num"} = 0;
            }
    
            #print "CATEGORY".$category."\n";
            if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{'All_attested'}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{'All_attested'} = 0;
            }
            if ($x->{'lang'}{$lang}{"category"}{$category}{'All_attested'}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{'All_attested'} +=
		$x->{'lang'}{$lang}{"category"}{$category}{'All_attested'};
            }
            
            if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{'Punct_attested'}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{'Punct_attested'} = 0;
            }
            if ($x->{'lang'}{$lang}{"category"}{$category}{'Punct_attested'}) {
                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{'Punct_attested'}
		+= $x->{'lang'}{$lang}{"category"}{$category}{'Punct_attested'};
            }
            
            if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}) {
                foreach my $prepost (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}}){
		    if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{'All_attested'}) {
			$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{'All_attested'}=0;
		    }
		    if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{'Punct_attested'}) {
			$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{'Punct_attested'}=0;
		    }
		    
                    if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{'Punct_attested'}) {
			$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{'Punct_attested'}+=
			$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{'Punct_attested'}
		    }
                    if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{'All_attested'}) {
			$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{'All_attested'}+=
			$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{'All_attested'}
		    }
		    
		    foreach my $item (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}}){
#                        $item - is sign name e.g.LU₂
                        foreach my $subitem (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}}){
                            if ($subitem =~m|_attested$| || $subitem eq 'total') {
                                if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{$subitem}) {
                                    $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{$subitem} = 0;
                                }
                                if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{$subitem}) {
                                    $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{$subitem}
                                    += $x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{$subitem};
                                }
                            }
                            elsif($subitem eq "state"){
                                foreach my $break (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}}){
                                    if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"}) {
                                        $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"} = 0;
                                    }
                                    if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"}) {
                                        $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"} 
                                        += $x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"};
                                    }
#                                    add to parent as well
                                    if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"state"}{$break}{"num"}) {
                                        $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"state"}{$break}{"num"} = 0;
                                    }
                                    if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"}) {
                                        $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"state"}{$break}{"num"} 
                                        += $x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"};
                                    }
                                    $comps->{$PQ}{'lang'}{$lang}[0]{"state"}{$break}{"num"} += $x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"};
                                    $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"state"}{$break}{"num"} += $x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"state"}{$break}{"num"};
            
                                }
                            }
                            elsif($subitem eq "type"){
                                foreach my $syllabic (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}}){
                                    foreach my $totals (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}}){
                                        if ($totals =~m|_attested$| || $totals eq 'total') {
                                            if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{$totals}) {
                                                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{$totals} = 0;
                                            }
                                            if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{$totals}) {
                                                $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{$totals}
						+= $x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"type"}{$syllabic}{$totals};
                                            }
                                        }
                                        if ($totals eq "state") {
                                            foreach my $break (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{"state"}}){
                                                if (!$comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{"state"}{$break}{"num"}) {
                                                    $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{"state"}{$break}{"num"} = 0;
                                                }
                                                if ($x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{$item}{"state"}{$break}{"num"}) {
                                                    $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{"state"}{$break}{"num"} =
                                                    $comps->{$PQ}{'lang'}{$lang}[0]{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{"state"}{$break}{"num"}
                                                    + $x->{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prepost}{"value"}{$item}{"type"}{$syllabic}{"state"}{$break}{"num"};
                                                } 
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }   
                }
            }
            

            
	    if ($x->{'lang'}{$lang}{"category"}{$category}{"value"}) {
		$comps->{$PQ}{'lang'}{$lang}[0] = &reorder(\%{$comps->{$PQ}{'lang'}{$lang}[0]},\%{$x->{'lang'}{$lang}{"category"}{$category}{"value"}}, $category, "value");
	    }
	    if ($x->{'lang'}{$lang}{"category"}{$category}{"type"}) {
		foreach my $type (keys %{$x->{'lang'}{$lang}{"category"}{$category}{"type"}}){
		    $comps->{$PQ}{'lang'}{$lang}[0] = &reorder(\%{$comps->{$PQ}{'lang'}{$lang}[0]},\%{$x->{'lang'}{$lang}{"category"}{$category}{"type"}{$type}{"value"}}, $category, "value", $type,"type");
		}
	    }
        }
#        $signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}
    }
    return $comps;
}

sub reorder{
    my $item = shift;#$comps->{$PQ}{'lang'}{$lang}[0]
    my $match = shift;#$x->{'lang'}{$lang}{"category"}{$category}{"value"}
    my $category = shift;
    my $section = shift;
    my $extra = shift;
    my $extratype = shift;
    my $cat;
    
    if ($extra) {
	$cat = $item->{"category"}{$category}{$extratype}{$extra}{$section};
    }
    else{
	$cat = $item->{"category"}{$category}{$section};
    }
    my %totals = {};
    foreach my $sign (keys %{$match}){
	if (!$totals{'All_attested'}) {
	    $totals{'All_attested'} = 0;
	}
	if (!$totals{'Punct_attested'}) {
	    $totals{'Punct_attested'} = 0;
	}
	if (!$cat->{$sign}{'All_attested'}) {
	    $cat->{$sign}{'All_attested'} = 0;
	}
	if (!$cat->{$sign}{'Punct_attested'}) {
	    $cat->{$sign}{'Punct_attested'} = 0;
	}
	if ($match->{$sign}{'All_attested'}) {
	    $cat->{$sign}{'All_attested'} += $match->{$sign}{'All_attested'};
	    $totals{'All_attested'} +=$match->{$sign}{'All_attested'};
	}
	if ($match->{$sign}{'Punct_attested'}) {
	    $cat->{$sign}{'Punct_attested'} += $match->{$sign}{'Punct_attested'};
	    $totals{'Punct_attested'} +=$match->{$sign}{'Punct_attested'};
	}
	#print "SIGN".$sign."\n";
	foreach my $t (keys %{$match->{$sign}}){
	    #print $t."\n";
	    if ($t eq "state") {#weird punctuation
		foreach my $punctstate (keys %{ $match->{$sign}{"state"}}){
		    if ( $match->{$sign}{"state"}{$punctstate}{"line"}) {
			my $count = scalar @{$match->{$sign}{"state"}{$punctstate}{"line"}};
			
			$item->{"state"}{$punctstate}{"num"} += $count;
			$item->{"category"}{$category}{"state"}{$punctstate}{"num"} += $count;
	
			foreach my $line (@{$match->{$sign}{"state"}{$punctstate}{"line"}}){
			    push(@{$cat->{$sign}{"state"}{$punctstate}{"line"}}, $line);
			}
		    }
		}
	    }
	    
	    if ($t eq "standard") {
		my $standard =  $match->{$sign}{"standard"};
		foreach my $word (keys %{$standard}){
		    foreach my $pos (keys %{$standard->{$word}{"pos"}}){
			foreach my $wordtype (keys %{$standard->{$word}{"pos"}{$pos}{"wordtype"}}){
			    if ($standard->{$word}{"pos"}{$pos}{"wordtype"}{$wordtype}{"gw"}) {
				foreach my $gwname (keys %{$standard->{$word}{"pos"}{$pos}{"wordtype"}{$wordtype}{"gw"}}){
				    my $gwitem =  $standard->{$word}{"pos"}{$pos}{"wordtype"}{$wordtype}{"gw"}{$gwname};
				    foreach my $gwstate (keys %{$gwitem->{"state"}}){
					if (!$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gwname}{"state"}{$gwstate}{"num"}) {
					    $cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gwname}{"state"}{$gwstate}{"num"} = 0;
					}
					$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gwname}{"state"}{$gwstate}{"num"}
					+= $gwitem->{"state"}{$gwstate}{"num"};
					
					$item->{"state"}{$gwstate}{"num"} += $gwitem->{"state"}{$gwstate}{"num"};
					$item->{"category"}{$category}{"state"}{$gwstate}{"num"} += $gwitem->{"state"}{$gwstate}{"num"};
    
					foreach my $writtenWord (keys %{$gwitem->{"state"}{$gwstate}{"writtenWord"}}){
					    if (!$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gwname}{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"}) {
						$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gwname}{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"} = [];
					    }
					    foreach my $line (@{$gwitem->{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"}}){
						push(@{$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"gw"}{$gwname}{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"}}, $line);
					    }
					}
				    }
				}
			    }
			    else{
				#go straight to state
				my $nongw = $standard->{$word}{"pos"}{$pos}{"wordtype"}{$wordtype};
				foreach my $gwstate (keys %{$nongw->{"state"}}){
				    if (!$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"state"}{$gwstate}{"num"}) {
					$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"state"}{$gwstate}{"num"} = 0;
				    }
				    $cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"state"}{$gwstate}{"num"} =
				    $cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"state"}{$gwstate}{"num"}
				    + $nongw->{"state"}{$gwstate}{"num"};
				    $item->{"state"}{$gwstate}{"num"} += $nongw->{"state"}{$gwstate}{"num"};
				    $item->{"category"}{$category}{"state"}{$gwstate}{"num"} += $nongw->{"state"}{$gwstate}{"num"};
    
				    foreach my $writtenWord (keys %{$gwitem->{"state"}{$gwstate}{"writtenWord"}}){
					print $writtenWord;
					if (!$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"}) {
					    $cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"} = [];
					}
					foreach my $line (@{$gwitem->{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"}}){
					    push(@{$cat->{$sign}{"standard"}{$word}{"wordtype"}{$wordtype}{"pos"}{$pos}{"state"}{$gwstate}{"writtenWord"}{$writtenWord}{"line"}}, $line);
					}
				    }
				}
			    }
			}
		    }
		}                      
	    }
	    
	}
    }
    
    if ($extra) {
	$item->{"category"}{$category}{$extratype}{$extra} = \%totals;
	$item->{"category"}{$category}{$extratype}{$extra}{$section} = $cat;
    }
    else{
	$item->{"category"}{$category}{$section} = $cat;
    }
    
    return $item;
}

sub returnComp{
    my $comps = shift;
    
} 
   
1;
