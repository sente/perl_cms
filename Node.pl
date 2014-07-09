#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

=pod
package Node;



use Exporter;

our @ISA	= qw(Exporter);
our @EXPORT = qw(
	&doesChildExist
	&getProperty
	&writeDirInfo
	&writeDefaultDirInfo
	&getDirInfo
	&getChildren
	&addChildToChildrenInfo
	&removeChildFromChildrenInfo
	&getParentNode
	&doesNodeExist
	&createNode
	&recurseTree
	&copyNode
	&getNodeName
	);
	
use Config;
use General;
=cut

#####################################################
# Node.pl
#
# This file contains functions which manipulate "nodes" in the CMS content tree.
# Nodes are actually represented as directories.
# Each node (directory) has a directoryinfo.dat file (name can be changed in config.pl)
#  which contains properties of the node.
# Each node also contains a children.dat file which is a list of its children (folders 
#  such as "images" or "scripts" do not count as children, since they are not truly 
#  nodes in the tree, but are directories for managing content-related stuff.)
# 
# A "treepath" is a path to a node in the tree. It should not be confused with a system
#  path, since it is relative to the root of the (more theoretical) tree, and uses a different
#  delimiter (specified in config.pl). An example treepath is "/node1/node2/node3/".
#  The treepath for the root is "/".
#
#####################################################



#####################################################
# Function: createNode
# Parameters: path of the parent node under which the new node will be created as a child, name of the new node
# Return value: 1 if success, 0 otherwise
# 
# Purpose: Adds a node to the tree.
#
sub createNode
{
	my $parentpath = shift;
	my $nodename = shift;
	
	my $nodetocreate = makeSystemPath($parentpath.$nodename).$config{'systemslash'};
	
	if(-e makeSystemPath($parentpath.$nodename) || -d $nodetocreate)	#	path already exists. this is an error.
	{
		$STATUS_FLAG = 1;
		return 0;
	}
	
	addChildToChildrenInfo($parentpath, $nodename);
	
	mkdir($nodetocreate) or die ("could not MKDIR!!\nin createNode in Node.pl\n$!\n\n");
	
	writeDirInfo($parentpath.$nodename.$config{'delimiter'}, \%defaultDirInfo);
	
	return 1;
}

#####################################################
# Function: deleteNode
# Parameters: Treepath to the node to be deleted
# Return value: 1 if success, 0 otherwise
# 
# Purpose: Removes a node from the tree, no questions asked.
#
sub deleteNode
{
	my $node = shift;
	
	my %dirinfo = getDirInfo($node);
	
	my $systempath = makeSystemPath($node);
		
	my @patharrays = recurseTree($node, [$config{'systemslash'}]);
	my @files = @{$patharrays[0]};
	
	foreach(reverse @files)
	{
		my $filepath = $systempath.$_;
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
			die "error: $filepath is not a directory or a plain file...";
		}
	}
	
	rmdir($systempath);
	
	#removing child from the parent's children.dat file

	my $parentnode = getParentNode($node);
	
	my @nodes = split($config{'escapeddelimiter'}, $node);
	my $childname = $nodes[scalar(@nodes)-1];
	
	removeChildFromChildrenInfo($parentnode, $childname);
	
	return 1;
}

