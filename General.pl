#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

=pod
package General;
require Exporter;
our @ISA	= qw(Exporter);
our @EXPORT = qw(
	&slurp
	&cleanupPath
	&makeSystemPath
	&makeWebPath
	&escapeRegexStr
	);
use Node;
use Config;
=cut

#####################################################
# General.pl
#
#  This file contains various small functions which do useful things.
#  Many of them manipulate strings and convert between different "types" of 
#  strings (for instance, makeSystemPath takes a treepath of a node and 
#  returns the path to the node's corresponding system folder.)
#
#####################################################

#####################################################
# Function: recurseTree
# Parameters: node to start recursion at, reference to array of delimiters
# Return value: an array of array references of everything within the node, relative to the node.
#	There is one entry in this array for each delimiter passed in the second argument.
#	Each entry is identical except that the paths in them use the corresponding delimiter.
# 
# Purpose: gets a list of all files and directories within a node, not counting the node itself.
#		All of these paths are relative to the starting node.
#
sub recurseTree
{
	my @ar = ();
	recurseTreeHelper(makeSystemPath(shift), shift, [],  \@ar);
	return @ar;
}
#####################################################
# Function: recurseTreeSystemPath
# Parameters: see recurseTree()
# Return value: see recurseTree()
# 
# Purpose: Same as recurseTree(), but the first argument is a system path 
#		instead of a treepath.
#
sub recurseTreeSystemPath
{
	my @ar = ();
	recurseTreeHelper(shift, shift, [],  \@ar);
	return @ar;
}
#####################################################
# Function: recurseTreeHelper
# Parameters: current node in the recursion,
#		the reference to an array of delimiters,
#		a reference to an array of paths, each one corresponding to the current node
#			in the recursion, using the corresponding delimiter
#		a reference to an array of array references; each array reference corresponds
#			to one of the delimiters, and is the current list of paths being built
#			for that delimiter.
# Return value: none
# 
# Purpose: Implements the recursion for recurseTree.
#
sub recurseTreeHelper
{
	my $rootpath = shift;			# IM A SCALAR!!! i make life simple
	my $delimitersref = shift;		# [delimiter1,delimiter2,etc]
	my $pathsref = shift;			# [/path/to/node/, \path\to\node\]
	my $arrayrefsref = shift;		# [  []   []  ]
								 

	opendir(DIR, $rootpath);
	my @files = readdir(DIR);
	closedir(DIR);
	
	foreach my $f (@files)
	{
		next if $f eq ".";
		next if $f eq "..";
		if (-d $rootpath.$f)
		{
			my @newpathrefs = @$pathsref;
			for(my $i =0; $i<scalar(@$delimitersref); $i++)
			{
				push @{${$arrayrefsref}[$i]}, ${$pathsref}[$i] . $f . ${$delimitersref}[$i];
				$newpathrefs[$i] .= $f . ${$delimitersref}[$i];
			}
			recurseTreeHelper($rootpath.$f.$config{'systemslash'}, $delimitersref, \@newpathrefs, $arrayrefsref);
		}
		else
		{
			for(my $i =0; $i<scalar(@$delimitersref); $i++)
			{
				push @{${$arrayrefsref}[$i]}, ${$pathsref}[$i] . $f;
			}
		}
	}
}
#####################################################
# Function: outputStatus
# Parameters: none
# Return value: none
# 
# Purpose: Prints an HTML paragraph containing the error text for the current
#		error. Doesn't do anything if there has been no error.
#
sub outputStatus
{
	if ($STATUS_FLAG)
	{
		print "<p class=\"error\">Error: $ERROR_CODE[$STATUS_FLAG]";
		if ($STATUS_FLAG == 17)
		{
			print ": " . $q->cgi_error;
		}
		else {
			print ".";
		}
		print "</p>\n\n";
	}
}
#####################################################
# Function: slurp
# Parameters: file path
# Return value: contents of file
# 
# Purpose: Reads a file and returns its contents.
#
sub slurp
{
#	use Cwd;
#	my $currentDir = cwd;

	my $file = shift;
	local *FH;
	open(FH, "<$file") or die "Couldn't open $file while in Slurp()\n$!\n";
	readLock(FH);
	local $/;
	undef $/;
	my $slurp = <FH>;
	unlock(FH);
	close(FH);
	return $slurp;
}
#####################################################
# Function: cleanupPath
# Parameters: user-inputted treepath to node
# Return value: cleaned-up treepath
# 
# Purpose: Attempts to get a treepath out of a node that the user may have 
#		entered manually.
#
#		Right now, this function does nothing. We are not currently forgiving
#		the user for imprecice input.
#
sub cleanupPath # doesn't do anything useful yet
{
	return shift;
	#my $arg = shift;
	#$arg =~ s#\/#$config{"systemslash"}#g;			#replace all /'s with \'s
	#if($arg !~ /$config{"systemslashreg"}$/)			#make sure it ends with a system-slash
	#{
	#	$arg.=$config{"systemslash"};
	#}
	#$arg =~ s/^$config{"systemslashreg"}//;			#remove system-slash at beginning, if present
	#return $arg;
}
#####################################################
# Function: makeFinalURL
# Parameters: treepath to a node or a file within a node
# Return value: URL to the given node/file relative to the web root
# 
# Purpose: Generates a URL to a file or node in the finalized web site.
#
sub makeFinalURL
{
	$_ = shift;
	s/$config{'escapeddelimiter'}/\//g;
	$_ = substr $_, 1;
	return $config{'webfinalizedroot'} . $_;
}
#####################################################
# Function: makeRemoteFinalURL
# Parameters: treepath to a node or a file within a node
# Return value: URL to the given node/file relative to the remotewebfinalizedroot
# 
# Purpose: Generates a remote URL to a file or node in the finalized web site.
#
sub makeRemoteFinalURL
{
	$_ = shift;
	s/$config{'escapeddelimiter'}/\//g;
	$_ = substr $_, 1;
	return $config{'remotewebfinalizedroot'} . $_;
}
#####################################################
# Function: makePreviewURL
# Parameters: treepath to a node or a file within a node
# Return value: URL to preview the given node/file relative to the web root
# 
# Purpose: If the treepath is to a node, returns a URL which will preview that node.
#		Otherwise, a URL to the file within the CMS root folder is returned.
#
sub makePreviewURL
{
	my $url = shift;
	if($url =~ /$config{'escapeddelimiter'}$/) {
		return "$config{'webscriptpath'}?action=preview&node=$url"; # ampersand is purposely not escaped; the callee must escape the URL.
	}
	else {
		$url =~ s/$config{'escapeddelimiter'}/\//g;
		return $config{'webcmscontentroot'} . substr $url, 1;
	}
}
#####################################################
# Function: makeSystemPath
# Parameters: treepath to a node or file
# Return value: system path to the node or file
# 
# Purpose: Converts a treepath into a system path to the node or file.
#
sub makeSystemPath
{
	$_ = shift;
	s/$config{'escapeddelimiter'}/$config{'systemslash'}/g;
	return $config{'cmscontentroot'}.substr($_, 1);
}
#####################################################
# Function: makeFinalizedSystemPath
# Parameters: treepath to a node or file
# Return value: system path to the finalized version of the node or file
# 
# Purpose: Converts a treepath into a system path to the finalized node or file.
#
sub makeFinalizedSystemPath
{
	$_ = shift;
	s/$config{'escapeddelimiter'}/$config{'systemslash'}/g;
	return $config{'finalizedroot'}.substr($_, 1);
}

