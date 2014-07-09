#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

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


sub readLock {
	if ($dbconfig{'lockfiles'}) {
		flock(shift, 1); # LOCK_SHared
	}
}
sub writeLock {
	if ($dbconfig{'lockfiles'}) {
		flock(shift, 2); # LOCK_EXplicit
	}
}
sub unlock {
	if ($dbconfig{'lockfiles'}) {
		flock(shift, 8); # LOCK_UNlock
	}
}

1;