#####################################################
# Function: copyNode
# Parameters: Treepath to the node to be copied from, treepath to the node which will be the parent of the newly created node, name of the new node
# Return value: 1 if success, 0 otherwise
# 
# Purpose: Makes a duplicate of a given node in a specified location.
#
sub copyNode
{
	my ($fromnode, $parentnode, $nodename) = @_;
	
	my $destnode = $parentnode . $nodename . $config{'delimiter'};

	my $fromnodepath = makeSystemPath($fromnode);
	my $parentnodepath = makeSystemPath($parentnode);
	my $destnodepath = makeSystemPath($destnode);
	
	
	my @patharrays = recurseTree($fromnode, [$config{'systemslash'}, $config{'delimiter'}]);
	my @fromfiles	= @{$patharrays[0]};
	my @nodepaths	= @{$patharrays[1]};
	my @tofiles;
	
	mkdir($destnodepath);
	
	for (my $i=0; $i < scalar(@fromfiles); $i++)
	{
		my $file = $fromfiles[$i];
		$fromfiles[$i] = $fromnodepath.$file;
		$tofiles[$i] = $destnodepath.$file;
	}
	for (my $i=0; $i < scalar(@fromfiles); $i++) {
		if(-d $fromfiles[$i]) {					# must make a directory
			mkdir ($tofiles[$i]);
		}
		else {							# copy the file
			copy($fromfiles[$i], $tofiles[$i]);
		}
	}
	
	addChildToChildrenInfo($parentnode, $nodename);
	
	foreach my $node (@nodepaths)
	{
		$node = $destnode . $node;
		my $dirinfoescaped = escapeRegexStr($config{'directoryinfofile'});
		if($node =~ /$config{'escapeddelimiter'}$dirinfoescaped$/)
		{
			my $thisnode = substr($node, 0, length($node) - length($config{'directoryinfofile'}));
			my %dirinfo = getDirInfo($thisnode);
		
			$dirinfo{'has_been_finalized'} = "0";
			writeDirInfo($thisnode, \%dirinfo);
		}
	}
	
	return 1;
}

#####################################################
# Function: doesChildExist
# Parameters: Treepath to the parent node, name of the child
# Return value:	1 or 0, depending if the specified child exists 
# 
# Purpose: checks to see if a given child of a node exists
#
sub doesChildExist
{
	my $parentdir = shift;
	my $childname = shift;
	
	my @ar = getChildren($parentdir);
	
	foreach(@ar)
	{
		return 1 if $_ eq $childname;
	}
	return 0;
}


#####################################################
# Function: writeDirInfo
# Parameters: Treepath to a node, \%hashreference which maps the properties of the directory to their values
# Return value:	0
# 
# Purpose: Interface to write a directory info file for a node
#
sub writeDirInfo
{
	my $nodepath = makeSystemPath(shift);
	my $hashref = shift;
	
	open(HANDLE, ">$nodepath$config{'directoryinfofile'}") or die "cannot open file. $nodepath$config{'directoryinfofile'}. $!\n";;
	writeLock(HANDLE);
	foreach(sort keys %$hashref)
	{
		print HANDLE "$_=$$hashref{$_}\n";
	}
	unlock(HANDLE);
	close HANDLE;
	return 0;
}

#####################################################
# Function: getDirInfo
# Parameters: Treepath to the node to get the directory info of
# Return value:	hash which maps properties of the given node to their values
# 
# Purpose: Interface to read a directory info file, to quickly retrieve information about a node
#
sub getDirInfo
{
	my $nodepath = makeSystemPath(shift);

	my $slurp = slurp("$nodepath$config{'directoryinfofile'}");
	
	open(DIRINFO, "<$nodepath$config{'directoryinfofile'}");
	readLock(DIRINFO);
	my @blocks = <DIRINFO>;
	unlock(DIRINFO);
	close (DIRINFO);
	
	my %properties;
	foreach my $line (@blocks)
	{
		chomp($line);
		my @ar = split('\s*=\s*', $line);
		$properties{$ar[0]} = $ar[1];
	}
	#print Dumper(\%properties);
	
	return %properties;
}

#####################################################
# Function: getChildren
# Parameters: Treepath to the node to get the children of
# Return value:	array of children node names (not paths)
# 
# Purpose: get a list of the children of a node
#
sub getChildren
{
	my $nodepath = makeSystemPath(shift);

	my @toreturn = ();
	open (CHILDINFO, "<$nodepath$config{'childreninfofile'}") or return @toreturn;
	readLock(CHILDINFO);
	@toreturn = <CHILDINFO>;
	unlock(CHILDINFO);
	close (CHILDINFO);
	map {chomp} @toreturn;
	return @toreturn;
}
#####################################################
# Function: addChildToChildrenInfo
# Parameters: Treepath to the node to add a child to, name of the child being added
# Return value:	none
# 
# Purpose: Adds a child to the children.dat file. Does not actually create the child.
#
sub addChildToChildrenInfo
{
	my $nodepath = makeSystemPath(shift);
	my $childname = shift;
	open(CHILDINFO, ">>$nodepath$config{'childreninfofile'}") or die "Could not open $nodepath$config{'childreninfofile'}: $!\n in addChildToChildrenInfo";
	writeLock(CHILDINFO);
	print CHILDINFO "$childname\n";
	unlock(CHILDINFO);
	close (CHILDINFO);
}

