#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

#####################################################
# Content.pl
#
#  This file contains three functions (and their helper functions), each of which
#  deal with content XML files, and content templates.
#
#  They all have to do with the storage of content data. getFormFieldsFromTemplate()
#  creates the form with which one can edit a node's content. saveContent() takes the submitted
#  form data and saves it to the node's content.xml. outputFinalizedContent() takes the
#  saved data and the template and creates the final (X)HTML content out of it.
#
#  The content is heavily linked to the format of the template file. Both are stored in XML.
#  The template file has a very specific, as of yet undocumented format. <input> nodes in the 
#  template file are linked to <data> nodes in the content file. Text data in the template 
#  file will be output to the final page.
#
#  For instance, the following template segment:
#
#   &lt;p&gt;<input type="text" id="paragraphtext" Label="Paragraph Text" />&lt;/p&gt;
#
#  linked with the following content segment:
#
#   <data matches="paragraphtext">this text was input by the user</data>
#
#  will produce the following output:
#
#   <p>this text was input by the user</p>
#
#  For more information, look at an existing template file.
#
#  Note that the word "node" in this file is usually referring to an XML node.
#
#####################################################

#####################################################
# Function: getFormFieldsFromTemplate
# Parameters: template and content file paths
# Return value: reference to an array of form fields which can be passed to generateForm
# 
# Purpose: Generates the form fields which can be used to edit a node's content, based
#	on the node's existing content and its content template.
#
sub getFormFieldsFromTemplate
{
	my $templatefile = shift;
	my $contentfile = shift;
	
	
	my @formfields;
	
	my $parser = new XML::DOM::Parser;

	# parse the template file
	open (FH, "<$templatefile");
	readLock(FH);
	my $template = $parser->parse(\*FH, ProtocolEncoding => 'ISO-8859-1');
	unlock(FH);
	close(FH);
	
	# grab first level of template nodes
	my @templatenodes = $template->getDocumentElement()->getChildNodes();
	
	my @contentnodes;
	if (-e $contentfile)
	{
		# parse the content file
		open (FH, "<$contentfile");
		readLock(FH);
		my $content = $parser->parse(\*FH, ProtocolEncoding => 'ISO-8859-1');
		unlock(FH);
		close(FH);
		
		# grab first level of content nodes
		@contentnodes = $content->getDocumentElement()->getChildNodes();
	}
	else
	{
		# if the content file does not exist, pretend it's simply an XML document with no nodes
		@contentnodes = ();
	}
	# do form field generation
	getFormFieldsFromTemplateHelper(\@templatenodes, \@contentnodes, \@formfields, "content_");

	# add a hidden form field saying which node this is
	push @formfields, ["hidden", "node", "node", [$requestinfo{'node'}]];
	
	return \@formfields;
}
#####################################################
# Function: getFormFieldsFromTemplateHelper
# Parameters: current array (reference) of template nodes being worked with,
#			current array (reference) of content nodes being worked with,
#			form fields so far,
#			id prefix for form field IDs so far
# Return value: none
# 
# Purpose: Implements the recursion for getFormFieldsFromTemplate. 
#		Goes through the list of template nodes, and generates the 
#		appropriate form fields for each. Makes use of the list of content nodes
#		to get the default values for each form field (so that the generated form
#		contains the node's current content).
#
# 		Should throw errors when required attributes are not specified!
#
sub getFormFieldsFromTemplateHelper
{
	my $templatenodes = shift;
	my $contentnodes = shift;
	my $formfields = shift;
	my $idprefix = shift;
	
	# for each node in the list of template nodes...
	foreach $node (@$templatenodes)
	{
		# ...if it's an input node (that's not linked to another input node)
		if ($node->getNodeName() eq "input" && !$node->getAttribute('linkedto'))
		{
			my @formfield;
			# if it's a text input node
			if ($node->getAttribute('type') eq 'textarea' || $node->getAttribute('type') eq 'text')
			{
				# start creation of the form field
				$formfield[0] = $node->getAttribute('type');
				$formfield[1] = $node->getAttribute('label');
				$formfield[2] = $idprefix . $node->getAttribute('id');
				
				$formfield[3] = [""]; # default default value. maybe allow this to be specified in the template itself later on
				
				# find corresponding node in the content file (if there is one) and use its text as the default value
				my $contentnode = getMatchingNode($contentnodes, 'data', 'matches', $node->getAttribute('id'));
				if (defined $contentnode && defined $contentnode->getFirstChild()) {
					#$formfield[3] = [unescapeForCDATA($contentnode->getFirstChild()->getData())]; # grab default value from existing content file
					$formfield[3] = [$contentnode->getFirstChild()->getData()]; # grab default value from existing content file
				}
				
				# add the new form field
				push @$formfields, \@formfield;
				
				# if it's a textarea, add a dropdown which lets the user specify how the text should be parsed
				if ($node->getAttribute('type') eq 'textarea')
				{
					# create select dropdown
					my @parseoptionsfield;
					$parseoptionsfield[0] = 'select';
					$parseoptionsfield[1] = 'Applied Format Type'; #  (' . ((defined $contentnode) ? $contentnode->getAttribute('formatting-level') : 'fdsa') . ')
					$parseoptionsfield[2] = $idprefix . $node->getAttribute('id') . '_parseoptions_';
					# determine default selectedindex
					my $defaultformattingtype = 1;
					if (defined $contentnode && $contentnode->getAttribute('formatting-level') ne "")
					{
						$defaultformattingtype = $contentnode->getAttribute('formatting-level');
					}
					# create select dropdown
					$parseoptionsfield[3] = [[['Full Formatting',2],['Simple Formatting',1],['No Formatting (Raw XHTML)',0]], 2-$defaultformattingtype];
					
					# append select dropdown to form field list
					push @$formfields, \@parseoptionsfield;
				}
			}
			# if it's a url input node
			elsif ($node->getAttribute('type') eq 'url')
			{
				# start creation of the form field
				$formfield[0] = 'url';
				$formfield[1] = $node->getAttribute('label');
				$formfield[2] = $idprefix . $node->getAttribute('id');
				
				$formfield[3] = [""];
				
				#find corresponding node in the content file (if there is one) and use its text as the default value
				my $contentnode = getMatchingNode($contentnodes, 'data', 'matches', $node->getAttribute('id'));
				if (defined $contentnode && defined $contentnode->getFirstChild()) {
					$formfield[3] = [unescapeForCDATA($contentnode->getFirstChild()->getData())]; # grab default value from existing content file
				}
				
				# add the new form field
				push @$formfields, \@formfield;
			}
			# boolean, etc
			# NEW INPUT TYPES HERE!
		}
		# ...if it's a choose node (that's not linked to another choose node)
		elsif ($node->getNodeName() eq "choose" && !$node->getAttribute('linkedto'))
		{
			# start creation of the form field
			my @formfield;
			$formfield[0] = 'select';
			$formfield[1] = $node->getAttribute('label');
			$formfield[2] = $idprefix . $node->getAttribute('id');
			
			# options to be put into the choice dropdown
			my @selectoptions;
			my $currentchoice = 0; # default default index. maybe allow this to be specified in the template itself later on
			
			# list of fieldsets form elements, each of which represent a choice
			my @fieldsets;

			# get the content 'choice' node which matches this template node
			my $correspondingcontentnode = getMatchingNode($contentnodes, 'choice', 'matches', $node->getAttribute('id'));

			# get the different possible choices
			my @choices = $node->getChildNodes();
			#for each choice...
			my $i = 0;
			foreach my $choice (@choices)
			{
				# (make sure this is, in fact, a choice node)
				if ($choice->getNodeName() eq 'choice')
				{
					# make  select dropdown option for this choice
					push @selectoptions, [$choice->getAttribute('label'), $idprefix . $choice->getAttribute('id')];
					# if this is the choice which has been made, remember it for later
					if (defined $correspondingcontentnode && $correspondingcontentnode->getAttribute("choicemade") eq $choice->getAttribute('id'))
					{
						$currentchoice = $i;
					}

					$i++;
				}
			}
			# finish the choice dropdown
			$formfield[3] = [\@selectoptions, $currentchoice];
			$formfield[4] = {'onchange' => "makeChoice(this);", 'class' => 'choicechooser'};
			# append the choice dropdown: this can be used to change the chosen choice.
			push @$formfields, \@formfield;
			
			# for each choice, create its fieldset
			$i = 0;
			foreach my $choice (@choices)
			{
				# (make sure this is a choice node)
				if ($choice->getNodeName() eq 'choice')
				{
					# start fieldset creation
					my @fieldset;
					$fieldset[0] = 'fieldset';
					$fieldset[1] = $choice->getAttribute('label');
					$fieldset[2] = $idprefix . $choice->getAttribute('id');
					
					# get the content nodes within this content 'choice' node
					my $childcontentnodes = [];
					if (defined $correspondingcontentnode && $currentchoice == $i) {
						$childcontentnodes = [$correspondingcontentnode->getChildNodes()];
					}

					# set HTML style attribute of the fieldset
					my %fieldsetattributehash;
					$fieldsetattributehash{'style'} = 'display:none;';
					if ($currentchoice == $i) {
						$fieldsetattributehash{'style'} = 'display:block;';
					}
					
					# complete fieldset creation
					$fieldset[3] = [];
					$fieldset[4] = \%fieldsetattributehash;
					
					# get the form fields for this fieldset by recursing
					getFormFieldsFromTemplateHelper([$choice->getChildNodes()], $childcontentnodes, $fieldset[3], $idprefix);
					
					# if this choice has any fields associated with it, add it to the list of formfields
					# (the if keeps empty fieldsets from appearing)
					if (scalar(@{$fieldset[3]}))
					{
						push @$formfields, \@fieldset;
					}
					
					$i++;
				}
			}
		}
		# ...if it's a repetition node
		elsif ($node->getNodeName() eq "repetition")
		{
			# start fieldset creation for this repetition
			my @fieldset;
			$fieldset[0] = 'fieldset';
			$fieldset[1] = $node->getAttribute('label');
			$fieldset[2] = $idprefix . $node->getAttribute('id');
			$fieldset[3] = [];
			
			# append to the idprefix, to avoid HTML ID/name collisions
			my $newidprefix = $idprefix . $node->getAttribute('id') . "_";

			# give a general-purpose version of this repetition (a repetition element "prototype")
			# so that new repetition elements can be created with javascript
			my @generalfieldset;
			$generalfieldset[0] = 'fieldset';
			$generalfieldset[1] = $node->getAttribute('singularlabel');
			$generalfieldset[2] = $newidprefix . "prototype_";
			$generalfieldset[3] = [];
			$generalfieldset[4] = {'style' => 'display:none;'};
			# recurse to get the fieldset's contents. No content nodes are passed, since there is obviously no content associated 
			# with a new repetition element when the user clicks the "new" button.
			getFormFieldsFromTemplateHelper([$node->getChildNodes()], [], $generalfieldset[3], $newidprefix . '_');

			# create the remove button for the repetition element prototype
			my @removebutton;
			$removebutton[0] = 'button';
			$removebutton[1] = 'Remove ' . $node->getAttribute('singularlabel');
			$removebutton[2] = $newidprefix . "_remove_";
			$removebutton[3] = [];
			$removebutton[4] = {'onclick' => 'removeRepetition(this)'};

			# create the move-up button for the repetition element prototype
			my @moveupbutton;
			$moveupbutton[0] = 'button';
			$moveupbutton[1] = 'Move Up';
			$moveupbutton[2] = $newidprefix . "_moveup_";
			$moveupbutton[3] = [];
			$moveupbutton[4] = {'onclick' => 'moveRepetition(this, -1)'};
			
			# create the move-down button for the repetition element prototype
			my @movedownbutton;
			$movedownbutton[0] = 'button';
			$movedownbutton[1] = 'Move Down';
			$movedownbutton[2] = $newidprefix . "_movedown_";
			$movedownbutton[3] = [];
			$movedownbutton[4] = {'onclick' => 'moveRepetition(this, 1)'};

			# add the buttons to the repetition element prototype
			push @{$generalfieldset[3]}, \@removebutton;
			push @{$generalfieldset[3]}, \@moveupbutton;
			push @{$generalfieldset[3]}, \@movedownbutton;

			# add the repetition element prototype
			push @{$fieldset[3]}, \@generalfieldset;

			my $repetitionnum = 0; 
			# find the repetitionset node in the content XML which matches this repetition template node
			my $repetitionset = getMatchingNode($contentnodes, 'repetitionset', 'matches', $node->getAttribute('id'));
			# if it was found
			if (defined $repetitionset)
			{
				# get the repetitions in the content file
				my @repetitions = $repetitionset->getChildNodes();
				# get the number of repetitions
				my $numrepetitions = 0;
				foreach my $repetition (@repetitions) {
					$numrepetitions++ if ($repetition->getNodeName() eq "repetition");
				}
				# for each repetition in the content file
				foreach my $repetition (@repetitions)
				{
					# (make sure it's a repetition node)
					if ($repetition->getNodeName() eq "repetition")
					{
						# start creating the repetition element's fieldset
						my @repetitionfieldset;
						$repetitionfieldset[0] = 'fieldset';
						$repetitionfieldset[1] = $node->getAttribute('singularlabel') . " #" . ($repetitionnum+1);
						$repetitionfieldset[2] = $idprefix . $node->getAttribute('id') . "_" . $repetitionnum . "_fieldset_";
						$repetitionfieldset[3] = [];

						# recursively grab the form fields for this repetition element
						getFormFieldsFromTemplateHelper([$node->getChildNodes()], [$repetition->getChildNodes()], $repetitionfieldset[3], $newidprefix . $repetitionnum . "_");

						# create the remove button for this repetition element
						my @removebutton;
						$removebutton[0] = 'button';
						$removebutton[1] = 'Remove ' . $node->getAttribute('singularlabel');
						$removebutton[2] = $newidprefix . $repetitionnum . "_remove_";
						$removebutton[3] = [];
						$removebutton[4] = {'onclick' => 'removeRepetition(this)'};
						
						# create the move-up button for this repetition element
						my @moveupbutton;
						$moveupbutton[0] = 'button';
						$moveupbutton[1] = 'Move Up';
						$moveupbutton[2] = $newidprefix . $repetitionnum . "_moveup_";
						$moveupbutton[3] = [];
						$moveupbutton[4] = {'onclick' => 'moveRepetition(this, -1)'};
						if ($repetitionnum == 0) {
							${$moveupbutton[4]}{'disabled'} = 'disabled';
						}
						
						# create the move-down button for this repetition element
						my @movedownbutton;
						$movedownbutton[0] = 'button';
						$movedownbutton[1] = 'Move Down';
						$movedownbutton[2] = $newidprefix . $repetitionnum . "_movedown_";
						$movedownbutton[3] = [];
						$movedownbutton[4] = {'onclick' => 'moveRepetition(this, 1)'};
						if ($repetitionnum == $numrepetitions-1) {
							${$movedownbutton[4]}{'disabled'} = 'disabled';
						}

						# append the buttons for this repetition element
						push @{$repetitionfieldset[3]}, \@removebutton;
						push @{$repetitionfieldset[3]}, \@moveupbutton;
						push @{$repetitionfieldset[3]}, \@movedownbutton;
						
						# append the repetition element to the repetition fieldset
						push @{$fieldset[3]}, \@repetitionfieldset;

						$repetitionnum++;
					}
				}
			}
			
			# make a hidden form field which tells how many repetition elements there were
			my @hidden;
			$hidden[0] = 'hidden';
			$hidden[1] = "";
			$hidden[2] = $newidprefix . "count_";
			$hidden[3] = [$repetitionnum];

			# add the hidden form field
			push @{$fieldset[3]}, \@hidden;
			
			# make a 'new' button
			my @newbutton;
			$newbutton[0] = 'button';
			$newbutton[1] = "New " . $node->getAttribute('singularlabel');
			$newbutton[2] = $newidprefix . "new_";
			$newbutton[4] = {'onclick' => 'newRepetition(this);'};
			
			# add the 'new' button
			push @{$fieldset[3]}, \@newbutton;
			
			# add the repetition fieldset to the list of form fields
			push @$formfields, \@fieldset;
		}
	}
}

