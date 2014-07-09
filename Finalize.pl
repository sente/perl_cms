#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

#####################################################
# Finalize.pl
#
#  This file contains functions that relate to finalization.
#  The first few functions are related to the finalization of nodes and their content, 
#  while the last bunch are related to the output of the finalized sidebar file,
#  which is included (via SSI) into all finalized pages.
#
#####################################################

# This hash is used in the call to generatePage when we're generating a finalized page
my %finalizetokenhash = (
	'CONTENT' => \&finalizedContentGenerator,
	'SIDEBAR' => \&finalizedSidebarIncludeGenerator,
	'TITLE'	=> \&titleGenerator,
);

#####################################################
# Function: finalizeNode
# Parameters: path of the node to finalize,
#	whether or not to recurse and finalize its descendants (boolean)
# Return value: none
# 
# Purpose: Finalizes a node, making a copy of it in the actual website.
#		If a node is marked for deletion, it deletes it from both the CMS and 
#		the main website. Otherwise, the node's index page is generated
#		with generatePage, and placed on the website.
#
sub finalizeNode
{
	my $node = shift;
	my $recurse = shift;
	
	my %dirinfo = getDirInfo($node);

	my $finalizedsystempath = makeFinalizedSystemPath($node);

	# marked for deletion nodes are simply deleted
	if ($dirinfo{'marked_for_deletion'})
	{
		# get an array of everything inside the node
		my @patharrays = recurseTreeSystemPath($finalizedsystempath, [$config{'systemslash'}]);
		my @files = @{$patharrays[0]};

		# delete everything inside the node
		foreach(reverse @files)
		{
			my $filepath = $finalizedsystempath.$_;
			if(-d $filepath)
			{
				rmdir($filepath);
			}
			elsif(-e $filepath)
			{
				unlink($filepath);
			}
			else
			{
				die "$!\n when deleting in finalizeNode(): $filepath is neither a directory nor a file; (THIS IS SERIOUS!!!)\n";
			}
		}
		# remove the node's directory
		rmdir($finalizedsystempath);
		
		# now that we've deleted the finalized version of the node, let's delete the cms's version
		deleteNode($node);

		# die if we failed
		if ($STATUS_FLAG) {
			return 0;
		}
	}
	else
	{
		# make node's directory if it doesn't exist
		if (!(-d $finalizedsystempath))
		{
			mkdir $finalizedsystempath or die "$!\n when creating directory $finalizedsystempath in function finalizeNode() (THIS IS SERIOUS!!!)\n";
		}

		# copy node's content
		my $nodeindex = makeFinalizedSystemPath($node).$config{'indexfile'};
		if ($dirinfo{'has_content'})
		{
			my $templatefile	= $config{'contenttemplatespath'}.$dirinfo{'content_template'};
			my $contentfile		= makeSystemPath($node).$config{'contentfile'};
			
			local *TEMP;
			my $tempfile = $config{'datadirpath'} . $config{'temporaryfile'};
			
			open(TEMP, ">$tempfile");
			writeLock(TEMP);
			outputFinalizedContent(TEMP, $templatefile, $contentfile);
			unlock(TEMP);
			close(TEMP);
			
			if (!$STATUS_FLAG) # content generated successfully?
			{
				local *FH;
				open(FH, ">$nodeindex") or die "Couldn't open $nodeindex in function finalizeNode(): $! (THIS IS SERIOUS!!!\n" ;
				writeLock(FH);
				generatePage(\*FH, $config{'pagetemplatespath'} . $dirinfo{'page_template'}, \%finalizetokenhash, $node);
				unlock(FH);
				close (FH);
				
				chmod 0775, $nodeindex; # enable SSI on our server
			}
			else {
				return 0;
			}
		}
		elsif(-e $nodeindex) #node no longer has content, delete index file now
		{
			unlink($nodeindex);		
		}
		
		#copy node's files (images, css, other, etc...)
		
		foreach my $filetype (@fileTypes)
		{
			my $olddirpath = makeSystemPath($node . $fileTypeFolders{$filetype});
			my $newdirpath = makeFinalizedSystemPath($node . $fileTypeFolders{$filetype});
			my @files = sort(&getAllFilesInFolder($olddirpath));
			if (scalar(@files))
			{
				# make directory if necessary
				if (!(-d $newdirpath))
				{
					mkdir $newdirpath or die "$!\n when creating directory $newdirpath in function finalizeNode() (THIS IS SERIOUS!!!)\n";
				}
				foreach $file (@files)
				{
					#print "\n\nCopying $olddirpath$config{'systemslash'}$file to $newdirpath$config{'systemslash'}$file";
					copy($olddirpath 	. $config{'systemslash'} . $file,
						$newdirpath 	. $config{'systemslash'} . $file);
				}
			}
		}

		# update node's finalized-related properties
		$dirinfo{'has_been_finalized'} = 1;
		$dirinfo{'had_content_when_finalized'} = $dirinfo{'has_content'};

#		$dirinfo{'title'} = "Managed Care Analysis";
#		#note: you must finalize a node twice for this hack to take effect


		writeDirInfo($node, \%dirinfo);

		# finalize children if recursion is demanded
		if($recurse)
		{
			foreach my $child (getChildren($node))
			{
				if (!finalizeNode("$node$child$config{'delimiter'}", 1)) {
					return 0;
				}
			}
		}
	}
	return 1;
}