#####################################################
# Function: removeChildFromChildrenInfo
# Parameters: Treepath to the node to remove a child from, child name to remove
# Return value: 1
# 
# Purpose: Removes a child from the children.dat file. Does not actually delete the child.
#
sub removeChildFromChildrenInfo
{
	my $nodepath = shift;
	my $childname = shift;
	
	my @ar = getChildren($nodepath);
	
	my $systempath = makeSystemPath($nodepath);
	open(CHILDINFO, ">$systempath$config{'childreninfofile'}") or die "Could not open $systempath$config{'childreninfofile'}: $!\n in removeChildFromChildrenInfo.";
	writeLock(CHILDINFO);	
	
	foreach (@ar)
	{
		print CHILDINFO "$_\n" unless $childname eq $_;		
	}
	
	unlock(CHILDINFO);
	close CHILDINFO;
	return 1;
}
#####################################################
# Function: getParentNode
# Parameters: Treepath to the node to get the parent of
# Return value: Treepath to the parent of the node given
# 
# Purpose: Gets the treepath to the parent of a node.
#
sub getParentNode
{
	my $node = shift;
	#/this/that/this/that/file
	#/this/that/this/that/
	
	
	#if its root
	
	if($node eq $config{'delimiter'})
	{
		return "";
	}
	
	#if its a directory...
	#The order of these if statements matters. do NOT change order
	if($node =~ /^(.*$config{'escapeddelimiter'}).*?$config{'escapeddelimiter'}$/)
	{
		return $1;
	}
	#if its a file...
	if($node =~ /^(.*$config{'escapeddelimiter'})(.*?)$/)
	{
		return $1;
	}
	die "getParentNode(param:$node) error.\n";
	return 0;
}
#####################################################
# Function: getNodeName
# Parameters: Treepath to the node to get the name of
# Return value: name of the node (not path)
# 
# Purpose: Grab the name of the last node in a treepath. For instance:
# 		 "/node1/node2/node3/" => "node3"
# 		 "/" => ""
#
sub getNodeName
{
	my $treepath = shift;
	$treepath =~ s/^(.*?$config{'escapeddelimiter'})*(.*)$config{'escapeddelimiter'}$/$2/;
	return $treepath;
}

#####################################################
# Function: doesNodeExist
# Parameters: Treepath to the node to check existance of
# Return value: 1 if node exists, 0 if it doesn't
# 
# Purpose: Checks the existance of a node in the tree.
#
sub doesNodeExist
{
	my $destnode = shift;
	
	my @nodes = split (/$config{"escapeddelimiter"}/, $destnode);
	shift(@nodes);
	my $pathsofar = $config{"delimiter"};
	
	foreach my $node (@nodes)
	{
		if(-d makeSystemPath($pathsofar))
		{
			unless(doesChildExist($pathsofar, $node))
			{
				#print "doesnodeexist failed at $node, parent: $pathsofar";
				return 0;
			}
		}
		else
		{
			return 0;
		}
		$pathsofar.=$node.$config{"delimiter"};
	}	
	return 1;	
}

#####################################################
# Function: isLeafNode
# Parameters: treepath of the node to check
# Return value: 1 if leaf node, 0 otherwise
# 
# Purpose: Determines if a node is a leaf node. If a node has only children which are 
#		marked for deletion or hidden, that node will still be considered a leaf node 
#		by this function. This function is intended to be used to determine whether 
#		a node would be a leaf if the entire tree were finalized right now. That is 
#		why children which are marked-for-deletion or hidden don't count.
#
sub isLeafNode
{
	my $node = shift;
	my @children = getChildren($node);
	foreach $child (@children)
	{
		my %dirinfo = getDirInfo($node.$child.$config{'delimiter'});
		return 0 if (!$dirinfo{'marked_for_deletion'} && !$dirinfo{'hidden'});
	}
	return 1;
}