#####################################################
# Function: saveContent
# Parameters: template and content file paths
# Return value: 1 if success, 0 if failure
# 
# Purpose: By reading from CGI parameters, this saves content
#		to a node, based on the node's template. This only works
#		right, obviously, if the form created by getFormFieldsFromTemplate()
#		has been submitted, and its CGI parameters are currently available
#		through a global CGI object named q.
#
sub saveContent
{
	my $templatefile =shift;
	my $contentfile = shift;
	
	my $parser = new XML::DOM::Parser;

	# parse the template file
	open (FH, "<$templatefile") or die "error in saveContent().  couldn't open $templatefile.\n$!";
	readLock(FH);
	my $template = $parser->parse(\*FH, ProtocolEncoding => 'ISO-8859-1');
	unlock(FH);
	close(FH);
	
	# get the first level of template nodes
	my @templatenodes = $template->getDocumentElement()->getChildNodes();
	
	# parse the content file
	open (FH, "<$config{'datadirpath'}$config{'defaultcontentfile'}") or die "error in saveContent().  couldn't open $config{'datadirpath'}$config{'defaultcontentfile'}.\n$!";
	readLock(FH);
	my $content = $parser->parse(\*FH, ProtocolEncoding => 'ISO-8859-1');
	unlock(FH);
	close(FH);
	
	# save the content
	if (!saveContentHelper(\@templatenodes, $content->getDocumentElement(), $content, "content_"))
	{
		# content failed to save
		return 0;
	}
	
	# print the content file as XML
	$content->printToFile($contentfile);
	
	return 1;
}
#####################################################
# Function: saveContentHelper
# Parameters: current array (reference) of template nodes being worked with,
#			current array (reference) of content nodes being worked with,
#			document object of the content document,
#			id prefix of CGI parameters so far
# Return value: 1 if success, 0 if failure
# 
# Purpose: Implements the recursion for saveContent(). Goes through the list of template nodes,
#			finds the CGI parameters that correspond to each, and saves the CGI parameter values
#			to the content XML file. Upon finding a choose or repetition node, recurses deeper as 
#			necessary.
#
sub saveContentHelper
{
	my $templatenodes = shift;
	my $contentnode = shift;
	my $contentdocument = shift;
	my $idprefix = shift;

	# loop through each node in the list of template nodes
	foreach my $node (@$templatenodes)
	{
		# if it's an input node (which isn't linked to another input node)
		if ($node->getNodeName() eq "input" && !$node->getAttribute('linkedto'))
		{
			# make sure its 'id' attribute is defined
			if (!(defined $node->getAttribute('id')))
			{
				$STATUS_FLAG = 28;
				return 0;
			}
			# create a content 'data' node which 'matches' this template 'input' node
			my $datanode = $contentdocument->createElement('data');
			$contentnode->appendChild($datanode);
			$datanode->setAttribute('matches', $node->getAttribute('id'));
			
			# if it's a known input type...
			if ($node->getAttribute('type') eq 'textarea' || $node->getAttribute('type') eq 'text' || $node->getAttribute('type') eq 'url')
			{
				# grab the value from the cgi form and put it in the new content node
				my $value = $q->param($idprefix . $node->getAttribute('id'));
				if (!(defined $value))
				{
					$STATUS_FLAG = 27;
					return 0;
				}
				$datanode->appendChild($contentdocument->createTextNode($value));
				
				# if it's a textarea node, save the parse-type choice the user made in the dropdown
				if ($node->getAttribute('type') eq 'textarea')
				{
					my $param = $q->param($idprefix . $node->getAttribute('id') . '_parseoptions_');
					if (!(defined $param))
					{
						$STATUS_FLAG = 27;
						return 0;
					}
					# remember the parse type
					$datanode->setAttribute('formatting-level', $param);
				}
				# boolean, dropdown, etc, if ever implemented
				
				# ummmm... should this line even be here? it looks like it got copied and pasted from getFormFieldsFromTemplateHelper...
				push @$formfields, \@formfield;
			}
		}
		# if it's a choose node (which isn't linked to another choose node)
		elsif ($node->getNodeName() eq "choose" && !$node->getAttribute('linkedto'))
		{
			# make sure its 'id' attribute is defined
			if (!(defined $node->getAttribute('id')))
			{
				$STATUS_FLAG = 28;
				return 0;
			}
			# create a new content 'choice' element which 'matches' the template 'choose' element
			my $choiceelement = $contentdocument->createElement('choice');
			$contentnode->appendChild($choiceelement);
			$choiceelement->setAttribute('matches', $node->getAttribute('id'));
			
			# determine which choice was made by the user
			my $choicemade = $q->param($idprefix . $node->getAttribute('id'));
			if(!(defined $choicemade))
			{
				$STATUS_FLAG = 27;
				return 0;
			}
			$choicemade =~ s/.*_(.*)$/$1/;
			
			# save which choice was made
			$choiceelement->setAttribute('choicemade', $choicemade);
			
			# get the template choice node which corresponds with the choice that was made
			my $chosenchoicenode = getMatchingNode([$node->getChildNodes()], 'choice', 'id', $choicemade);
			if (!(defined $chosenchoicenode))
			{
				$STATUS_FLAG = 27;
				return 0;
			}

			# recursively save the contents of the choice
			if (!saveContentHelper([$chosenchoicenode->getChildNodes()], $choiceelement, $contentdocument, $idprefix))
			{
				return 0;
			}
		}
		# if it's a repetition node
		elsif ($node->getNodeName() eq "repetition")
		{
			# make sure its 'id' attribute is defined
			if (!(defined $node->getAttribute('id')))
			{
				$STATUS_FLAG = 28;
				return 0;
			}
			
			# append the repetition node's id to the idprefix to avoid HTML id/name collisions
			my $newidprefix = $idprefix . $node->getAttribute('id') . "_";
			
			# create a content 'repetitionset' element which 'matches' this template 'repetition' element
			my $repetitionset = $contentdocument->createElement('repetitionset');
			$contentnode->appendChild($repetitionset);
			$repetitionset->setAttribute('matches', $node->getAttribute('id'));
			
			# get the number of repetitions being saved
			my $numrepetitions = $q->param($newidprefix . "count_") || 0;
			if (!(defined $numrepetitions))
			{
				$STATUS_FLAG = 27;
				return 0;
			}
			# for each repetition being saved...
			for (my $rep = 0; $rep < $numrepetitions; $rep++)
			{
				# ...create a content 'repetition' element for it...
				my $repetition = $contentdocument->createElement("repetition");
				$repetitionset->appendChild($repetition);
				
				# ...and recursively save its contents
				if (!saveContentHelper([$node->getChildNodes()], $repetition, $contentdocument, $newidprefix . $rep . "_"))
				{
					return 0;
				}
			}
		}
	}
	return 1;
}


