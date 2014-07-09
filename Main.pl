#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

##!C:\perl\bin\perl
use strict;
use warnings;

# IF YOU DON'T KNOW WHERE TO START, look at the main() function, at the end of this file; it is the first function called.


#print "\n\n";
#while (<STDIN>)
#{
#	print;
#}



use Data::Dumper;
use File::Copy;
use HTML::Entities;
use XML::DOM;
use CGI;


$CGI::DISABLE_UPLOADS = 0;
$CGI::POST_MAX = 2 ** 26; #64 megs is the most one can upload


#require "Config.pl";		# Contains variable declarations which allow easy configuration of the CMS's behavior

require "General.pl";		# Contains general functions for little random things which are done a lot
require "Node.pl";		# Contains functions which make node manipulation simpler

require "Output.pl";		# Contains functions which create output whose content is specified by their parameters
					# (list and form generators, along with page generation)

require "Edit.pl";		# Contains functions which relate to editing a page
require "Content.pl";		# Contains the three functions which 
					# (a) generate a form to edit a page with, 
					# (b) recieve and save input from that form, and 
					# (c) read from the saved input to produce a final page

require "Finalize.pl";		# Contains functions which relate to the finalization of nodes and the finalized sidebar
require "Preview.pl";		# Contains functions which relate to the previewing of a node and the preview sidebar

require "Uploads.pl";		# Contains functions which relate to the file manager / upload page

require "Actions.pl";		# Contains a top-level function for each action carried out by this program
require "MainPage.pl";	# Contains functions which relate to the output of the main page


#####################################################
# index.cgi
#
#  This is the main script that is executed through the CGI interface.  This script contains
#  the main high level functions which in turn call lower level functions.  This script is meant to
#  remain abstract and detatched from the inner workings of the CMS's operation.
#
#####################################################




#variable that is used to access parameters and methods given to use by the CGI.pm module.
our $q = new CGI;

###################################
#	various hashes used in config.pl but must be first defined here 
#	to avoid foolish warnings by perl.  
our %config;
our @ERROR_CODE = @ERROR_CODE;
our $STATUS_FLAG = 0;
our %requestinfo;
our %requiredparams;
our %optionalparams;
our %paramtypes;
our %dataTypeRegexes;
our %outputTokenHash;
#our %defaultDirInfo;
###################################

# these variables are used to control what sort of response will be output at the end of the program
%outputTokenHash = (
	'CONTENT' => \&mainContentGenerator,
);
our $outputtemplate = $config{'templatefile'};


#####################################################
# Function: readInput
# Parameters: none.	it uses the global variables.
# Return value: 1
# 
# Purpose: reads the input from the user (CGI input), allowing for poorly manipulated URLS
#  helping us to find the intention of the user, even though there may be mistakes in the syntax
#  of what we are given.
#
sub readInput
{
	#not used
	$requestinfo{"sessionID"}	= $ENV{"REMOTE_USER"}		|| "";
	#determine the action to be carried out
	$requestinfo{"action"}	= $q->param("action")		|| "main";

	# for each parameter that this action requires (including optional ones)..
	foreach my $param (@{$requiredparams{$requestinfo{'action'}}}, @{$optionalparams{$requestinfo{'action'}}})
	{
		my $paramval = $q->param($param);
		
		#check if the parameter is supplied
		if (defined $q->param($param) || ($paramtypes{$param} eq 'boolean' && defined $q->param("${param}_supplied_")))
		{
			if ($paramtypes{$param} eq 'treepath')
			{
				# forgive poorly typed tree paths
				$paramval = cleanupPath($paramval);
			}
			elsif ($paramtypes{$param} eq 'boolean' && defined $q->param("${param}_supplied_"))
			{
				$paramval = ($paramval?1:0);
			}
			# save the parameter for later
			$requestinfo{$param} = $paramval;
		}
		# do nothing for now if parameter is not supplied
	}
	return 1;
}

#####################################################
# Function: confirmRequest
# Parameters: none.	it mainly uses $requestinfo{'action'} which was originally $q->param("action")
# Return value: 1 on success, 0 on failure
# 
# Purpose: check the validity of the users request, checking that all parameters are valid and that
#  they are allowed to do what they are trying to do.  This checking is done through the hashes in 
#  config.pl
#
sub confirmRequest
{
	# get the action
	my $action = $requestinfo{'action'};
	if(! exists $requiredparams{$action})	# make sure the action is recognizable
	{
		$STATUS_FLAG = 10;
		return 0;
	}
	
	#for every parameter (optional and required) associated with the given action...
	
	foreach my $param (@{$requiredparams{$action}}, @{$optionalparams{$action}}) 
	{
		#for every parameter in our list of required params
		#if they supplied that param, make sure it has legal values
		#this also checks the list of optional params, and makes sures those values are legal as well
			
		my $datatype = $paramtypes{$param};
		my $value = $requestinfo{$param};

		if(exists $requestinfo{$param} && $value !~ /$dataTypeRegexes{$datatype}/ )
		{
			#print "\n\n||$param||$requestinfo{$param}|||\n";
			# throw error if paramater format was invalid
			$STATUS_FLAG = 11;
			return 0;
		}	
	}

	return 1;
}