#####################################################
# Function: getAllDescendants
# Parameters: node to get descendants of
# Return value: array of descendants
# 
# Purpose: gets a list of all descendants of a node. Primarily used to generate 
#		drop-down lists for the user to select a node in the tree.
#
sub getAllDescendants
{
	my $root = shift;
	my @descendants = ();
	
	getAllDescendantsHelper($root, \@descendants);
	
	return @descendants;
}
#####################################################
# Function: getAllDescendantsHelper
# Parameters: current node in recursion, array of descendants so far
# Return value: none
# 
# Purpose: Implements the recursion for getAllDescendants.
#
sub getAllDescendantsHelper
{
	my $node = shift;
	my $arrayref = shift;
	
	my %dirinfo = getDirInfo($node);
	return if ($dirinfo{'marked_for_deletion'});
	
	push @$arrayref, $node;

	my @children = getChildren($node);
	foreach my $child (@children)
	{
		my $childpath = $node . $child . $config{'delimiter'};
	
		getAllDescendantsHelper($childpath, $arrayref);
	}
}

#####################################################
# Function: fixDescendantLeafValues
# Parameters: node which has been added or will soon be removed,
#		number of new descendant leaves (should be negative upon node deletion)
#		number of new descendant leaves with content (should be negative upon content removal)
# Return value: none
# 
# Purpose: When leaf nodes are added, deleted, or changed, the descendant_leaves and 
#		descendant_leaves_with_content properties of its ancestors must be 
#		updated. This function does that. It takes the node which has caused changes in the tree,
#		and an amount by which each property must be changed, and updates the ancestors
#		of the node with the new values. Note that it stops when it reaches either the root or 
#		a hidden or marked for deletion node, since those are not considered descendants of their
#		parents for the purpose of finalization.
#
sub fixDescendantLeafValues
{
	my $currentnode = shift; # start at parent of this node, working towards root
	my $descendant_leaves_change = shift; # add this to descendant_leaves values
	my $descendant_leaves_with_content_change = shift; # add this to descendant_leaves_with_content values

	while($currentnode = getParentNode($currentnode))
	{
		my %dirinfo = getDirInfo($currentnode);
		
		$dirinfo{'descendant_leaves'} += $descendant_leaves_change;
		$dirinfo{'descendant_leaves_with_content'} += $descendant_leaves_with_content_change;
		writeDirInfo($currentnode, \%dirinfo);

		last if ($dirinfo{'hidden'} || $dirinfo{'marked_for_deletion'});
	}
}

#####################################################
# Function: leafContentChanged
# Parameters: node which has had content added or removed,
#		directory info reference for that node,
#		+1 or -1 depending on whether content was added to or removed from the node.
# Return value: none
# 
# Purpose: When a leaf gains or loses content, the descendant_leaves_with_content 
#		properties of its ancestors must be updated. This function does that.
#
sub leafContentChanged
{
	my $node = shift;
	my $dirinforef = shift;
	my $changeby = shift;
	
	$$dirinforef{'descendant_leaves_with_content'} += $changeby;
	
	# we shouldn't modify this node's ancestors if it's parent doesn't consider it a descendant
	# (that is, if it's hidden or marked for deletion)
	return if ($$dirinforef{'hidden'} || $$dirinforef{'marked_for_deletion'});
	
	fixDescendantLeafValues($node, 0, $changeby);
}

