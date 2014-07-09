#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

#####################################################
# MainPage.pl
#
#  This file contains functions which create the main CMS page. It makes heavy
#  use of generateList, since the main page is little more than a list of nodes, 
#  each of which has a number of buttons (hyperlinks) which can be used to
#  manipulate it.
#
#####################################################

my $marked_for_deletion_mode = 3;
my $hidden_mode = 2;

#####################################################
# Function: mainContentGenerator
# Parameters: Filehandle to output content to
# Return value: none
# 
# Purpose: Generates the content for the main CMS page.
#
sub mainContentGenerator
{
	my $FH = shift;
	print $FH "<h1>Content Management System</h1>\n";
	print $FH "<h2>Version $VERSION</h2>\n\n";
	
	outputStatus();
	
	print $FH "<ul id=\"sitetree\">";
	print $FH generateList($config{'delimiter'}, \&mainCMSListOpenFunc, \&mainCMSListCloseFunc, \&mainCMSListRecurseFunc);
	print $FH "</ul>";
}

#####################################################
# Function: mainCMSListOpenFunc
# Parameters: See purpose of generateList()
# Return value: String (See purpose of generateList())
# 
# Purpose: Outputs the opening of the list item for a node when generating the main
# 	CMS page's tree. Also outputs create, delete, copy, etc buttons for the node.
#
sub mainCMSListOpenFunc
{
	#print "entering open func\n";
	my %dirinfo = %{$_[0]}; shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;
	my $mode = shift;
	my $numsiblings = shift;
	my $siblingnum = shift;

	my $newline = "\n" . "\t" x $depth;

	my @classes = ();
	if ($dirinfo{'marked_for_deletion'} or $mode == $marked_for_deletion_mode) { #if self or ancestors have been marked for deletion
		$classes[scalar(@classes)] = 'marked-for-deletion';
	}
	elsif ($dirinfo{'hidden'} or $mode == $hidden_mode) {
		$classes[scalar(@classes)] = 'hidden';
	}
	if ($numchildren == 0 && $dirinfo{'descendant_leaves_with_content'} != $dirinfo{'descendant_leaves'}) {
		$classes[scalar(@classes)] = 'incomplete';
	}
	if (!$dirinfo{'has_been_finalized'})
	{
		$classes[scalar(@classes)] = 'new';
	}
	
	my @strings = ();
	push @strings, "<li";
	my $nodename = getNodeName($treepath);
	$nodename = "Root" if ($nodename eq "");
	my $displayname = " (\"$dirinfo{'display_name'}\")";
	$displayname = '' if ($nodename eq "Root");
	push @strings, ">";
	if (scalar(@classes) > 0)
	{
		push @strings, '<span class="' . join(' ', @classes) . '">';
	}
	push @strings, "<a class=\"nodename\"";
	push @strings, ">$nodename$displayname";
	#push @strings, "  ($dirinfo{'descendant_leaves_with_content'}/$dirinfo{'descendant_leaves'})";
	push @strings, "</a>";
	if (scalar(@classes) > 0) {
		push @strings, '</span>';
	}
	
	if ($mode != $marked_for_deletion_mode) # have no ancestors of this node been marked for deletion?
	{
		push @strings, "<span class=\"controlpanel\">";
		if ($dirinfo{'marked_for_deletion'})
		{
			push @strings, createButton('undelete', "$config{'webscriptpath'}?action=undelete&node=$treepath");
		}
		else
		{
			push @strings, createButton('new child', "$config{'webscriptpath'}?action=create&parentnode=$treepath");
			if($treepath ne $config{'delimiter'})
			{
				if ($dirinfo{'has_been_finalized'})
				{
					push @strings, createButton('mark for deletion', "$config{'webscriptpath'}?action=delete&node=$treepath");
				}
				else
				{
					push @strings, createButton('delete', "$config{'webscriptpath'}?action=delete&node=$treepath");
				}
			}
			else
			{
				push @strings, createButton('delete', '', "The root cannot be deleted");
			}
			push @strings, createButton('edit', "$config{'webscriptpath'}?action=edit&node=$treepath");
			push @strings, createButton('copy', "$config{'webscriptpath'}?action=copy&node=$treepath");
			push @strings, createButton('manage files', "$config{'webscriptpath'}?action=upload&node=$treepath", "", "_blank");
			push @strings, createButton('properties', "$config{'webscriptpath'}?action=change_attribute&node=$treepath&displayname=$dirinfo{'display_name'}&title=$dirinfo{'title'}&hidden=$dirinfo{'hidden'}&forceform=1");
	
			if ($dirinfo{'has_content'}) {
				push @strings, createButton('preview', "$config{'webscriptpath'}?action=preview&node=$treepath", "", "_blank");
			}
			else {
				push @strings, createButton('preview', '', 'This node cannot be previewed because it has no content');
			}
			if ($dirinfo{'has_been_finalized'} && $dirinfo{'had_content_when_finalized'}) {
				push @strings, createButton('view current', makeRemoteFinalURL($treepath), "", "_blank");
			}
			elsif (!$dirinfo{'has_been_finalized'}) {
				push @strings, createButton('view current', '', 'This node cannot be viewed because it has not been finalized');
			}
			else {
				push @strings, createButton('view current', '', 'This node cannot be viewed because it did not have content when it was finalized');
			}
			if ($dirinfo{'has_been_finalized'}) {
				push @strings, createButton('update', "$config{'webscriptpath'}?action=finalize&node=$treepath&recurse=0");
			}
			else {
				push @strings, createButton('update', '', 'This node cannot be updated because it has not been finalized');
			}
			if ($dirinfo{'descendant_leaves_with_content'} == $dirinfo{'descendant_leaves'}) {
				my %parentdirinfo = getDirInfo(getParentNode($treepath)); # not a great way to do this...
				if ($depth == 0 || $parentdirinfo{'has_been_finalized'}) {
					push @strings, createButton('finalize all', "$config{'webscriptpath'}?action=finalize&node=$treepath&recurse=1");
				}
				else {
					push @strings, createButton('finalize all', '', 'This node cannot be finalized because its parent has not been finalized');
				}
			}
			else {
				push @strings, createButton('finalize all', '', 'This node cannot be finalized because not all of its lowest-level sub-nodes have content');
			}
			if($siblingnum > 0) {
				push @strings, createButton('move up', "$config{'webscriptpath'}?action=move&node=$treepath&direction=-1");
			}
			else {
				push @strings, createButton('move up', "", 'This node cannot be moved up because it is the first child of its parent');
			}
			if($siblingnum < $numsiblings-1) {
				push @strings, createButton('move down', "$config{'webscriptpath'}?action=move&node=$treepath&direction=1");
			}
			else {
				push @strings, createButton('move down', "", 'This node cannot be moved down because it is the last child of its parent');
			}
		}
		push @strings, "</span>";
	}
	#buttons here
	if ($recurse) # if we recurse
	{
		push @strings, "<ul$newline>";
	}
	return join "", @strings;
}

