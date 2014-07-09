#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

#####################################################
# Output.pl
#
#  This file contains functions which are used to generate output.
#  They are usually called by other functions, and sent function references or 
#  other data as parameters.
#
#####################################################

#####################################################
# Function: generateList
# Parameters: Treepath, \&functionreference, \&functionreference, \&functionreference
# 	the first 2 function references passed contain code which outputs specific markup
#	for the opening/closing of nodes as the tree is recursed
#	the third function reference determines whether a given node should be recursed into
#	or not, and returns a number: 0 indicates no recursion, other values indicate that
#	there should be recursion (if there are any children), and the highest such value
#	(considered the recursion "mode") will be passed into the opening and closing functions
#	of descendant nodes as mentioned below.
#
# Return value: $string which is the list we have generated
# 
# Purpose: to generate a list representing the document tree with a specific node as the root.
#	The tree is traversed (depth-first) using recursion.
#	As each node is begun and completed, the opening and closing functions
#		passed by reference to this function, are called.
#	Those functions are passed the following parameters:
#		\%hashreference to the dir-info of the current node,
#		$depth of the current node with respect to the root given, 
#		the number of children the node has,
#		treepath of the current node,
#		whether the node's children will be recursed into or not (as determined
#			by the third function reference passed to generateList),
#		and the highest recursion "mode" the third function reference has returned for 
#			the *ancestors* of the current node.
#	The functions should return a string which will be appended onto the final string that 
#	generateList returns.
#
#	Looking back, writing this function was a very bad idea. It makes the program more 
#	complicated than it needs to be, and doesn't really accomplish much. It got in the 
#	way more often than not. In the future, if we ever do any heavy editing on this 
#	program again, it should really be removed. Right now though, it's staying, because
#	too much depends on it.
#
sub generateList
{
	my $treepath = shift;
	my $string = "";
	my @array = $treepath =~ /($config{'delimiter'})/g;
	my $depth = scalar(@array) - 1;

	my $numsiblings = 1;
	my $index = 0;
	if($treepath ne $config{'delimiter'})
	{
		$numsiblings = scalar(getChildren(getParentNode($treepath)));
		$index = getSiblingIndex($treepath);
	}
	
	generateListHelper($treepath, makeSystemPath($treepath), \$string, shift, shift, shift, $depth, -1, $numsiblings, $index);
	return $string;
}

#####################################################
# Function: generateListHelper
# Parameters: Treepath, systempath, \$stringreference, \&functionreference, \&functionreference, $depth
# 	The treepath is the path of the node currently being worked with.
#	The system path is the path of the corresponding directory for that node.
# 	The string reference is the string which is constantly being appended to, and will eventually
# 		be returned by generateList.
# 	The two function references are the same as in generateList.
# 	The depth is the depth of the current node with respect to the root passed to generateList.
# Return value: none
# 
# Purpose: Implements the recursion of generateList.
#
sub generateListHelper
{
	my $treepath = shift;
	my $systempath = shift;
	my $stringref = shift;
	my $openfunc = shift;
	my $closefunc = shift;
	my $recursetestfunc = shift;
	my $depth = shift;
	my $oldmode = shift;
	my $numsiblings = shift;
	my $siblingnum = shift;
	
	my %dirinfo = getDirInfo($treepath);
	my @children = getChildren($treepath);

	my $numchildren = scalar(@children);
	my $newmode = &$recursetestfunc(\%dirinfo, $depth, $numchildren, $treepath);
	my $willrecurse = $numchildren && $newmode;

	my $mode = $oldmode;

	# open func
	$$stringref .= &$openfunc(\%dirinfo, $depth, $numchildren, $treepath, $willrecurse, $mode, $numsiblings, $siblingnum);

	$mode = $newmode if ($newmode > $mode); # higher modes take precedence

	#recurse
	if ($willrecurse)
	{
		my $childindex = 0;
		foreach my $child (@children)
		{
			generateListHelper(
				$treepath.$child.$config{'delimiter'},
				$systempath.$child.$config{'systemslash'},
				$stringref,
				$openfunc,
				$closefunc,
				$recursetestfunc,
				$depth+1,
				$mode, 
				$numchildren,
				$childindex
			);
			$childindex++;
		}
	}
	
	$mode = $oldmode;
	
	# close func
	$$stringref .= &$closefunc(\%dirinfo, $depth, $numchildren, $treepath, $willrecurse, $mode, $numsiblings, $siblingnum);
}