#####################################################
# Function: leafCountChanged
# Parameters: node which has been added or removed,
#		directory info reference for that node,
#		boolean of whether the parent is/was a leaf before the node was added, or after it was removed,
#		boolean of whether the parent has content,
#		whether the nodes are being added or removed
# Return value: none
# 
# Purpose: When leaf nodes are added, deleted, or changed, the descendant_leaves and 
#		descendant_leaves_with_content properties of its ancestors must be 
#		updated. This function determines how much those properties will be changed
#		by, and calls the fixDescendantLeafValues function to update them (if necessary).
#
sub leafCountChanged
{
	my $node = shift;				# this node is going to affect its anscestors
	my $dirinforef = shift;			# dirinfo of the relevant node
	my $parent_is_leaf = shift;			# is the parent a leaf either before or after the operation was carried out? (before if adding, after if removing)
	my $parent_has_content = shift;		# does the parent have content?
	my $adding_or_removing = shift;	# +1 or -1
	
	my $descendant_leaves_change = $$dirinforef{'descendant_leaves'};
	$descendant_leaves_change-- if ($parent_is_leaf);
	$descendant_leaves_change *= $adding_or_removing;
	
	my $descendant_leaves_with_content_change = $$dirinforef{'descendant_leaves_with_content'};
	$descendant_leaves_with_content_change-- if ($parent_is_leaf && $parent_has_content);
	$descendant_leaves_with_content_change *= $adding_or_removing;
	
	if ($descendant_leaves_change || $descendant_leaves_with_content_change)
	{
		fixDescendantLeafValues($node, $descendant_leaves_change, $descendant_leaves_with_content_change);
	}
}

#####################################################
# Function: isParentLeafWithContent
# Parameters: node whose parent is being checked
# Return value: array: (whether the parent is a leaf, whether the parent has content)
# 
# Purpose: When the leafCountChanged function is going to be called, the calling 
#		function needs to know whether the parent of the node being operated on
#		is a leaf and whether it has content. This function can be used to determine that.
#		Note that it always returns 0 for parent_has_content if the parent is
#		a leaf, because the leafCountChanged function doesn't care about the parent's 
#		content if that is the case.
#
sub isParentLeafWithContent
{
	my $parentpath = getParentNode(shift);
	
	if(!$parentpath){
		return (1,0);
	}
	
	my $parent_is_leaf = isLeafNode($parentpath);
	my $parent_has_content = 0;
	if ($parent_is_leaf)
	{
		my %parent_dirinfo = getDirInfo($parentpath);
		$parent_has_content = $parent_dirinfo{'has_content'};
	}
	return ($parent_is_leaf, $parent_has_content);
}

#####################################################
# Function: moveNode
# Parameters: node which is being moved, +1/-1 indicating which direction it's being moved in
# Return value: none
# 
# Purpose: Moves a node up or down in its parent's children.dat file, in order to move it 
#		around among its siblings. Note that +1 means down, and -1 means up (since 
#		the top of the children.dat file is array index 0, and indices increase towards
#		the bottom).
#
#		Note that this is not "move" in the sense of "make a copy and then delete the original" - 
#		it's merely a way of swapping a node's position with its nearby siblings.
#
sub moveNode
{
	my $node = shift;
	my $direction = shift;

	my $parentnode = getParentNode($node);
	my @children = getChildren($parentnode);
	my $index = getSiblingIndex($node);
		
	if($index == -1 || $index+$direction < 0 || $index +$direction >= scalar(@children)) {
		$STATUS_FLAG = 21;
		return 0;
	}
	else{
		($children[$index], $children[$index+$direction]) = ($children[$index+$direction], $children[$index]);
	}

	local *FH;
	open(FH, ">" . makeSystemPath($parentnode . $config{'childreninfofile'}));
	writeLock(FH);
	foreach my $child (@children)
	{
		print FH "$child\n";
	}
	unlock(FH);
	close(FH);
}

#####################################################
# Function: getSiblingIndex
# Parameters: node to get the index of
# Return value: index of the node among its siblings
# 
# Purpose: Returns the position of the given node within its parent's children.dat file.
#		The parent's first child has an index of zero, etc.
#
sub getSiblingIndex
{
	my $node = shift;
	my @children = getChildren(getParentNode($node));
	my $nodename = getNodeName($node);
	my $index = 0;
	foreach my $child (@children)
	{
		return $index if ($child eq $nodename);
		$index++;
	}
	return -1;
}

1;