#####################################################
# Function: handleRequest
# Parameters: none.	it uses the global variables.
# Return value: 1
# 
# Purpose: do what the user wants done.  If the user has left out parameters that are needed
#  to perform the necessary action, give them an opportunity to supply the necessary parameters.
#  Only executes if request is valid, as determined by confirmRequest().
#
sub handleRequest
{
	# get the action
	my $action = $requestinfo{'action'};
	my %dirinfo;

	# send form for parameters if it's explicitly asked for:
	if ($q->param('forceform'))
	{
		$outputTokenHash{'CONTENT'} = \&paramRequestGenerator;
		return 1;
	}
	
	# if not all parameters are supplied, send form to get them:
	
	# for every required paramater of this action...
	foreach my $param (@{$requiredparams{$requestinfo{'action'}}})
	{
		# ...if it wasn't supplied...
		if(! (exists ($requestinfo{$param}) || (($paramtypes{$param} eq 'boolean') && $q->param("${param}_supplied_"))))
		{
			# ...ask for it
			$outputTokenHash{'CONTENT'} = \&paramRequestGenerator;
			return 1; # we won't be carrying out any action
		}
	}
	#if "displayname" parameter is supplied but not valid, use value of "nodename" parameter:
	if(exists $requestinfo{'displayname'} && $requestinfo{'displayname'} !~ /\w/)
	{
		$requestinfo{'displayname'} = $requestinfo{'nodename'};
	}
	
	
	# we now know that all parameters have been supplied; we will now carry out the requested action:
	
	# all of these functions are in Actions.pl
	if($action eq 'preview')
	{
		actionPreview($requestinfo{'node'});
	}
	
	if ($action eq 'settemplate')
	{
		my $node				= $requestinfo{'node'};
		my $page_template		= $requestinfo{'page_template'};
		my $content_template	= $requestinfo{'content_template'};
		actionSetTemplate($node, $page_template, $content_template);
	}
	if($action eq 'edit' || $action eq 'settemplate')
	{
		actionEdit($requestinfo{'node'});
	}
	if($action eq 'finalize')
	{
		my $node		= $requestinfo{'node'};
		my $recurse	= $requestinfo{'recurse'};
		actionFinalize($node, $recurse);
	}
	if($action eq 'change_attribute')
	{
		my $node				= $requestinfo{'node'};
		my $displayname		= $requestinfo{'displayname'};
		my $hidden			= $requestinfo{'hidden'};
		my $title				= $requestinfo{'title'};
		actionChangeAttribute($node, $displayname, $hidden, $title);
	}
	if($action eq 'save')
	{
		actionSave($requestinfo{'node'});
	}
	if($action eq 'copy')
	{
		my $fromnode		= $requestinfo{'node'};
		my $parentnode	= $requestinfo{'parentnode'};
		my $nodename		= $requestinfo{'nodename'};
		my $displayname	= $requestinfo{'displayname'};
		actionCopy($fromnode, $parentnode, $nodename, $displayname);
	}
	if($action eq 'create')
	{
		my $parentpath		= $requestinfo{'parentnode'}; 
		my $nodename		= $requestinfo{'nodename'}; 
		my $displayname	= $requestinfo{'displayname'};
		actionCreate($parentpath, $nodename, $displayname);
	}
	if($action eq 'delete')
	{
		my $node = $requestinfo{'node'};
		actionDelete($node);
	}
	if($action eq 'undelete') # or, "unmark for deletion"
	{
		actionUndelete($requestinfo{'node'});
	}
	if($action eq 'upload')
	{
		actionUpload($requestinfo{'node'});
	}
	if ($action eq 'move')
	{
		my $node = $requestinfo{'node'};
		my $direction = $requestinfo{'direction'};
		actionMove($node, $direction);
	}
	if ($action eq 'urlchooser')
	{
		actionURLChooser();
	}
	return 1;
}

#####################################################
# Function: sendResponse
# Parameters: none.
# Return value: none.
# 
# Purpose: main function that sends a page back to the user as the response of their action
#  Every page sent to the user originally came from this function call.
#
sub sendResponse
{
	# print HTTP header
	print "content-type: text/html\n\n";
	
	# generate the page; outputTokenHash contains function references which were set earlier 
	# so that the page output will correspond to the action that was carried out
	generatePage(\*STDOUT, $outputtemplate, \%outputTokenHash);
}

#####################################################
# Function: main
# Parameters: none.
# Return value: none.
# 
# Purpose: This is the master function that calls all other functions.
#  readInput()  confirmRequest()  handleRequest()  sendResponse()
#  (all in this same file).
#
sub main
{
	# enable w (writing) bit for group so that we can get to the files too
	umask(002);

	# record errors for convenience
	open(STDERR, ">errors.txt");
	#writeLock(STDERR); # never mind this...
	
	# Die if there was a CGI error
	$q->cgi_error and $STATUS_FLAG = 17;
	
	# Haven't died yet?
	if($STATUS_FLAG == 0)
	{
		# Get data relating to the specified action
		readInput();
		
		# Make sure all data recieved is valid
		confirmRequest();
	}
	
	# Request is valid?
	if ($STATUS_FLAG == 0)
	{
		# Do what they want!
		handleRequest();
	}
	
	# Send the appropriate page back to them
	sendResponse();
}

main(); # here we go!

1;