#####################################################
# Function: finalizedContentGenerator
# Parameters: file handle to output finalized content to, node being worked with
# Return value: none
# 
# Purpose: Generates the content of a page being finalized. Uses the
# outputFinalizedContent function.
#
sub finalizedContentGenerator
{
	my $FH = shift;
	my $node = shift;
	
	my %dirinfo = getDirInfo($node);
	
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
# Function: finalizedSidebarIncludeGenerator
# Parameters: file handle to output the sidebar to
# Return value: none
# 
# Purpose: Simply outputs an SSI include which will include the finalized sidebar file.
#
sub finalizedSidebarIncludeGenerator
{
	my $FH = shift;
	print $FH "<!--#include virtual=\"$config{'includefiles'}$config{'sidebarincludefile'}\"-->";
}

#####################################################
# Function: finalizeSidebar
# Parameters: node which is being finalized;
#	whether or not its descendants are being finalized (boolean)
# Return value: none
# 
# Purpose: Updates the appropriate part of the commented sidebar file with the
#		new sidebar contents. The commented sidebar file has the following 
#		syntax which makes use of HTML comments:
#
#		Each node starts with <!--#{/path/to/node/}-->
#		and ends with <!--#/{/path/to/node/}--> (note the slash).
#
#		Within these is an <!--#IFCHILDREN--> ... <!--#/IFCHILDREN--> block
#		whose contents are only output to the final sidebar file iff the node has 
#		children.
#
#		Within that is a <!--#CHILDREN--> ... <!--#/CHILDREN{/path/to/node}--> block
#		whose contents are children nodes. The closing of the block contains the path 
#		to the current node to make parsing easier.
#
#		Once the commented sidebar file has been output, the final sidebar file is
#		generated. In the final sidebar file, the weird comments are removed, and
#		contents of IFCHILDREN blocks are only output when there are actually 
#		children between the corresponding CHILDREN blocks.
#
#		This weird commented sidebar file is used because otherwise, finalizing 
#		*partial* areas of the site would be an impossibility when it comes to the sidebar.
#
#		General format of a node:
#		
#		<!--#{/path/to/node/}-->
#			blah blah blah
#			<!--#IFCHILDREN-->
#				blah blah blah
#				<!--#CHILDREN-->
#					...children here, one after another...
#				<!--#/CHILDREN{/path/to/node/}-->
#				blah blah blah
#			<!--#/IFCHILDREN-->
#			blah blah blah
#		<!--#/{/path/to/node/}-->
#
#		We should have used XML.
#
sub finalizeSidebar
{
	my $node = shift;
	my $recurse = shift;
	
	# commented sidebar file path
	my $sidebarfile = $config{'datadirpath'}.$config{'commentedsidebar'};
	local *FH;

	my $sidebartext;
	my $sidebaropentext;
	my $sidebarclosetext;

	# if this node doesn't exist (which means we're finalizing a node which had been marked for deletion and was just deleted), remove it entirely from the sidebar
	if (!(-d makeSystemPath($node)))
	{
		$sidebartext = "";
		$recurse = 1;
	}
	# if we're finalizing recursively, get the entire portion of the list that this node and it's children make up
	elsif ($recurse)
	{
		$sidebartext = generateList($node, \&finalizedSidebarOpenFunc, \&finalizedSidebarCloseFunc, \&finalizedRecurseTestFunc);
	}
	# if we're not finalizing recursively, just get the opening and closing parts of this node
	else
	{
		my @array = $node =~ /($config{'delimiter'})/g;
		my $depth = scalar(@array) - 1;
		
		my %dirinfo = getDirInfo($node);
		
		#send 1 for numchildren: the function doesn't care about how many children it has (and rightly shouldn't).
		#send 1 for recurse: even though we're not recursing, we want all of the code as though we are.
		# it doesn't matter anyway, since these functions don't use those parameters.
		
		$sidebaropentext = finalizedSidebarOpenFunc(\%dirinfo, $depth, 1, $node, 1);
		$sidebarclosetext = finalizedSidebarCloseFunc(\%dirinfo, $depth, 1, $node, 1);
	}

	# generate initial commented sidebar file if necessary
	if(!(-e $sidebarfile) || !(-s $sidebarfile))
	{
		generateInitialSidebarFile();
	}
	# open the commented sidebar file
	open(FH, "<$sidebarfile") or die "cannot open $sidebarfile, but it's there?! in finalizeSidebar():\n$!";
	readLock(FH);
	
	# grab the commented sidebar file's contents
	my @ar = <FH>;
	my $oldsidebar = join ('', @ar);
	unlock(FH);
	close FH;
	
	# start writing
	open (FH, ">$sidebarfile");
	writeLock(FH);
	my $regexnode = escapeRegexStr($node);
	
	# find the place in the commented sidebar where this node begins
	# only enter this if block if the node was already in the commented sidebar
	if($oldsidebar =~ m/<!--#\{$regexnode\}-->/g)
	{
		# replace the node's old contents with the new ones
		
		# print everything before this node
		print FH $`;
		
		# if recursing, print this node and all of its children
		if ($recurse)
		{
			print FH $sidebartext;
		}
		# if not recursing, print everything before this node's children, copy the node's children from the old commented sidebar, 
		# and then copy everything after this node's children
		else
		{
			$oldsidebar =~ m/<!--#CHILDREN-->((.|\n)*?)<!--#\/CHILDREN\{$regexnode\}-->/mg;
			print FH $sidebaropentext, $1, $sidebarclosetext;
		}
		# find the end of this node
		$oldsidebar =~ m/<!--#\/\{$regexnode\}-->/g;
		# print everything after the end of this node
		print FH $';
	}
	# if the node was *not* already in the commented sidebar,,,
	else
	{
		# ...we must insert it inside its parent, which is guaranteed to exist by the logic of finalization allowances

		# start regex searching at beginning of old sidebar
		pos($oldsidebar) = 0;
		
		# get parent node's name
		my $parentnode = getParentNode($node);
		
		# check if node is the root
		my $isroot = ($parentnode eq '');

		my $regexparentnode = escapeRegexStr($parentnode);
		
		# if we can find the node's parent in the sidebar
		if($isroot || $oldsidebar =~ m/<!--#\{$regexparentnode\}-->/g)
		{
			# determine what comment to insert this node after in the sidebar file; store in $regex
			my $regex;
			if ($isroot)
			{
				# root is always inserted after <!--#ROOT-->
				$regex = qr/<!--#ROOT-->/;
			}
			else
			{
				# find the previous sibling (ignoring ones which haven't been finalized)
				my @siblings = getChildren($parentnode);
				my $foundself = 0;
				my $prevsibling = '';
				my $thisnodename = getNodeName($node);
				# for each sibling, backwards...
				foreach my $sibling (reverse @siblings)
				{
					# if we've passed the node being finalized...
					if ($foundself) {
						my %dirinfo = getDirInfo($parentnode . $sibling . $config{'delimiter'});
						
						# if this node has been finalized...
						if ($dirinfo{'has_been_finalized'})
						{
							# then this is the node to insert after
							$prevsibling = $sibling;
							last;
						}
					}
					# if this is the node being finalized, remember that we've passed it
					elsif ($sibling eq $thisnodename) {
						$foundself = 1;
					}
				}

				# if we didn't find a node to insert after, insert after the next <!--#CHILDREN--> comment (by using global matching, we'll get the one we want, the first one after the parent's beginning)
				if (!$prevsibling)
				{
					$regex = qr/<!--#CHILDREN-->/;
				}
				# if we found a node to insert after, insert after its ending
				else
				{
					my $escapedprevsibling = escapeRegexStr($parentnode.$prevsibling.$config{'delimiter'});
					$regex = qr/<!--#\/\{$escapedprevsibling\}-->/;
				}
			}
			# insret the node's new sidebar content after $regex
			$oldsidebar =~ m/($regex)/g;
			print FH $` . $1 . $sidebartext . $';
		}
		# if we cannot find its parent in the sidebar (should never happen)
		else
		{
			die "$parentnode not found in $sidebarfile! (from finalizeSidebar())\n$!";
		}
	}
	
	# we're done outputting the new commented sidebar
	unlock(FH);
	close (FH);
	
	#
	#
	#
	# Commented sidebar file has been output.
	# Now we produce the non-commented version (without our little "comment markup" stuff)
	#
	#
	#
	
	# start reading from the commented sidebar file
	open(FH, "<$sidebarfile") or die "cannot open $sidebarfile?! in finalizeSidebar():\n$!";
	readLock(FH);
	my @ar = <FH>;
	my $commentedsidebar = join ('', @ar);
	unlock(FH);
	close FH;
	
	# start writing to the final sidebar file
	my $finalsidebarfile = $config{'includesdir'}.$config{'sidebarincludefile'};
	open (FH, ">$finalsidebarfile") or die "Couldn't write to $finalsidebarfile in finalizeSidebar():\n$!";
	writeLock(FH);
	
	my $currentnode;
	# stop at each <!--#...--> HTML comment
	while ($commentedsidebar =~ m/((?:.|\n)*?)<!--#(.*?)-->/mcg)
	{
		# print whatever was before it
		print FH $1;
		
		my $commenttype = $2;
		
		#if this comment begins a new node, remember the node that it refers to for later use
		if ($commenttype =~ /^{(.*)}/)
		{
			$currentnode = escapeRegexStr($1);
		}
		# if this comment begins an IFCHILDREN block...
		elsif ($commenttype eq 'IFCHILDREN')
		{
			# ...find next CHILDREN block and see if it contains anything. if not, skip ahead to next /IFCHILDREN. if so, continue as normal.
			
			# find CHILDREN block
			$commentedsidebar =~ m/((?:.|\n)*?)<!--#CHILDREN-->/mcg;
			# remember what was before it
			my $beforeCHILDREN = $1;
			# remember where to go back to if we need to do so
			my $gobackpos = pos($commentedsidebar);
			# check for end of CHILDREN block corresponding to this node
			$commentedsidebar =~ m/((?:.|\n)*?)<!--#\/CHILDREN{$currentnode}-->/mcg;
			# remember what was between the children
			my $betweenCHILDREN = $1;
			
			# if there wasn't anything inside the CHILDREN block...
			if (!$betweenCHILDREN)
			{
				# ...skip ahead to the end of the IFCHILDREN block and resume parsing; nothing was output since there were no children
				$commentedsidebar =~ m/<!--#\/IFCHILDREN-->/mcg;
			}
			# if there were children inside the CHILDREN block...
			else
			{
				# ...print whatever was before them...
				print FH $beforeCHILDREN;
				# ...and resume parsing at the beginning of the children block
				pos($commentedsidebar) = $gobackpos;
			}
		}
	}
	unlock(FH);
	close (FH);
}
#####################################################
# Function: generateInitialSidebarFile
# Parameters: none
# Return value: none
# 
# Purpose: Generates an empty commented sidebar file. This is used the first time
#		that a node is finalized.
#
sub generateInitialSidebarFile
{
	local *FH;
	open (FH, ">$config{'datadirpath'}$config{'commentedsidebar'}") or die "generateInitialSidebarFile failed to open \"$config{'datadirpath'}$config{'commentedsidebar'}\": $!";
	writeLock(FH);
	
	# contents of initial, "empty" commented sidebar file
	print FH "<!--#ROOT--><!--#/ROOT-->";
	
	unlock(FH);
	close (FH);
}

#####################################################
# Function: finalizedSidebarOpenFunc
# Parameters: see purpose of generateList()
# Return value: string (see purpose of generateList())
# 
# Purpose: Generates the opening of a list item in the commented sidebar file.
#		See the purpose of finalizeSidebar().
#
sub finalizedSidebarOpenFunc
{
	my %dirinfo = %{$_[0]};
	shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;

	my $newline = "\n" . "\t" x $depth;
	my $toreturn = '';

	# if this node should be output to the sidebar...
	if (!$dirinfo{'hidden'} && !$dirinfo{'marked_for_deletion'})
	{
		# opening of the node
		$toreturn .= "<!--#{$treepath}-->";
		
		#my $displayname = escapeForHTML($dirinfo{'display_name'});
		#my $nodename = escapeForHTML(getNodeName($treepath));
		#my $hyperlinkurl = escapeForHTMLAttribute(makeFinalURL($treepath));
		#$toreturn .= "<li id=\"node_$nodename\"><a href=\"$hyperlinkurl\">$displayname</a>" if ($depth);
		
		# opening of the node's IFCHILDREN block
		#$toreturn .= "<!--#IFCHILDREN-->" if ($depth);
		#$toreturn .= "<ul$newline>";

		$toreturn .= $listfunctions->[0]->(\%dirinfo, $treepath, $depth, $newline);

		$toreturn .= "<!--#IFCHILDREN-->"; # if (!$depth);
		#if ($dirinfo{'has_content'} && $depth)
		#{
		#	$toreturn .= "<li><a href=\"$hyperlinkurl\">$displayname</a></li$newline>";
		#}
		
		$toreturn .= $listfunctions->[1]->(\%dirinfo, $treepath, $depth, $newline);
		
		# opening of the node's CHILDREN block
		$toreturn .= "<!--#CHILDREN-->";
	}
	return $toreturn;
}

#####################################################
# Function: finalizedSidebarCloseFunc
# Parameters: see purpose of generateList()
# Return value: string (see purpose of generateList())
# 
# Purpose: Generates the closing of a list item in the commented sidebar file.
#		See the purpose of finalizeSidebar().
#
sub finalizedSidebarCloseFunc
{
	my %dirinfo = %{$_[0]}; shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;

	my $newline = "\n" . "\t" x ($depth-1);
	my $toreturn = '';
	
	# if this node should be output to the sidebar...
	if (!$dirinfo{'hidden'} && !$dirinfo{'marked_for_deletion'})
	{
		# closing of the CHILDREN block
		$toreturn .= "<!--#/CHILDREN{$treepath}-->";

		$toreturn .= $listfunctions->[2]->(\%dirinfo, $treepath, $depth, $newline);

		# closing of the IFCHILDREN block
		#$toreturn .= "<!--#/IFCHILDREN-->" if (!$depth);
		#$toreturn .= "</ul$newline>";
		$toreturn .= "<!--#/IFCHILDREN-->" if ($depth);
		#$toreturn .= "</li$newline>" if ($depth);

		$toreturn .= $listfunctions->[3]->(\%dirinfo, $treepath, $depth, $newline);

		# closing of the node
		$toreturn .= "<!--#/{$treepath}-->";
	}
	return $toreturn;
}

#####################################################
# Function: finalizedSidebarCloseFunc
# Parameters: see purpose of generateList()
# Return value: recurse into this node or not? (boolean)
# 
# Purpose: Determines whether a node should be placed in the finalized sidebar file.
#
sub finalizedRecurseTestFunc
{
	my $dirinforef = shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	# only recurse into a node if it's neither hidden nor marked for deletion, and it has children
	if ($$dirinforef{'hidden'} || $$dirinforef{'marked_for_deletion'} || isLeafNode($treepath))
	{
		return 0;
	}
	return 1;
}

#####################################################
# Function: titleGenerator
# Parameters: file handle to output title to, node whose title is being output
# Return value: none
# 
# Purpose: Outputs a node's title. Typically this will be done inbetween <title> tags
#		in a template.
#
sub titleGenerator
{
	my $FH = shift;
	my $node = shift || $requestinfo{'node'};
	
	# get title from dir info of the node
	my %dirinfo = getDirInfo($node);
	my $title = $dirinfo{'title'};
	print $FH escapeForHTML($title);
}
1;