#####################################################
# Function: generatePage
# Parameters: File handle to output page to, template file to base page on, token 
# 	hash reference which gives functions to call for each token found.
# Return value: none
# 
# Purpose: Goes through a template file. When tokens such as
# 	<!--#CONTENT -->
# 	are found, the token hash reference (3rd parameter) is dereferenced and checked 
#	for the token ("CONTENT" in this case). The corresponding value of the hash 
#	should be a function pointer. This function is called, and passed the file handle 
#	being worked with. It can do whatever it wants with the file handle.
#	Any additional arguments to generatePage are also sent into the function being called.
#
sub generatePage
{
	my $filehandle = shift;
	my $templatefile = shift;
	my $tokenhashref = shift;
	my @args = @_;
	
	open(TEMPLATE, "<$templatefile") or die "generatePage: cannot open $templatefile\n$!";
	readLock(TEMPLATE);
	chomp(my @temp = <TEMPLATE>);
	unlock(TEMPLATE);
	close(TEMPLATE);
	
	# Go through the template. Output lines as we go, and replace tokens with the output of their respective functions.
	foreach my $line (@temp)
	{
		if($filehandle == \*STDOUT)	#if we're writing to STDOUT
		{
			$line =~ s/$config{"virtualfilepattern"}/&slurp(&webPathToSystemPath($2))/ge;	#searches for SSI includes
		}
		while ($line =~ /$config{"tokenpattern"}/g)
		{
			print $filehandle $`;
			$line = $';
			
			#	Call the function which is associated with the token that we have discovered.
			#	The function is stored by reference in a hash. We dereference the hash, get its token'th entry, and 
			#	dereference the function, before passing it the file handle to work with.
			#	The function does whatever it wants with the filehandle.
			
			if (exists $$tokenhashref{$1})
			{
				&{$$tokenhashref{$1}}($filehandle, @args);
			}
		}
		print $filehandle "$line\n";
	}
}


#####################################################
# Function: parseBlockLevelInput
# Parameters: string to parse; boolean indicating whether stuff that doesn't look like
#		HTML should be parsed (such as "*bold*" and "/italic/")
# Return value: formatted string
# 
# Purpose: Divides a string into "blocks" (as determined by newline characters), 
#	parses each block with the parseBlock function, and returns the result.
#
sub parseBlockLevelInput
{
	my $input = shift;
	my $parseforcharactermarkup = shift; # parse things like "...*bold*..."?
	
	# find paragraphs
	$input =~ s/(\S(?:.|\n)*?)(\n{2,}|\z)/&parseBlock($1, $parseforcharactermarkup)/meg;
	return $input;
}
#####################################################
# Function: parseBlock
# Parameters: string to parse; boolean indicating whether stuff that doesn't look like
#		HTML should be parsed (such as "*bold*" and "/italic/")
# Return value: formatted block
# 
# Purpose: Determines what a block of text represents (paragraph? heading? list?)
#	and adds HTML to turn it into that thing. It then parses the content of the block as
#	inline text with the parseInlineInput function.
#
sub parseBlock
{
	my @lines = split /\n/, shift;
	my $parseforcharactermarkup = shift;
	
	if ($lines[0] =~ /^<h>/ && $lines[scalar(@lines)-1] =~ /<\/h>$/)
	{
		$lines[0] =~ s/^<h>//;
		$lines[scalar(@lines)-1] =~ s/<\/h>$//;
		return "<h3>". &parseInlineInput(join("\n", @lines), $parseforcharactermarkup) ."</h3>";
	}
	if ($parseforcharactermarkup)
	{
		if (scalar(@lines) == 2 && $lines[1] =~ /^-*$/) # look for headers
		{
			my $header = &parseInlineInput($lines[0], $parseforcharactermarkup);
			return "<h3>$header</h3>\n";
		}

		my $char = '';
		$char = $1 if $lines[0] =~ /^([*\-~])/;	
		$char = escapeRegexStr($char);

		if (scalar(@lines) > 1 && $char && scalar( grep {/^$char/} @lines) == scalar(@lines)) # look for lists
		{
			map {s/^$char\s*(.*)$/"<li>" . &parseInlineInput($1, $parseforcharactermarkup) . "<\/li>\n"/eg} @lines;
			return "<ul>\n" . join('', @lines) . "</ul>\n";
		}
	}

	return "<p>". &parseInlineInput(join("\n", @lines), $parseforcharactermarkup) ."<\/p>\n";
}

# This regular expression matches a segment of well-formed XML, perhaps surrounded by text.
# It is made specifically to work well with the below function, and will not necessarily work in all other cases.
# Don't use this unless you understand how it works.
my $wellFormedXML = qr/
	(?:
		(?> [^<>\*\/_&\+]+ ) # Match anything but these characters;
						 # In other words, gobble up all characters found, but when one of these are found, check and see
						 # if we've hit the end of the segment of text that we're in.
						 # If we haven't, since these characters are re-listed at the end of this regular expression,
						 # we'll continue on anyway gobbling up characters.
						 # All characters that might be at the end of the area we're trying to match with this regular expression
						 # must be in both this list and the end of this regex, since this is a non-backtracking subpattern.
		|
		<(?=[^\/]) (\w*?) (?:\s([^>]*?))?\/> # Match a closed XML tag (attributes are not checked for validity)
		|
		<(?=[^\/]) (\w*?) (?:\s([^>]*?))?> # Match an open XML tag
			(??{ $wellFormedXML }) # check that its contents are well-formed
		<\/\2>
		|
		\* | \/ | _ | & | \+ # if we didn't find a well-formed XML tag, and we haven't been able to finish matching the regular expression which
					   # this wellFormedXML expression was included in, continue on to try to match by gobbling up more characters.
	)*?
/x;

#####################################################
# Function: parseInlineInput
# Parameters: string to parse; boolean indicating whether stuff that doesn't look like
#		HTML should be parsed (such as "*bold*" and "/italic/")
# Return value: formatted string
# 
# Purpose: Finds hyperlinks, bold tags, italic tags, line breaks, etc in a string of text
#		and turns it into XHTML. The return value should always be a valid segment
#		of inline XHTML which can be put into a block-level XHTML element.
#
sub parseInlineInput
{
	my $input = shift;
	my $parseforcharactermarkup = shift;

	$input = escapeForHTML($input);

	# new lines ("\n" -> "<br />")
	$input =~ s/\n/<br \/>\n/mg;
	
	# hyperlinks (<a href="..." [target="..."]>...</a>)
	$input =~ s/
		&lt;
			(
				a
				\s+ href \s*=\s* "([^"]*?)"
				(?: \s+ target \s*=\s* "([^"]*?)" )?
			)\s*
		&gt;
		($wellFormedXML)
		&lt;\/a&gt;
		(?![^<>]*?>) # make sure we're not inside an html tag
	/
		'<a href="' . escapeForHTMLAttribute(makeActualURL(unescapeForHTML($2))) . "\"" . 
		($3?" onclick=\"window.open(this.href,'$3'); return false;\"":"") . # open in a new window while retaining valid XHTML 1.0 strict
		">$4<\/a>"
	/xeg;

	# images (<img src="..." [alt=""] [align="left|right|center"]>)
	$input =~ s/
		&lt;
			(
				img
				\s+ src \s*=\s* "([^"]*?)"
				(?: \s+ alt \s*=\s* "([^"]*?)" )?
				(?: \s+ align \s*=\s* "([^"]*?)" )? #"
			)\s*
		&gt;
		(?![^<>]*?>) # make sure we're not inside an html tag
	/
		'<img src="' . escapeForHTMLAttribute(makeActualURL(unescapeForHTML($2))) . "\" alt=\"$3\"" . 
		(($4 eq 'left')?" class=\"leftfloating\"":(($4 eq 'right')?" class=\"rightfloating\"":"")) . # class to satisfy fake "align" attribute 
		" \/>"
	/xeg;

	# style tags
	# allow <b> or <strong>
	$input =~ s/&lt;(b|strong)&gt;($wellFormedXML)&lt;\/\1&gt;(?![^<>]*?>)/<strong>$2<\/strong>/g;
	# allow <i> or <em>
	$input =~ s/&lt;(i|em)&gt;($wellFormedXML)&lt;\/\1&gt;(?![^<>]*?>)/<em>$2<\/em>/g;
	# allow <u>
	$input =~ s/&lt;(u)&gt;($wellFormedXML)&lt;\/\1&gt;(?![^<>]*?>)/<em class="underlined">$2<\/em>/g;
	#allow <sup>
	$input =~ s/&lt;(sup)&gt;($wellFormedXML)&lt;\/\1&gt;(?![^<>]*?>)/<sup>$2<\/sup>/g;
	
	if ($parseforcharactermarkup)
	{
		# style weird markup
		# allow *bold*
		$input =~ s/\*(?=\S)($wellFormedXML)(?<=\S)\*(?![^<>]*?>)/<strong>$1<\/strong>/g;
		
		
		# allow /italic/
		# removed for convenience
		#$input =~ s/\/(?=\S)($wellFormedXML)(?<=\S)\/(?![^<>]*?>)/<em>$1<\/em>/g;
		
		# allow _underline_
		$input =~ s/_(?=\S)($wellFormedXML)(?<=\S)_(?![^<>]*?>)/<em class="underlined">$1<\/em>/g;
	}
	
	return $input;
}

#####################################################
# Function: generateForm
# Parameters: Filehandle to output form to, HTML ID of the form, the action of the form, and a reference to an array of form controls
# Return value: none
# 
# Purpose: Handles form generation. Outputs a nicely formatted form, using tables when necessary.
#		Each form control in the array should be an array reference with the following structure:
#
#		[
#			"element type",
#			"Visual Label",
#			"HTML ID and HTML name",
#			array reference of more data depending on the data type,
#			hash reference of parameters to apply to the form control (such as class, onclick, etc)
#			optional string which overrides the HTML ID without overriding the form control name
#		]
#
#		The following data types are supported:
#			url, text, hidden, textarea
#				Array reference should contain a single element: default value.
#			checkbox
#				Array reference should contain a single element: 0 or 1 (default checked value).
#			select
#				Array reference should contain two elements: the first being a reference to an array of options, 
#				the second being the index of the option which is selected by default.
#				Each option should be an array reference containing two values: the label of the option, and the value of the option.
#			fieldset
#				Array reference should contain more form controls to be placed inside the fieldset.
#
sub generateForm
{
	my $FH = shift;
	my $formid = shift;
	my $action = shift;
	my $elementarray = shift;
	my $attributehash = shift;

	my $attributes = "";
	foreach my $key (keys %$attributehash)
	{
		my $val = escapeForHTMLAttribute($attributehash->{$key});
		$attributes .= " $key=\"$val\"";
	}

	print $FH "<form id=\"$formid\" action=\"$config{'webscriptpath'}\" method=\"post\" accept-charset=\"ISO-8859-1\"$attributes>\n";
	generateFormTable($FH, $action, $elementarray, 1);
	print $FH "</form>\n";
}

# A hash determining which form elements belong inside tables
my %elementintable = (
	'select' => 1,
	'text' => 1,
	'textarea' => 0,
	'checkbox' => 1,
	'button' => 0,
	'fieldset' => 0,
	'url' => 1,
);
# and inside paragraphs
my %elementinparagraph = (
	'select' => 0,
	'text' => 0,
	'textarea' => 0,
	'checkbox' => 0,
	'button' => 1,
	'fieldset' => 0,
	'url' => 0,
);

#####################################################
# Function: generateFormTable
# Parameters: Filehandle to output form to, reference to an array of form controls
# Return value: none
# 
# Purpose: Handles generation of the contents of a form element.
#
sub generateFormTable
{
	my $FH = shift;
	my $action = shift;
	my $elementarray = shift;
	my $tabdepth = shift;
	
	my $hiddeninputs = 0;

	my $intable = 0;
	my $inparagraph = 0;
	
	foreach my $element (@$elementarray)
	{
		if (@$element[0] ne 'hidden')
		{
			if ($intable && !$elementintable{@$element[0]}) {
				print $FH "\t" x $tabdepth . "</table>\n";
				$intable = 0;
			}
			if ($inparagraph && !$elementinparagraph{@$element[0]}) {
				print $FH "\t" x $tabdepth . "</p>\n";
				$inparagraph = 0;
			}
			if (!$inparagraph && $elementinparagraph{@$element[0]}) {
				print $FH "\t" x $tabdepth . "<p>\n";
				$inparagraph = 1;
			}
			if (!$intable && $elementintable{@$element[0]}) {
				print $FH "\t" x $tabdepth . "<table>\n";
				$intable = 1;
			}
			generateSingleInput($FH, $tabdepth + $intable, @$element);
		}
		else {
			$hiddeninputs = 1;
		}
	}

	if ($intable)
	{
		print $FH "\t" x $tabdepth . "</table>\n";
	}
	if ($inparagraph)
	{
		print $FH "\t" x $tabdepth . "</p>\n";
	}
	
	if ($hiddeninputs || $action)
	{
		print $FH "\t" x $tabdepth . "<p>\n"; # all input elements are required to be in a paragraph or a table or something like that
	}
	
	# hidden elements
	foreach my $element (@$elementarray)
	{
		if (@$element[0] eq 'hidden')
		{
			my $inputdataref = @$element[3];
			my $value = escapeForHTMLAttribute(@$inputdataref[0]);
			my $name = escapeForHTMLAttribute(@$element[2]);
			my $id = escapeForHTMLAttribute(@$element[5]);
			$id = $name if (!$id);
			print $FH "\t" x $tabdepth . "<input type=\"hidden\" name=\"$name\" id=\"$id\" value=\"$value\" />\n";
		}
	}
	if ($action) {
		print $FH "\t" x $tabdepth . "<input type=\"hidden\" name=\"action\" value=\"$action\" class=\"button\" />\n";
		my $value = escapeForHTMLAttribute($actionlabels{$action});
		print $FH "\t" x $tabdepth . "<input type=\"submit\" value=\"$value\" class=\"button\" />\n";
	}
	if ($hiddeninputs || $action)
	{
		print $FH "\t" x $tabdepth . "</p>\n";
	}
}

#####################################################
# Function: generateSingleInput
# Parameters: Filehandle to output form to, current tab depth, single form element as described above generateForm (array, not array reference)
# Return value: none
# 
# Purpose: Handles generation of a single form element.
#
sub generateSingleInput
{
	my $FH = shift;
	my $tabdepth = shift;
	my $type = shift;
	my $label = escapeForHTML(shift);
	my $name = escapeForHTMLAttribute(shift);
	my $inputdataref = shift;
	my $attributehash = shift;
	my $id = escapeForHTMLAttribute(shift);
	
	$id = $name if (!$id);
	
	print $FH "\t" x $tabdepth . "<tr>\n" if ($elementintable{$type});
	print $FH "\t" x $tabdepth . "\t<td><label for=\"$id\">$label:</label></td>\n" if ($elementintable{$type} && ($type ne 'checkbox'));

	my $attributes = "";
	my $classappend = "";
	foreach my $key (keys %$attributehash)
	{
		my $val = escapeForHTMLAttribute($attributehash->{$key});
		if ($key eq "class")
		{
			$classappend = " " . $val;
		}
		else
		{
			$attributes .= " $key=\"$val\"";
		}
	}
	if($type eq 'select')
	{
		my $optionsref = shift @$inputdataref;
		my $defaultindex = shift @$inputdataref;
		print $FH "\t" x $tabdepth . "\t<td>\n";
		print $FH "\t" x $tabdepth . "\t\t<select name=\"$name\" id=\"$id\" class=\"selectbox$classappend\"$attributes>\n";
		for (my $i = 0; $i < scalar(@$optionsref); $i++)
		{
			my $option = @$optionsref[$i];
			my $text = escapeForHTML(@$option[0]);
			my $value = escapeForHTMLAttribute(@$option[1]);
			print $FH "\t" x $tabdepth . "\t\t\t<option value=\"$value\"";
			print $FH " selected=\"selected\"" if ($i == $defaultindex);
			print $FH ">$text</option>\n";
		}
		print $FH "\t" x $tabdepth . "\t\t</select>\n";
		print $FH "\t" x $tabdepth . "\t</td>\n";
	}
	elsif($type eq 'text')
	{
		my $value = escapeForHTMLAttribute(@$inputdataref[0]);
		print $FH "\t" x $tabdepth . "\t<td><input type=\"text\" name=\"$name\" id=\"$id\" value=\"$value\" class=\"textbox$classappend\"$attributes /></td>\n";
	}
	elsif($type eq 'textarea')
	{
		print $FH "\t" x $tabdepth . "<label for=\"$id\">$label:</label><br />\n";
		my $text = escapeForHTML(@$inputdataref[0]);
		print $FH "\t" x $tabdepth . "<textarea name=\"$name\" id=\"$id\" rows=\"8\" cols=\"60\" class=\"textbox$classappend\"$attributes>$text</textarea><br />\n";
	}
	elsif($type eq 'checkbox')
	{
		if($classappend)
		{
			$classappend = substr($classappend, 1);
			$classappend = " class=\"$classappend\"";
		}
		print $FH "\t" x $tabdepth . "\t<td></td>\n";
		print $FH "\t" x $tabdepth . "\t<td>\n";
		my $defaultval = 0;
		$defaultval = 1 if (@$inputdataref[0]);
		print $FH "\t" x $tabdepth . "\t\t<input type=\"hidden\" name=\"${id}_supplied_\" id=\"${id}_supplied_\"$classappend value=\"1\" />\n";
		print $FH "\t" x $tabdepth . "\t\t<input type=\"checkbox\" name=\"$name\" id=\"$id\"";
		print $FH " checked=\"checked\"" if (@$inputdataref[0]);
		print $FH "$attributes /> <label for=\"$id\">$label</label>\n";
		print $FH "\t" x $tabdepth . "\t</td>\n";
	}
	elsif($type eq 'button')
	{
		print $FH "\t" x $tabdepth . "<input type=\"button\" name=\"$name\" id=\"$id\" value=\"$label\" class=\"button$classappend\"$attributes />\n";
	}
	elsif($type eq 'fieldset')
	{
		if($classappend)
		{
			$classappend = substr($classappend, 1);
			$classappend = " class=\"$classappend\"";
		}
	
		print $FH "\t" x $tabdepth . "<fieldset id=\"$id\"$classappend$attributes>\n";
		print $FH "\t" x $tabdepth . "\t<legend><a href=\"\" onclick=\"return toggleFieldset(this);\">-</a> $label</legend>\n";
		print $FH "\t" x $tabdepth . "\t<div id=\"${id}_contents_\" style=\"display:block;\">\n";
		
		generateFormTable($FH, '', $inputdataref, $tabdepth + 1);
		
		print $FH "\t" x $tabdepth . "\t</div>\n";
		print $FH "\t" x $tabdepth . "</fieldset>\n";
	}
	elsif($type eq 'url')
	{
		my $value = escapeForHTMLAttribute(@$inputdataref[0]);
		print $FH "\t" x $tabdepth . "\t<td>url (<input type=\"text\" name=\"$name\" id=\"$id\" value=\"$value\" class=\"textbox$classappend\"$attributes />) <input type=\"button\" value=\"Select URL...\" id=\"${id}_chooser_\" onclick=\"selectURL(this);\" class=\"button\"/></td>\n";
	}
	print $FH "\t" x $tabdepth . "</tr>\n" if ($elementintable{$type});
}

1;