#####################################################
# Function: escapeRegexStr
# Parameters: string to be escaped
# Return value: equivalent string that is ready to be interpolated in a regular expression
# 
# Purpose: Takes a normal string and escapes the characters necessary to make 
#		it possible for the string to be interpolated as part of a regular expression.
#
sub escapeRegexStr
{
	$_ = shift;
	s#([\\\|\(\)\[\]\{\}\^\$\*\+\?\.\-])#\\$1#g;
	return $_;
}

#####################################################
# Function: getAllFilesInFolder
# Parameters: folder
# Return value: array of files in folder
# 
# Purpose: Gets an array of all of the files that are in a folder. It is assumed that
#		the folder has no subfolders.
#
sub getAllFilesInFolder
{
	my $folder = shift;
	
	my @toreturn = ();
	
	opendir(DIR, $folder) or return @toreturn;
	
	my @files = readdir(DIR);
	
	foreach my $file (@files)
	{
		next if $file eq ".";
		next if $file eq "..";
		push @toreturn, $file;
	}
	close DIR;
	return @toreturn;
}

#####################################################
# Function: webPathToSystemPath
# Parameters: relative URL
# Return value: system path to the file
# 
# Purpose: Takes a URL (such as "/a/b/c.html") and returns the system path to the file it
#		links to. This is used when parsing SSI.
#
sub webPathToSystemPath
{
	my $webpath= shift;
	
	my @urlaliases=();
	if($requestinfo{'action'} eq "preview"){
		@urlaliases = @{$config{'previewurlaliases'}};
	}
	else{
		@urlaliases = @{$config{'urlaliases'}};
	}
	
	$webpath =~ s/\//$config{'systemslash'}/g;
	for (my $i=0; $i < scalar(@urlaliases); $i += 2)
	{
		my $regex = $urlaliases[$i];
		$regex =~ s/\//$config{'systemslash'}/g;
		$regex = escapeRegexStr($regex);
		$webpath =~ s/^$regex/$urlaliases[$i+1]/;
	}
	return $webpath;
}

