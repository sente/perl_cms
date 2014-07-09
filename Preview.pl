#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

#####################################################
# Preview.pl
#
#  This file contains functions which generate a preview page for a node. The
#  outputFinalizedContent function is used to output the actual content area,
#  since a preview page is so similar to what the page will look like when it is
#  finalized.
#
#####################################################

#####################################################
# Function: previewContentGenerator
# Parameters: file handle to output content to
# Return value: none
# 
# Purpose: Generates a preview version of a node (basically the same as the finalized
#	version, except that hyperlinks link to preview versions of other nodes)
#
sub previewContentGenerator
{
	my $FH = shift;
	
	my %dirinfo = getDirInfo($requestinfo{'node'});
	
	#read content from temp file
	my $tempfile = $config{'datadirpath'} . $config{'temporaryfile'};
	local *TEMP;
	open(TEMP, "<$tempfile");
	readLock(TEMP);
	
	print $FH $_ while (<TEMP>);
	
	unlock(TEMP);
	close(TEMP);
}

#####################################################
# Function: previewSidebarGenerator
# Parameters: file handle to output sidebar to
# Return value: none
# 
# Purpose: Generates the sidebar for a preview page with generateList.
#
sub previewSidebarGenerator
{
	my $FH = shift;
	#print $FH "<ul id=\"sitetree\">";
	print $FH generateList($config{'delimiter'}, \&previewSidebarOpenFunc, \&previewSidebarCloseFunc, \&previewSidebarRecurseTestFunc);
	#print $FH "</ul>";
}

#####################################################
# Function: previewSidebarOpenFunc
# Parameters: see purpose of generateList()
# Return value: string (see purpose of generateList())
# 
# Purpose: Generates the opening of a list item for the preview sidebar.
#
sub previewSidebarOpenFunc
{
	my %dirinfo = %{$_[0]};
	shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;

	my $newline = "\n" . "\t" x $depth;
	my $toreturn = '';

	if (!$dirinfo{'hidden'} && !$dirinfo{'marked_for_deletion'}) #  && $dirinfo{'descendant_leaves_with_content'} == $dirinfo{'descendant_leaves'}
	{
		#my $displayname = escapeForHTML($dirinfo{'display_name'});
		#$toreturn .= "<li><a href=\"" . escapeForHTMLAttribute("$config{'webscriptpath'}?action=preview&node=$treepath") . "\">$displayname</a>";
		$toreturn .= $listfunctions->[0]->(\%dirinfo, $treepath, $depth, $newline);
		if ($recurse)
		{
			$toreturn .= $listfunctions->[1]->(\%dirinfo, $treepath, $depth, $newline);
			#$toreturn .= "<ul$newline>";
			#if ($dirinfo{'has_content'})
			#{
			#	$toreturn .= "<li><a href=\"" . escapeForHTMLAttribute("$config{'webscriptpath'}?action=preview&node=$treepath") . "\">$displayname</a></li$newline>";
			#}
		}
	}
	return $toreturn;
}

#####################################################
# Function: previewSidebarCloseFunc
# Parameters: see purpose of generateList()
# Return value: string (see purpose of generateList())
# 
# Purpose: Generates the opening of a list item for the preview sidebar.
#
sub previewSidebarCloseFunc
{
	my %dirinfo = %{$_[0]}; shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;

	my $toreturn;
	my $newline = "\n" . "\t" x ($depth-1);

	if (!$dirinfo{'hidden'} && !$dirinfo{'marked_for_deletion'}) #  && $dirinfo{'descendant_leaves_with_content'} == $dirinfo{'descendant_leaves'}
	{
		if ($recurse)
		{
			$toreturn .= $listfunctions->[2]->(\%dirinfo, $treepath, $depth, $newline);
		}
		$toreturn .= $listfunctions->[3]->(\%dirinfo, $treepath, $depth, $newline);
		#if ($depth == 0)
		#{
		#	return "";
		#}
		#elsif ($recurse)
		#{
		#	return "</ul$newline></li$newline>";
		#}
		#else
		#{
		#	return "</li$newline>";
		#}
	}
	return $toreturn;
}
#####################################################
# Function: previewSidebarRecurseTestFunc
# Parameters: see purpose of generateList()
# Return value: boolean: should we recurse into this node?
# 
# Purpose: Determines whether a node's contents should be placed into the preview 
#	sidebar.
#
sub previewSidebarRecurseTestFunc
{
	my $dirinforef = shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	if ($$dirinforef{'hidden'} || $$dirinforef{'marked_for_deletion'} || isLeafNode($treepath)) #  || $$dirinforef{'descendant_leaves_with_content'} != $$dirinforef{'descendant_leaves'}
	{
		return 0;
	}
	return 1;
}

1;
