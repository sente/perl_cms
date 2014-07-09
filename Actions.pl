#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

#####################################################
# Actions.pl
#
#  This file contains a function for each action that this program can carry out. There is a function
#  for each button on the main interface, as well as other functions for some other actions available
#  only elsewhere within the program.
#  This file also contains the paramRequestGenerator function, which creates a form that the user
#  can use to specify required parameters for an action that they have not supplied them all for.
#
#####################################################

#####################################################
# Function: actionPreview
# Parameters: node to preview
# Return value: none
# 
# Purpose: Generates a preview page for the requested node, and sets up the outputTokenHash to display it when we reach sendResponse().
#
sub actionPreview
{
	#require XML::DOM;

	# get parameters and do error checking
	my $node = shift;
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}
	my %dirinfo = getDirInfo($node);
	if (!$dirinfo{'has_content'})
	{
		$STATUS_FLAG = 22;
		return 0;
	}
	
	# make a temporary file to output the content to; it will be read from later, within previewContentGenerator
	my $tempfile = $config{'datadirpath'} . $config{'temporaryfile'};
	
	local *FH;
	open (FH, ">$tempfile") or die "Couldn't open $tempfile in actionPreview: $!\n";
	writeLock(FH);
	
	# output finalized content to temp file
	outputFinalizedContent(\*FH, $config{'contenttemplatespath'}.$dirinfo{'content_template'}, makeSystemPath($node).$config{'contentfile'});
	
	unlock(FH);
	close(FH);
	
	if (!$STATUS_FLAG) # if there have been no problems
	{
		# set up the outputTokenHash so that the correct output will be given
		$outputtemplate = $config{'previewtemplatespath'} . $dirinfo{'page_template'};
		$outputTokenHash{'CONTENT'}	= \&previewContentGenerator;
		$outputTokenHash{'TITLE'}	= \&titleGenerator;
		$outputTokenHash{'SIDEBAR'}	= \&previewSidebarGenerator;
	}
}

#####################################################
# Function: actionSetTemplate
# Parameters: node to set the template of, the page template of the node, the content template of the node
# Return value: none
# 
# Purpose: changes or sets the template that a node uses; also delete's the node's content in the process.
#
sub actionSetTemplate
{
	# get params
	my $node = shift;
	my $page_template = shift;
	my $content_template = shift;
	
	# error checking
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}
	my %dirinfo = getDirInfo($node);

	# delete content file if necessary
	if ($dirinfo{'has_content'})
	{
		unlink makeSystemPath($node . $config{'contentfile'});
		$dirinfo{'has_content'} = 0;
		
		# update descendant-related properties of ancestor nodes
		leafContentChanged($node, \%dirinfo, -1) if (isLeafNode($node));
	}

	# set the templates
	$dirinfo{'content_template'} = $content_template;
	$dirinfo{'page_template'} = $page_template;
	writeDirInfo($node, \%dirinfo);

	# we will now go on to let them edit the page (actionEdit will be called from handleRequest)
}

#####################################################
# Function: actionEdit
# Parameters: node to edit
# Return value: none
# 
# Purpose: Sets up the outputTokenHash so that the user will be sent to the node editing page
#
sub actionEdit
{
	#require XML::DOM;

	# get params and do error checking
	my $node = shift;
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}
	
	# check to see if there is a designated template setup with the node:
	
	# if not, ask which template they want to use
	my %dirinfo = getDirInfo($node);
	if (!($dirinfo{'content_template'} && $dirinfo{'page_template'}))
	{
		$outputTokenHash{'CONTENT'} = \&templateRequestGenerator;
	}
	
	# if so, set up outputTokenHash to send them the edit form
	else
	{
		# editFormGenerator creates a form for the user to input values which will be written to template.xml
		$outputTokenHash{'CONTENT'} = \&editFormGenerator;
	}
}