#####################################################
# Function: outputFinalizedContent
# Parameters: file handle to output to, template and content file paths
# Return value: 1 if success, 0 if failure
# 
# Purpose: By reading from the template file and the corresponding content
#		file, this function outputs the final HTML content as dictated
#		by the template file, filling in content where the template file
#		says to do so.
#
sub outputFinalizedContent
{
	my $FH = shift;
	my $templatefile = shift;
	my $contentfile = shift;
	
	my $parser = new XML::DOM::Parser;

	# parse the template file
	open (TEMPLATEFILE, "<$templatefile") or die "error in outputFinalizedContent().  couldn't open $templatefile.\n$!";
	readLock(TEMPLATEFILE);
	my $template = $parser->parse(\*TEMPLATEFILE, ProtocolEncoding => 'ISO-8859-1');
	unlock(TEMPLATEFILE);
	close(TEMPLATEFILE);
	
	# get the first level of template nodes
	my @templatenodes = $template->getDocumentElement()->getChildNodes();

	# parse the content file
	my @contentnodes;
	if (-e $contentfile)
	{
		open (CONTENTFILE, "<$contentfile") or die "error in outputFinalizedContent().  couldn't open $contentfile.\n$!";
		readLock(CONTENTFILE);
		my $content = $parser->parse(\*CONTENTFILE, ProtocolEncoding => 'ISO-8859-1');
		unlock(CONTENTFILE);
		close(CONTENTFILE);
		
		# get the first level of content nodes
		@contentnodes = $content->getDocumentElement()->getChildNodes();
	}
	else
	{
		# if the content file doesn't exist, pretend it's an XML document with no nodes
		@contentnodes = ();
	}
	
	# output the finalized content
	if (!outputFinalizedContentHelper($FH, \@templatenodes, \@contentnodes))
	{
		# content failed to output
		return 0;
	}
	
	return 1;
}
#####################################################
# Function: outputFinalizedContentHelper
# Parameters: file handle to output to,
#			current array (reference) of template nodes being worked with,
#			current array (reference) of content nodes being worked with,
# Return value: 1 if success, 0 if failure
# 
# Purpose: Goes through the list of template nodes and outputs any text nodes
#		encountered. Upon the discovery of an input node, finds the corresponding
#		content node and outputs its content. Upon the discovery of a choose or 
#		repetition node, recurses deeper.
#
sub outputFinalizedContentHelper
{
	my $FH =shift;
	my $templatenodes = shift;
	my $contentnodes = shift;

	# for each template node in the list...
	foreach $node (@$templatenodes)
	{
		# should this line even be here? looks like it was copied and pasted from getFormFieldsFromTemplateHelper...
		my @formfield;
		
		# ...if it's an input node
		if ($node->getNodeName() eq "input")
		{
			my $inputnode = $node;
			# if this is simply "linked to" another input node in the template, find that one and work with it instead of this one
			if ($node->getAttribute('linkedto'))
			{
				# (find the linked to input node)
				$inputnode = getMatchingNode($templatenodes, 'input', 'id', $node->getAttribute('linkedto'));
				if(!(defined $inputnode))
				{
					$STATUS_FLAG = 34;
					return 0;
				}
			}
			
			# make sure the node's id is defined
			if (!(defined $inputnode->getAttribute('id')))
			{
				$STATUS_FLAG = 31;
				return 0;
			}
			# if it's a recognized input type...
			if ($inputnode->getAttribute('type') eq 'textarea' || $inputnode->getAttribute('type') eq 'text' || $inputnode->getAttribute('type') eq 'url' )
			{
				# ...find the corresponding 'data' node in the content file which 'matches' this 'input' node
				my $contentnode = getMatchingNode($contentnodes, 'data', 'matches', $inputnode->getAttribute('id'));
				if(!(defined $contentnode))
				{
					# no longer throwing an error: we'll simply skip over this input node
					#$STATUS_FLAG = 30;
					#return 0;#
				}
				else
				{
					# if the content node has text inside of it
					if (defined $contentnode->getFirstChild() && ($contentnode->getFirstChild()->getNodeType() == XML::DOM::CDATA_SECTION_NODE || $contentnode->getFirstChild()->getNodeType() == XML::DOM::TEXT_NODE))
					{
						# get the text
						#my $input = unescapeForCDATA($contentnode->getFirstChild()->getData());
						my $input = $contentnode->getFirstChild()->getData();

						# ignore this
						#open (TEMP, ">/var/apache/sites/cms/htdocs/temp.txt");
						#print TEMP $input;
						#close (TEMP);

						# output the text depending on the input type
						if ($inputnode->getAttribute('type') eq 'textarea')
						{
							# parse the text depending on the parse type of the textarea
							if ($contentnode->getAttribute('formatting-level') == 0)
							{
								# they typed raw XHTML
								print $FH $input;
							}
							elsif ($contentnode->getAttribute('formatting-level') == 1)
							{
								# we're parsing just for things that look like tags
								print $FH &parseBlockLevelInput($input, 0);
							}
							else
							{
								# we're parsing for anything
								print $FH &parseBlockLevelInput($input, 1);
							}
						}
						if ($inputnode->getAttribute('type') eq 'text')
						{
							# only parse the text input if HTML is allowed, according to the template
							if ($inputnode->getAttribute('allowhtml') eq 'false') {
								print $FH $input;
							}
							else {
								print $FH &parseInlineInput($input);
							}
						}
						elsif ($inputnode->getAttribute('type') eq 'url')
						{
							# construct the URL based on whether we're previewing or finalizing
							if ($requestinfo{'action'} eq "preview") {
								print $FH makePreviewURL($input);
							}
							else {
								print $FH makeFinalURL($input);
							}
						}
					}
				}
			}
			# boolean, dropdown, etc
		}
		# ...if it's a choose node
		elsif($node->getNodeName() eq "choose")
		{
			my $correspondingcontentnode;
			# if the node is merely linked to another one...
			if ($node->getAttribute('linkedto'))
			{
				# ...get the 'choice' node which 'matches' the 'choose' node which this 'choose' node is 'linkedto'
				$correspondingcontentnode = getMatchingNode($contentnodes, 'choice', 'matches', $node->getAttribute('linkedto'));
			}
			# if the node is not linked to anotehr one...
			else
			{
				# ...make sure the node has its id attribute set...
				if (!(defined $node->getAttribute('id')))
				{
					$STATUS_FLAG = 31;
					return 0;
				}

				# ...and find the content 'choice' node which 'matches' this template 'choose' node
				$correspondingcontentnode = getMatchingNode($contentnodes, 'choice', 'matches', $node->getAttribute('id'));
			}
			
			# make sure we found the content 'choice' node successfully
			if(!(defined $correspondingcontentnode))
			{
				# no longer throwing an error: we'll simply skip over this choose node
				#$STATUS_FLAG = 30;
				#return 0;
			}
			else
			{
				# figure out which choice was made
				my $choicemade = $correspondingcontentnode->getAttribute('choicemade');
				if(!(defined $choicemade))
				{
					$STATUS_FLAG = 32;
					return 0;
				}

				# find the template 'choice' node which was chosen
				my $chosenchoicenode = getMatchingNode([$node->getChildNodes()], 'choice', 'id', $choicemade);
				if(!(defined $chosenchoicenode))
				{
					$STATUS_FLAG = 33;
					return 0;
				}

				# recursively output the contents of the choice
				if (!outputFinalizedContentHelper($FH, [$chosenchoicenode->getChildNodes()], [$correspondingcontentnode->getChildNodes()]))
				{
					return 0;
				}
			}
		}
		# ...if it's a repetition node
		elsif($node->getNodeName() eq "repetition")
		{
			# make sure its id attribute is set
			if (!(defined $node->getAttribute('id')))
			{
				$STATUS_FLAG = 31;
				return 0;
			}
			
			# find the content 'repetitionset' node which 'matches' this 'repetition' node
			my $repetitionset = getMatchingNode($contentnodes, 'repetitionset', 'matches', $node->getAttribute('id'));
			# make sure it was found
			if(!(defined $repetitionset))
			{
				# no longer throwing an error: we'll simply skip over this repetition node
				#$STATUS_FLAG = 30;
				#return 0;
			}
			else
			{
				# for each repetition element in the repetition set...
				my @repetitions = $repetitionset->getChildNodes();
				foreach my $repetition (@repetitions)
				{
					# (make sure it's a repetition node)
					if($repetition->getNodeName() eq "repetition")
					{
						# recursively output the contents of the repetition element
						if (!outputFinalizedContentHelper($FH, [$node->getChildNodes()], [$repetition->getChildNodes()])) {
							return 0;
						}
					}
				}
			}
		}
		# ...if it's a 'text' node (that is, <text ...>, not a real text node)
		elsif ($node->getNodeName() eq "text")
		{
			# if it has text inside of it
			if (defined $node->getFirstChild() && ($node->getFirstChild()->getNodeType() == XML::DOM::CDATA_SECTION_NODE || $node->getFirstChild()->getNodeType() == XML::DOM::TEXT_NODE))
			{
				# output the text verbatim
				print $FH $node->getFirstChild()->getData();
			}
		}
		# ...if it's a text node (that is, "blahblahblah", not an element)
		elsif ($node->getNodeType() == XML::DOM::TEXT_NODE)
		{
			# get its text
			my $text = $node->getData();
			# output, unless it's pure whitespace
			unless ($text =~ /\A\s*\z/m) {
				print $FH $text;
			}
		}
	}
	return 1;
}

#####################################################
# Function: getMatchingNode
# Parameters: reference to array of nodes to search, node names to check, 
#			attribute to match, value that the attribute must have
# Return value: the first node with the required node name whose 
#			attribute matches the given value, or undef if none is found.
# 
# Purpose: Used by many of the above functions in this file to find 
#		content nodes which are associated with template nodes. Searches an 
#		array of nodes, and when a node is found whose node name matches 
#		$requirednodename, and whose attribute $attributetomatch has the value 
#		$valuetomatch, returns that node.
#
sub getMatchingNode
{
	my $nodesref= shift;
	my $requirednodename = shift;
	my $attributetomatch = shift;
	my $valuetomatch = shift;
	foreach my $node (@$nodesref)
	{
		if ($node->getNodeName() eq $requirednodename && $node->getAttribute($attributetomatch) eq $valuetomatch)
		{
			return $node;
		}
	}
	return undef;
}

1;
