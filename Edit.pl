#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)


#####################################################
sub templateRequestGenerator
{
	my $FH = shift;
	
	my @inputlist;
	my @selectinput;

	my %dirinfo = getDirInfo($requestinfo{'node'});

	$inputlist[0] = getTemplateDropdown('page_template', $dirinfo{'page_template'}, $config{'pagetemplatespath'});
	
	$inputlist[1] = getTemplateDropdown('content_template', $dirinfo{'content_template'}, $config{'contenttemplatespath'});
	
	$inputlist[2] = ["hidden", "node", "node", [$requestinfo{'node'}]];
	
	print $FH "<div class=\"smallformcontainer\">\n";
	generateForm($FH, "templatechooser", "settemplate", \@inputlist);
	print $FH "</div>\n";
}

sub getTemplateDropdown
{
	my $templatetype = shift;
	my $defaulttemplate = shift;
	my $templatedir = shift;
	
	my @selectinput;
	my @selectinputdata;
	my @options;

	opendir(DIR, $templatedir);
	my @templates = readdir(DIR);
	closedir(DIR);
	
	my $defaultindex = 0;
	
	my $i=0;
	foreach $template (@templates)
	{
		next if ($template eq '.');
		next if ($template eq '..');
		next if (!(-f $templatedir.$template));
		
		my $displaytext = $template;
		$displaytext =~ s/(.*)\..*$/$1/; # truncate file extension
		
		$defaultindex = $i if ($template eq $defaulttemplate);
		
		push @options, [$displaytext, $template];
		
		$i++;
	}
	
	$selectinputdata[0] = \@options;
	$selectinputdata[1] = $defaultindex;
	
	$selectinput[0] = "select";
	$selectinput[1] = $paramlabels{$templatetype};
	$selectinput[2] = $templatetype;
	$selectinput[3] = \@selectinputdata;
	
	return \@selectinput;
}

sub editFormGenerator
{
	my $FH = shift;
	
	print $FH "<div class=\"largeformcontainer\">\n";
	
	my %dirinfo = getDirInfo($requestinfo{'node'});
	
	my @templateformfields;
	$templateformfields[0] = getTemplateDropdown('page_template', $dirinfo{'page_template'}, $config{'pagetemplatespath'});
	$templateformfields[1] = getTemplateDropdown('content_template', $dirinfo{'content_template'}, $config{'contenttemplatespath'});
	$templateformfields[2] = ["hidden", "node", "node", [$requestinfo{'node'}], {}, "settemplatenode"];
	generateForm($FH, "templateform", "settemplate", \@templateformfields, {'onsubmit' => "return confirm('Are you sure you want to change the template? Proceeding will permanently delete this node\\'s content.');"});

	my %dirinfo = getDirInfo($requestinfo{'node'});
	my $formfieldsref = getFormFieldsFromTemplate($config{'contenttemplatespath'}.$dirinfo{'content_template'}, makeSystemPath($requestinfo{'node'}).$config{'contentfile'});
	generateForm($FH, "editform", "save", $formfieldsref);

	print $FH "</div>\n";
}


sub urlChooserGenerator
{
	my $FH = shift;

	print $FH "<div class=\"largeformcontainer\" id=\"urlchooser\">\n<ul id=\"urlchooserlist\">";
	print $FH generateList($config{'delimiter'}, \&urlChooserListOpenFunc, \&urlChooserListCloseFunc, \&urlChooserListRecurseFunc);
	print $FH "</ul>\n</div>\n";
}

 # THIS FUNCTION CONTAINS UNESCAPED HTML
sub urlChooserListOpenFunc
{
	my %dirinfo = %{$_[0]}; shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;
	my $mode = shift;
	
	my $newline = "\n" . "\t" x $depth;
	my $toreturn = '';

	$toreturn .= "<li><div class=\"node\">";
	
	my $nodetext = getNodeName($treepath) . " (\"$dirinfo{'display_name'}\")";
	$nodetext = "Root" if ($depth == 0);
	$toreturn .= "$nodetext ";
	$toreturn .= "<a href=\"\" onclick=\"return chooseURL('$treepath');\" title=\"Select as URL destination\" class=\"linkbutton\">Select</a> ";
	$toreturn .= "<a href=\"$config{'webscriptpath'}?action=upload&amp;node=$treepath\" target=\"_blank\" title=\"Manage the files for this node\" class=\"linkbutton\">Manage Files</a> ";
	
	my $filelist = '';
	foreach my $filetype (@fileTypes)
	{
		my $dirpath = makeSystemPath($treepath . $fileTypeFolders{$filetype});
		my @files = sort(&getAllFilesInFolder($dirpath));
		if (scalar(@files))
		{
			$filelist .= "<strong>$fileTypeCaptions{$filetype}</strong>";
			$filelist .= '<ul>';
			foreach $file (@files)
			{
				$filelist .= "<li><a href=\"\" onclick=\"return chooseURL('$treepath$fileTypeFolders{$filetype}$config{'delimiter'}$file')\" title=\"Select as URL destination\">$file</a></li$newline\t>";
			}
			$filelist .= '</ul>';
		}
	
	}
	my $treepathid;
	if ($filelist)
	{
		$treepathid = $treepath;
		$treepathid =~ s/$config{'escapeddelimiter'}/_/g;
		$treepathid = "filelist_$treepathid";

		$toreturn .= "<a href=\"\" onclick=\"return toggleDisplay('$treepathid');\" title=\"Choose one of this node's files as the URL destination\" class=\"linkbutton\">Toggle File View</a>";
		$toreturn .= "<div class=\"filelist\" id=\"$treepathid\">$filelist</div>";
	}
	$toreturn .= "</div>";
	
	if ($recurse)
	{
		$toreturn .= "<ul$newline>";
	}
	return $toreturn;
}
sub urlChooserListCloseFunc
{
	my %dirinfo = %{$_[0]}; shift;
	my $depth = shift;
	my $numchildren = shift;
	my $treepath = shift;
	my $recurse = shift;
	my $mode = shift;
	
	my $newline = "\n" . "\t" x $depth;

	if ($recurse) # recursed?
	{
		return "</ul$newline></li$newline>";
	}
	else
	{
		return "</li$newline>";
	}
}
sub urlChooserListRecurseFunc
{
	my $dirinforef = shift;
	return !($$dirinforef{'marked_for_deletion'});
}

1;