#####################################################
# Function: actionChangeAttribute
# Parameters: node to change properties of, node's new display name, node's hidden value, node's new title
# Return value: none
# 
# Purpose: changes the node's directory info file based on user-supplied parameters
#
sub actionChangeAttribute
{
	# get params
	my $node			= shift;
	my $displayname	= shift;
	my $hidden		= shift;
	my $title			= shift;
	
	# error checking
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}
	
	# used for logic later on
	my $washidden;

	my %dirinfo = getDirInfo($node);
	
	$washidden = $dirinfo{'hidden'};
	
	# set correct attributes in dirinfo
	$dirinfo{'display_name'} = $displayname;
	$dirinfo{'hidden'} = $hidden;
	$dirinfo{'title'}	= $title;
	
	my $parentpath = getParentNode($node);
	my $parent_is_leaf;
	my $parent_has_content;
	
	# get parent is leaf, parent has content values for later (if going from hidden to not hidden)
	if (!$hidden && $washidden) {
		($parent_is_leaf, $parent_has_content) = isParentLeafWithContent($node);
	}

	# write new dirinfo
	writeDirInfo($node, \%dirinfo);

	# get parent is leaf, parent has content values for later (if going from not hidden to hidden)
	if ($hidden && !$washidden) {
		($parent_is_leaf, $parent_has_content) = isParentLeafWithContent($node);
	}

	# update descendant-related properties of ancestors (if hiddenness changed)
	if ($hidden != $washidden) {
		leafCountChanged($node, \%dirinfo, $parent_is_leaf, $parent_has_content, $washidden - $hidden);
	}
}

#####################################################
# Function: actionFinalize
# Parameters: node to finalize, whether or not to recursively finalize children
# Return value: none
# 
# Purpose: starts node finalization
#
sub actionFinalize
{
	#require XML::DOM;

	# get params
	my $node = shift;
	my $recurse = shift;
	
	# some error checking
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}

	my %dirinfo = getDirInfo($node);

	
	# If we are finalizing the root, we must delete the sidebarinfo.txt file because of a bug
	# this bug caused the sidebar to have repetive nodes and was just a mess
	if($node eq $config{'delimiter'} && $recurse)
	{
		my $sidebarfile = $config{'datadirpath'}.$config{'commentedsidebar'};
		if(-e $sidebarfile)
		{
			unlink($sidebarfile);
		}
	}
	
	
	# heavy error checking:
	
	#can't finalize if self or ancestors are marked for deletion (TODO)
	# (right now the interface doesn't make it easy to do - one would have to manually enter the URL - so we're not too worried about it, but we should be)
	
	#you can't finalize recursively if not all descendant leaves have content
	if($recurse && $dirinfo{'descendant_leaves_with_content'} != $dirinfo{'descendant_leaves'})
	{
		$STATUS_FLAG = 12;
		return 0;
	}
	
	# you can't finalize without recursion unless the node has been finalized in the past.
	# we make an exception for nodes with no children, since recursion won't matter for them anyway.
	elsif(scalar(getChildren($node)) > 0 && !$recurse && !$dirinfo{'has_been_finalized'})
	{
		$STATUS_FLAG = 13;
		return 0;
	}
	
	# if we haven't hit any errors so far...
	else
	{
		my %parentinfo;
		
		# don't bother getting parent info if this is the root
		if ($node ne $config{'delimiter'}) {
			# get dir info of parent node
			%parentinfo = getDirInfo(getParentNode($node));
		}

		# you cannot finalize a node unless its parent has been finalized in the past, or it is the root
		if($node ne $config{'delimiter'} && !$parentinfo{'has_been_finalized'})
		{
			$STATUS_FLAG = 14;
			return 0;
		}

		# finalize the node!
		finalizeNode($node, $recurse);

		if (!$STATUS_FLAG) # if all is ok
		{
			# output the new sidebar!
			# (This is purposely done after finalizing the node; if something goes wrong for some reason inside finalizeNode(), we don't want to provide users with a sidebar that links to non-existant pages!)
			finalizeSidebar($node, $recurse);
		}

		# need to remember (possibly?) to add a field in dirinfo.dat named 'updated_since_last_finalization_or_something' like that;
		# this is so when using the recurse option while finalizing, it doesn't uselessly copy everything from A->B
	}
}