# Hash of button IDs; each entry contains title text and the button label for the corresponding button.
# Used by the createButton function, below.
our %buttondata = (
	'preview'				=> ['Preview this node',									'Preview'],
	'edit'					=> ['Edit this node\'s content',								'Edit'],
	'finalize all'			=> ['Save this node and all of its sub-nodes to the final website',		'Finalize All'],
	'update'				=> ['Save this node to the final website without saving its sub-nodes',	'Update'],
	'new child'				=> ['Create a new node underneath this node',					'New Child'],
	'delete'				=> ['Delete this node and all of its sub-nodes', 					'Delete'],
	'mark for deletion'		=> ['Mark this node to be deleted upon the next finalization',			'Mark for Deletion'],
	'undelete'				=> ['Cancel the deletion of this node',							'Undelete'],
	'copy'				=> ['Make a copy of this node and all of its sub-nodes',				'Copy'],
	'properties'			=> ['Change properties of this node', 							'Properties'],
	'manage files'			=> ['Upload and modifiy files contained within this node',			'Manage Files'],
	'view current'			=> ['View the current version of this node on the website', 			'View Current'],
	'move up'				=> ['Swap the position of this node with that of the previous node', 	'Move Up'],
	'move down'			=> ['Swap the position of this node with that of the next node', 		'Move Down'],
);

#####################################################
# Function: createButton
# Parameters: button's ID (entry of buttondata hash), url of the button, 
#		title text describing disabled state (should be empty string if not disabled), 
#		target window of the button
# Return value: button's HTML
# 
# Purpose: Creates the HTML for a button (which is actually a hyperlink). This 
#	function is intended for use on the front page of the CMS.
#
sub createButton
{
	my $buttonid = shift;
	my $url = shift;
	my $disabled = shift;
	my $target = shift || "";
	
	$target = " onclick=\"window.open(this.href,'$target'); return false;\"" if $target;
	
	
	my $dataref = $buttondata{$buttonid};
	
	my $text = escapeForHTML($$dataref[1]);
	$url = escapeForHTMLAttribute($url);
	if($disabled)
	{
		return " <a title=\"" . escapeForHTMLAttribute($disabled) . "\"$target class=\"disabled\" onclick=\"return false;\">$text</a>";
	}
	return " <a href=\"$url\" title=\"" . escapeForHTMLAttribute($$dataref[0]) . "\"$target>$text</a>";
}

#####################################################
# Function: mainCMSListCloseFunc
# Parameters: See purpose of generateList()
# Return value: String (See purpose of generateList())
# 
# Purpose: Outputs the closing of the list item for a node when generating the main
# 	CMS page's tree.
#
sub mainCMSListCloseFunc
{
	my %dirinfo = %{$_[0]}; shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;
	#my $mode = shift; # commented only because it's not used
	
	my $newline = "\n" . "\t" x ($depth-1);

	if ($recurse) # recursed?
	{
		return "</ul$newline></li$newline>";
	}
	else
	{
		return "</li$newline>";
	}
}

#####################################################
# Function: mainCMSListCloseFunc
# Parameters: See purpose of generateList()
# Return value: Recursion mode (see purpose of generateList())
# 
# Purpose: Outputs the current mode of recursion. 1 is normal recursion, 2 indicates
#		that an ancestor was hidden, and 3 indicates that an ancestor was 
#		marked for deletion.
#
sub mainCMSListRecurseFunc
{
	my $dirinforef = shift;
	return $marked_for_deletion_mode if ($$dirinforef{'marked_for_deletion'}); # mode 3 indicates an ancestor was marked for deletion
	return $hidden_mode if ($$dirinforef{'hidden'}); # mode 2 indicates an ancestor was hidden
	return 1;
}

1;