#####################################################
# Function: makeActualURL
# Parameters: user-inputted URL
# Return value: valid URL
# 
# Purpose: Takes a URL that the user has input and returns a URL that is safe to use in
#		a hyperlink.
#		For instance, "www.blah.com" is changed into "http://www.blah.com/"
#		When a treepath is used, the URL to the finalized version of the node or 
#		file is returned.
#
sub makeActualURL
{
	my $url = shift;
	
	if ($url =~ /$dataTypeRegexes{'treepath'}/)
	{
		if($requestinfo{'action'} eq "preview")
		{
			$url = makePreviewURL($url);
		}
		else
		{
			$url = makeFinalURL($url);
		}
	}
	else
	{
		if ($url =~ /^www\./)
		{
			$url = "http://$url";
		}
		if($url =~ /^\w+:\/\/[\w\.-]+$/) # "http://www.stuff.com" -> "http://www.stuff.com/"
		{
			$url = $url . "/";
		}
	}
	return $url;
}

#####################################################
# Function: padWith0s
# Parameters: required length of number, number (base 10)
# Return value: same number preceeded with zeroes to make it the specified length
# 
# Purpose: Makes a number a specified length by padding it with zeroes.
#
sub padWith0s
{
	my $numzeroes = shift;
	my $number = shift;
	return "0" x ($numzeroes - int(log($number)/log(10)) - 1) . $number;
}

#####################################################
# Function: escapeForHTML
# Parameters: string to escape
# Return value: HTML-safe string
# 
# Purpose: Escapes ampersands, less-than signs, and greater-than signs in a string
#		to make the string safe to insert in an HTML document. For strings which 
#		will be used as HTML attributes, use escapeForHTMLAttribute instead.
#
sub escapeForHTML
{
	$_ = shift;
	s/&/&amp;/g;
	s/</&lt;/g;
	s/>/&gt;/g;
	#$_ = encode_entities($_);
	return $_;
}
#####################################################
# Function: unescapeForHTML
# Parameters: HTML-safe string
# Return value: string without escaped characters
# 
# Purpose: Undoes the effects of escapeForHTML.
#
sub unescapeForHTML
{
	$_ = shift;
	s/&lt;/</g;
	s/&gt;/>/g;
	s/&amp;/&/g;
	#$_ = decode_entities($_);
	return $_;
}
#####################################################
# Function: escapeForHTMLAttribute
# Parameters: string to escape
# Return value: HTML-Attribute-safe string
# 
# Purpose: Same as escapeForHTML, but also escapes quote characters so that a 
#		string can be safely used as an HTML attribute.
#
sub escapeForHTMLAttribute
{
	$_ = escapeForHTML(shift);
	s/"/&quot;/g; #"
	return $_;
}

#####################################################
# Function: escapeForCDATA
# Parameters: string to escape
# Return value: CDATA-safe string
# 
# Purpose: Escapes the character sequence "]]>" to make a string safe for
#		insertion into a CDATA section of an XML document. The string must
#		later be unescaped with unescapeForCDATA.
#
sub escapeForCDATA
{
	$_ = shift;
	s/]]/]]0/g;
	s/]]>/]]1/g;
	return $_;
}
#####################################################
# Function: unescapeForCDATA
# Parameters: CDATA-safe string
# Return value: original string
# 
# Purpose: Takes a string passed through escapeForCDATA and unescapes it, 
#		getting the original string back.
#
sub unescapeForCDATA
{
	$_ = shift;
	s/]]1/]]>/g;
	s/]]0/]]/g;
	return $_;
}


sub readLock {
	if ($config{'lockfiles'}) {
		flock(shift, 1); # LOCK_SHared
	}
}
sub writeLock {
	if ($config{'lockfiles'}) {
		flock(shift, 2); # LOCK_EXplicit
	}
}
sub unlock {
	if ($config{'lockfiles'}) {
		flock(shift, 8); # LOCK_UNlock
	}
}

1;