#####################################################
# Function: actionSave
# Parameters: node to save
# Return value: none
# 
# Purpose: saves a node based on CGI parameters and the node's template
#
sub actionSave
{
	#require XML::DOM;

	# get params and do error checking
	my $node = shift;
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}
	
	# get dir info and make sure the node has its templates set
	my %dirinfo = getDirInfo($node);
	if (!($dirinfo{'content_template'} && $dirinfo{'page_template'}))
	{
		$STATUS_FLAG = 23;
		return 0;
	}
	
	# save the content into the content file based on the template and CGI parameters which should be supplied
	saveContent($config{'contenttemplatespath'}.$dirinfo{'content_template'}, makeSystemPath($node).$config{'contentfile'});
	
	# if all went well...
	if (!$STATUS_FLAG)
	{
		# check if this node had content before or not
		my $content_is_new = ($dirinfo{'has_content'} == 0);
		$dirinfo{'has_content'} = 1;

		# if this is a leaf node that has never had content before, 
		# update descendant-related properties of ancestors
		if ($content_is_new && isLeafNode($node))
		{
			leafContentChanged($node, \%dirinfo, 1);
		}
		
		# write the new dir info
		# (must be after leafContentChanged since that modifies dirinfo)
		writeDirInfo($node, \%dirinfo);
	}
}

#####################################################
# Function: actionCopy
# Parameters: node to copy from, node to copy into, new name of copied node, new display name of copied node
# Return value: none
# 
# Purpose: deep-copies node A into node B
#
sub actionCopy
{
	# get params
	my ($fromnode, $parentnode, $nodename, $displayname) = @_;
	
	# determine treepath of new node to be created
	my $destnode = $parentnode . $nodename . $config{'delimiter'};
	
	# make sure the node to copy exists	
	if( !doesNodeExist($fromnode))
	{
		$STATUS_FLAG = 7;
		return 0;
	}
	# make sure the parent exists so we have a place to put the node
	if( !doesNodeExist($parentnode))
	{
		$STATUS_FLAG = 9;
		return 0;
	}
	# make sure the destination node does not already exist
	if(doesNodeExist($destnode))
	{
		$STATUS_FLAG = 6;
		return 0;
	}
	# make sure the node to be created is not a reserved folder name
	foreach $filetype (@fileTypes)
	{
		if ($fileTypeFolders{$filetype} eq $nodename)
		{
			$STATUS_FLAG = 3; # directory is reserved
			return 0;
		}
	}

	# check if parent is a leaf/has content for later on
	my ($parent_was_leaf, $parent_has_content) = isParentLeafWithContent($destnode);

	# copy the node
	copyNode($fromnode, $parentnode, $nodename);
	
	# get dir info of newly copied node
	my %destnodeinfo = getDirInfo($destnode);

	# update descendant-related properties of ancestors
	leafCountChanged($destnode, \%destnodeinfo, $parent_was_leaf, $parent_has_content, 1);

	# change display name and write new dir info
	$destnodeinfo{'display_name'} = $displayname;
	writeDirInfo($destnode, \%destnodeinfo);
}

