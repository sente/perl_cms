#!C:\perl\bin\perl\
use Data::Dumper;

our %dbconfig = (
	'dbdir'		=> 	"$machine{'apachedir'}sites$machine{'slash'}cms$machine{'slash'}htdocs$machine{'slash'}databases$machine{'slash'}dbs$machine{'slash'}",
	'definitions'	=> 	'definitions.txt',
	'content'		=> 	'content.txt',
	'template'		=> 	'template.txt',
	'recordtemplate'	=>	'recordtemplate.txt',
	'tokenpattern'	=> 	qr/<!--\s*?#(\w*)\s*?-->/,
	'systemslash'	=> 	$machine{'slash'},
	'lockfiles'		=> 	1,
);

$AND = 0;
$OR = 1;
$FILTER = 2;

##############################################
sub outputResults
{
	my $FH = shift;
	my @args = @_; # remaining arguments are passed into tokenfunctions
	
	open (FORM, "<$params{'dbdir'}$dbconfig{'template'}");
	readLock(\*FORM);
	
	local $/;
	undef $/;
	my $form = <FORM>;
	
	while ($form =~ /((?:.|\n)*?)(<!--#(\w+)\s*-->|\Z)/mg)
	{
		print $FH $1;
		if ($2)
		{
			$tokenfunctions{$3}->($FH, @args);
		}
	}
	
	unlock(\*FORM);
	close (FORM);
}
##############################################
sub getContent
{
	my $file = shift;
	
	local*FH;
	open(FH, "<$file");
		
	my @lines = ();
	my $record;
	while($record = <FH>)
	{
		chomp($record);
		print "$record\n";
		push @lines, [split(/\t/, $record)];
	}
	return @lines;
}
##############################################
sub getDefinitions
{
	my $file = shift;
	
	local *FH;
	open(FH, "<$file");
	
	my %definitions = ();

	local $/;
	undef $/;
	
	chomp(my $text = <FH>);
	
	my $i=0;
	$text =~ tr/\n/ /;
	
	while($text =~ /(\w+)\s*{\s+(.*?)\s+}/g)
	{
		my $name = $1;
		
		my %data = ();
		$data{'name'} = $name;
		$data{'column'}= $i++;
		
		my $datastr = $2;
		while ($datastr =~ /(\w+)\s*=\s*(\w+)/g)
		{
			$data{$1} = $2;
		}
		$definitions{$name} = \%data;		
	}
	close(FH);
	
	getLookups(\%definitions);
	
	return \%definitions;
}
##############################################

sub getRawData
{
	my $file = shift;
			
	local *FH;
	open(FH, "<$file");

	my @rawdata = ();
	
	my $line;
	while($line = <FH>)
	{
		chomp($line);
		push @rawdata, [split(/\t/, $line)];
	}
	close(FH);
	return \@rawdata;
}
##############################################

sub getLookups
{
	my $hashref = shift;	
	foreach my $key (keys %$hashref)
	{
		if($hashref->{$key}->{'type'} eq "lookup")
		{
			$hashref->{$key}->{'lookup'} = getLookupTable($dbconfig{'dbdir'} . $params{'db'} . $dbconfig{'systemslash'} . $key . ".lookup");
		}
	}
}

sub getLookupTable
{
	my $file = shift;
	
	if(! -e $file) {	#file does not exist, error
		return {};
	}
	
	local $/;
	undef $/;
	local *FH;
	
	open(FH, "<$file");
	my $text = <FH>;
	close(FH);
	
	return {split(/\n|\t/, $text)};
}

##############################################
sub sendResults
{
	my $FH = shift;
	my $templatefile = shift;
	my $rawdataref = shift;
	my $defhashref = shift;
	
	local *HANDLE;
	open(HANDLE, "<$templatefile");

	local $/;
	undef $/;
	
	my $inresults =0;
	my $line = <HANDLE>;
	
	my $htmlref = [split(/$dbconfig{'tokenpattern'}/, $line)];
	
	foreach my $rowref (@$rawdataref)
	{
		printRow($FH, $rowref, $htmlref, $defhashref);
	}
}
##############################################
sub printRow
{
	my $FH = shift;
	my $rowref = shift;
	my $htmlref = shift;
	my $defhashref= shift;
	
	for(my $i = 0; $i<scalar(@$htmlref); $i++)
	{
		if($i%2){
			if ($recordtokenfunctions{$htmlref->[$i]})
			{
				$recordtokenfunctions{$htmlref->[$i]}->($FH, $rowref, $defhashref);
			}
			else
			{
				if($defhashref->{$htmlref->[$i]}->{'type'} eq 'lookup'){	
					print $FH &escapeForHTML($defhashref->{$htmlref->[$i]}->{'lookup'}->{$rowref->[$defhashref->{$htmlref->[$i]}->{'column'}]});
				}
				else{
					print $FH &escapeForHTML($rowref->[$defhashref->{$htmlref->[$i]}->{'column'}]);
				}
			}
		}
		else{
			print $FH $htmlref->[$i];
		}
	}
}

my %operators = (
	'>='				=> sub { return $_[0] >=	$_[1]; },
	'<='				=> sub { return $_[0] <=	$_[1]; },
	'>'				=> sub { return $_[0] >	$_[1]; },
	'<'				=> sub { return $_[0] <	$_[1]; },
	'=='				=> sub { return $_[0] ==	$_[1]; },
	'!='				=> sub { return $_[0] !=	$_[1]; },
	'ne'				=> sub { return $_[0] ne	$_[1]; },
	'eq'				=> sub { return $_[0] eq	$_[1]; },
	'=~'				=> sub { return $_[0] =~ 	/$_[1]/;},
	'!~'				=> sub { return $_[0] !~ 	/$_[1]/;},
	'firstletterequals'	=> sub {return uc(substr($_[0], 0, 1)) eq uc($_[1]);},
	);

sub applyFilters
{
	my $rawdataref = shift;
	my $unparsedfiltertreeref = shift;
	my $defhashref = shift;
	
	my $filtertreeref = createFilterTree($unparsedfiltertreeref, $defhashref);
	
	$rawdataref = filter($rawdataref, $defhashref, $filtertreeref);
	
	return $rawdataref;
}

sub createFilterTree
{
	my $filtertreeref = shift;
	my $defhashref = shift;
	
	my $toreturn = [];
	$toreturn->[0] = $filtertreeref->[0]; #copy AND, OR, or FILTER value
	
	if ($filtertreeref->[0] == $FILTER)
	{
		$toreturn->[1] = makeFilter(@{$filtertreeref->[1]}, $defhashref);
	}
	else #AND or OR, so recursively create each node
	{
		for (my $i = 1; $i < scalar(@$filtertreeref); $i++)
		{
			$toreturn->[$i] = createFilterTree($filtertreeref->[$i], $defhashref);
		}
	}
	
	return $toreturn;
}

sub filter
{
	my $rawdataref = shift;
	my $defhashref = shift;
	my $filtertreeref = shift;
	
	my @toreturn = ();
	foreach my $rowref (@$rawdataref)
	{
		if(applyFilterTree($rowref, $filtertreeref))
		{
			push @toreturn, $rowref;		
		}
	}
	return [@toreturn];
}
sub applyFilterTree
{
	my $rowref = shift;
	my $filtertreeref = shift;
	
	if ($filtertreeref->[0] == $FILTER)
	{
		return $filtertreeref->[1]->($rowref);
	}
	elsif ($filtertreeref->[0] == $OR)
	{
		for (my $i = 1; $i < scalar(@$filtertreeref); $i++)
		{
			if (applyFilterTree($rowref, $filtertreeref->[$i])) {
				return 1;
			}
		}
		return 0;
	}
	else # AND
	{
		for (my $i = 1; $i < scalar(@$filtertreeref); $i++)
		{
			if (!applyFilterTree($rowref, $filtertreeref->[$i])) {
				return 0;
			}
		}
		return 1;
	}
}


sub makeFilter
{
	my $columnname = shift;
	my $symbol = shift;
	my $value = shift;
	my $defhashref = shift;
	
	my $column = $defhashref->{$columnname}->{'column'};
	
	my $func =  $operators{$symbol};
	
	return sub {
		my $rowref = shift;
		return $func->($rowref->[$column], $value);
	};
}
######################################
######################################

sub applySort
{
	my $dataref = shift;
	my $sortparamsref = shift;
	my $defhashref = shift;
	
	my @sortfuncs;
	my @comparefuncs;
	
	my $numsortparams = scalar(@$sortparamsref);
	
	for(my $i=0; $i<$numsortparams; $i++)
	{
		my $j = $i; # make local copy of $i that doesn't change
		
		my $column = $defhashref->{$sortparamsref->[$j]->{'field'}}->{'column'};
		
		if ($defhashref->{$sortparamsref->[$j]->{'field'}}->{'type'} eq 'string' && !$sortparamsref->[$j]->{'searchexpression'})
		{
			$comparefuncs[$i] = sub { # alphabetic
				return uc($_[0]) cmp uc($_[1]);
			}
		}
		elsif ($defhashref->{$sortparamsref->[$j]->{'field'}}->{'type'} eq 'string')
		{
			my (@ar1, @ar2, $aval, $bval);
			$comparefuncs[$i] = sub { # string occurance count
				$aval = scalar(@ar1 = $_[0] =~ /$sortparamsref->[$j]->{'searchexpression'}/g);
				$bval = scalar(@ar2 = $_[1] =~ /$sortparamsref->[$j]->{'searchexpression'}/g);
				return $aval <=> $bval;
			}
		}
		else
		{
			$comparefuncs[$i] = sub { # numeric
				return $_[0] <=> $_[1];
			}
		}
		$sortfuncs[$i] = sub {
			my $aval = $a->[$column];
			my $bval = $b->[$column];
						
			my $returnval = $sortparamsref->[$j]->{'order'} * ($comparefuncs[$j]->($aval, $bval));
				
			if (!$returnval && $j < $numsortparams-1)
			{
				return $sortfuncs[$j+1]->();
			}
			else {return $returnval;}
		}
	}
	
	my @toreturn = sort {$sortfuncs[0]->();} @$dataref;
	
	return \@toreturn;
}

#####################################################
#	creates a set of filters to be ANDed within the params hash
#
sub getFiltersFromSearchTerms
{
	my $terms =~ s/[^\w\s"\-]//g; #" Important!
	
	my @tempfilters;
	my @searchterms;
	my @negativesearchterms;
	my $termsnegativeregexp;
	my $termsregexp;
	
	while ($terms =~ m/(-?".+?"|[\w\-]+)/g)
	{
		my $term = $1;
		my $negativeterm = 0;
		if ($term =~ /^-/)
		{
			$negativeterm = 1;
		}
		$term =~ s/^-?"?\s*(.*?)\s*"?$/$1/g;

		my $regex = "\\b";
		while ($term =~ /([\w\-]+)(\s+)?/g)
		{
			$regex .= escapeRegexStr($1);
			if ($2)
			{
				$regex .= "\\s+";
			}
		}
		$regex .= "\\b";
				
		if ($negativeterm)
		{
			push @negativesearchterms, $regex;
		}
		else
		{
			push @searchterms, $regex;
		}
	}
	
	$termsregexp = join '|', @searchterms;
	foreach my $term (@searchterms)
	{
		push @termfilters, [$FILTER, ['Caption', '=~', qr/$term/i]];
	}
	$termsnegativeregexp = join '|', @negativesearchterms;
	
	if ($termsnegativeregexp)
	{
		push @termfilters, [$FILTER, ['Caption', '!~', qr/$termsnegativeregexp/i]];
	}
	return @tempfilters;
}
1;