#####################################################
# Function: actionCreate
# Parameters: node to create within, new node's name, new node's display name
# Return value: none
# 
# Purpose: creates a new node
#
sub actionCreate
{
	# get params
	my $parentpath = shift;
	my $nodename = shift;
	my $displayname = shift;

	# make sure node to create within exists
	if (!doesNodeExist($parentpath)) {
		$STATUS_FLAG = 8;
		return 0;
	}
	# make sure node to create doesn't already exist
	if (doesChildExist($parentpath,$nodename)) {
		$STATUS_FLAG = 2;
		return 0;
	}
	# make sure node to create is not a reserved directory name
	foreach $filetype (@fileTypes)
	{
		if ($fileTypeFolders{$filetype} eq $nodename)
		{
			$STATUS_FLAG = 1; # directory is reserved
			return 0;
		}
	}

	# get the path of the new node being created
	my $nodepath = $parentpath.$nodename.$config{'delimiter'};

	# get parent leaf/content info for later
	my ($parent_was_leaf, $parent_has_content) = isParentLeafWithContent($nodepath);

	# create the node
	#print STDERR "creating: $parentpath . "::::" . $nodename\n\n";
	createNode($parentpath, $nodename);

	# get dir info of new node and set its display name	
	my %dirinfo = getDirInfo($nodepath);
	$dirinfo{'display_name'} = $displayname;
	writeDirInfo($nodepath, \%dirinfo);
	
	# update descendant-related properties of ancestors
	leafCountChanged($nodepath, \%dirinfo, $parent_was_leaf, $parent_has_content, 1);
}

#####################################################
# Function: actionDelete
# Parameters: node to delete
# Return value: none
# 
# Purpose: deletes a node or marks it for deletion
#
sub actionDelete
{
	# get params
	my $node = shift;

	# if the node does not exist, we can't delete it, idiot
	if(!doesNodeExist($node))
	{
		# WHAT WERE YOU THINKING?
		$STATUS_FLAG = 5;
		return 0;
	}
	# we can't delete the root
	if($requestinfo{'node'} eq $config{'delimiter'})
	{
		$STATUS_FLAG = 24;
		return 0;
	}

	# get node's dir info
	my %dirinfo = getDirInfo($node);
	
	# can't delete a node which is already marked for deletion.
	# quick check for safety; should probably throw an error though
	return if ($dirinfo{'marked_for_deletion'});

	# get the parent node
	my $parentnode = getParentNode($node);

	# mark for deletion if this node has been finalized
	if($dirinfo{'has_been_finalized'})
	{
		$dirinfo{'marked_for_deletion'} = 1;
		writeDirInfo($node, \%dirinfo);
	}
	# delete the node
	else
	{
		# yoink!
		deleteNode($node);
	}

	# update descendant-related properties of ancestors
	my ($parent_is_leaf, $parent_has_content) = isParentLeafWithContent($node);
	leafCountChanged($node, \%dirinfo, $parent_is_leaf, $parent_has_content, -1);
}

#####################################################
# Function: actionUndelete
# Parameters: node to unmark for deletion
# Return value: none
# 
# Purpose: unmarks a node for deletion
#
sub actionUndelete
{
	# get params and do error checking
	my $node = shift;
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}

	# get node's dir info
	my %dirinfo = getDirInfo($node);

	# make sure the node is, in fact, marked for deletion
	if (!$dirinfo{'marked_for_deletion'}) {
		$STATUS_FLAG = 25;
		return 0;
	}

	# set some variables for later
	my $parentnode = getParentNode($node);
	my ($parent_was_leaf, $parent_has_content) = isParentLeafWithContent($node);
	
	# unmark the node
	$dirinfo{'marked_for_deletion'} = 0;
	writeDirInfo($node, \%dirinfo);

	# update descendant-related properties of ancestors
	leafCountChanged($node, \%dirinfo, $parent_was_leaf, $parent_has_content, 1);
}

#####################################################
# Function: actionUpload
# Parameters: node to upload files for
# Return value: none
# 
# Purpose: handles file uploading for a node, and sets outputTokenHash so that the user will continue on to the node's file manager page
#
sub actionUpload
{
	# get params and do error checking
	my $node = shift;	
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}
	
	# rename and delete files as requested
	renameAndDelete();
	
	# if all went well...
	if($STATUS_FLAG == 0)
	{
		# get newly uploaded files (if any)
		getUploads();
	}
	
	# set page output so that the user goes back to the upload page
	$outputTokenHash{'CONTENT'} = \&uploadPageGenerator;
}

#####################################################
# Function: actionMove
# Parameters: node to move, direction (+1/-1) in which to move it
# Return value: none
# 
# Purpose: moves a node up or down amongst its siblings
#
sub actionMove
{
	# get params and do error checking
	my $node = shift;
	my $direction = shift;
	if (!doesNodeExist($node)) {
		$STATUS_FLAG = 20;
		return 0;
	}
	
	# can't move the root
	elsif ($node eq $config{'delimiter'})
	{
		$STATUS_FLAG = 26;
		return 0;
	}
	
	# move the node
	moveNode($node, $direction);
}

#####################################################
# Function: actionURLChooser
# Parameters: none
# Return value: none
# 
# Purpose: sets outputTokenHash so that the user will go to the URL chooser page; javascript handles the rest
#
sub actionURLChooser
{
	# set outputTokenHash to output the url chooser page
	$outputTokenHash{'CONTENT'} = \&urlChooserGenerator;
}

#####################################################
# Function: paramRequestGenerator
# Parameters: file handle to output to
# Return value: none
# 
# Purpose: when not all of an action's parameters are supplied, we ask for them with a form. 
#  This function generates the form.
#
# note: we should output something when an element is not required!
#
sub paramRequestGenerator
{
	# get params
	my $FH = shift;

	# keep track of whether or not we've already made a list of all of the nodes in the CMS	
	my $hasrecursed = 0;
	# the list of nodes
	my @nodes = ();
	# their display names
	my @displaynames = ();
	
	# the array of form elements to pass to generateForm
	my @formelements;
	
	# for each parameter that this action makes use of
	foreach my $field (@{$requiredparams{$requestinfo{'action'}}}, @{$optionalparams{$requestinfo{'action'}}})
	{
		#start form element generation
		my @element;
		
		$element[1] = $paramlabels{$field}; # text
		$element[2] = $field; # id
		
		# output a dropdown to choose from the nodes in the CMS
		if($paramtypes{$field} eq 'treepath')
		{
			# get a list of all nodes in the CMS
			unless($hasrecursed++)
			{
				@nodes= getAllDescendants($config{'delimiter'});
				foreach my $node (@nodes)
				{
					my %dirinfo = getDirInfo($node);
					push @displaynames,  $dirinfo{'display_name'};
				}
			}
			
			#start select element generation
			$element[0] = 'select';
			my @data;
			my @options;
			my $selectedindex;
			
			for (my $i = 0; $i < scalar(@nodes); $i++)
			{
				$options[$i] = ["$nodes[$i] (\"$displaynames[$i]\")", $nodes[$i]];
				$selectedindex = $i if ($nodes[$i] eq $requestinfo{$field});
			}
			$data[0] = \@options;
			$data[1] = $selectedindex;
			
			#end select element generation
			$element[3] = \@data;
		}
		# output a text box
		elsif($paramtypes{$field} eq 'string' || $paramtypes{$field} eq 'alphanumeric')
		{
			#generate text element
			$element[0] = 'text';
			$element[3] = [$requestinfo{$field}];
		}
		# output a checkbox
		elsif($paramtypes{$field} eq 'boolean')
		{
			#generate checkbox element
			$element[0] = 'checkbox';
			$element[3] = [$requestinfo{$field}];
		}
		# output a direction dropdown
		elsif($paramtypes{$field} eq 'direction')
		{
			#generate checkbox element
			$element[0] = 'select';
			$element[3] = [[["Up", -1], ["Down", 1]], 0];
		}
		#end element generation
		push @formelements, \@element;
	}
	
	# output the form
	print $FH "<div class=\"smallformcontainer\">\n";
	generateForm($FH, "paramrequest", $requestinfo{'action'}, \@formelements);
	print $FH "</div>\n";
}

1;

