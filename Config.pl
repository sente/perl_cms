#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

=pod
package Config;
require Exporter;
our @ISA	= qw(Exporter);
our @EXPORT = qw(%config %defaultDirInfo %modedata @ERROR_CODE);
use General;
=cut


our $VERSION = "0.9";

###########################
$ERROR_CODE[0] = "Success";
$ERROR_CODE[1] = "Cannot create node. The node name is already taken by a file or directory which is reserved or used internally by the CMS";
$ERROR_CODE[2] = "Cannot create node. The node already exists";
$ERROR_CODE[3] = "Cannot copy node. The node name is already taken by a file or directory which is reserved or used internally by the CMS";
#########
$ERROR_CODE[5] = "Cannot delete node. The node does not exist";
$ERROR_CODE[6] = "Cannot copy node. The destination node already exists";
$ERROR_CODE[7] = "Cannot copy node. The source node does not exist";
$ERROR_CODE[8] = "Cannot create node. The parent node does not exist";
$ERROR_CODE[9] = "Cannot copy node. The destination does not exist";
$ERROR_CODE[10] = "Invalid action";
$ERROR_CODE[11] = "One of the parameters does not have a valid value";
$ERROR_CODE[12] = "Cannot finalize node. Not all of its descendant leaves have content";
$ERROR_CODE[13] = "Cannot finalize node without recursion. Either it has not been finalized before, or it has no content";
$ERROR_CODE[14] = "Cannot finalize node. Its parent has not yet been finalized";
$ERROR_CODE[15] = "Cannot rename one of more files. The filename(s) specified are invalid";
$ERROR_CODE[16] = "Cannot perform requested actions. The directory appears to have been modified manually since this form was sent";
$ERROR_CODE[17] = "The request is invalid";
$ERROR_CODE[18] = "Cannot upload one or more files. The file(s) uploaded are empty, or the transfer failed";
$ERROR_CODE[19] = "Cannot upload one or more files. The file(s) could not be opened for writing";
$ERROR_CODE[20] = "Cannot handle the request. The specified node does not exist";
$ERROR_CODE[21] = "Cannot move node";
$ERROR_CODE[22] = "Cannot preview node. The specified node has no content";
$ERROR_CODE[23] = "Cannot save node. The node's template is not specified";
$ERROR_CODE[24] = "Cannot delete the root";
$ERROR_CODE[25] = "Cannot undelete node. The node is not marked for deletion";
$ERROR_CODE[26] = "Cannot move the root";
$ERROR_CODE[27] = "Cannot save node. Not all required parameters were supplied";
$ERROR_CODE[28] = "Cannot save node. The template file is not valid. At least one element does not have an \"id\" attribute";
$ERROR_CODE[29] = "Cannot output content. The content file is not valid. Data nodes must contain text or CDATA sections";
$ERROR_CODE[30] = "Cannot output content. The content file is missing a node corresponding to a node in the template file";
$ERROR_CODE[31] = "Cannot output content. The template file is not valid. At least one element does not have an \"id\" attribute";
$ERROR_CODE[32] = "Cannot output content. A node in the content file is missing a required attribute";
$ERROR_CODE[33] = "Cannot output content. A node specified by the content file could not be found in the template file";
$ERROR_CODE[34] = "Cannot output content. A node which is linked to by another node in the template file cannot be found";



$ERROR_CODE[100] = "Invalid request";
############################	

%config = (
	'webscriptpath'		=> '/cms/cgi-bin/index.cgi',
	'cmscontentroot'	=> '/var/apache/sites/cms/htdocs/cmsroot/',
	'webcmscontentroot'	=> '/cms/cmsroot/',
	'finalizedroot'		=> '/var/apache/sites/cms/htdocs/finalizedroot/',
	'webfinalizedroot'	=> '/cms/finalizedroot/',
	'datadirpath'		=> '/var/apache/sites/cms/data/',
	'contenttemplatespath'=> '/var/apache/sites/cms/htdocs/templates/content/',
	'pagetemplatespath'	=> '/var/apache/sites/cms/htdocs/templates/pages/',
	'templatefile'		=> '/var/apache/sites/cms/htdocs/templates/cms.template',
	'includesdir'		=> '/var/apache/sites/cms/htdocs/finalizedroot/includes/',
	
	'urlaliases'		=>	[ # use array, not hash
						'/cms/' 		=> '/var/apache/sites/cms/htdocs/', # map url's to directories
						'/cms/cgi-bin/' 	=> '/var/apache/sites/cms/cgi-bin/',
					],	
	
	'commentedsidebar'	=> 'commentedsidebar.txt',

	'content_type'		=> 'content-type: text/html',

	'includefiles'		=> '/cms/finalizedroot/includes/',
	'sidebarincludefile'	=> 'sidebar.txt',
	
	'generalsitefilesdir'	=> 'sitefiles',
	
	'indexfile'			=> 'index.html',
	'usercontrolfile'		=> 'protection.dat',
	'directoryinfofile'	=> 'directoryinfo.dat',
	'childreninfofile'		=> 'children.dat',
	'contentfile'		=> 'content.xml',
	'defaultcontentfile'	=> 'defaultcontent.xml',
	'temporaryfile'		=> 'temp.txt',
	
	'systemslash'		=> '/',
	'systemslashreg'	=> '\\/',
	'delimiter'			=> '/',
	'escapeddelimiter'	=> '\\/',
	
	'virtualfilepattern'	=> qr/(<!--\s*?#include\s+?virtual="(.*?)"\s*?-->)/,
	'tokenpattern'		=> qr/<!--\s*?#(\w*)\s*?-->/,
	'templatetagpattern'	=> qr/<!\s*?(\/?)(\w*)((\s+\w+=("?).*?\5?)*)\s*>/,

	'defaulttitle'		=> "Health Analytics",
	
	'lockfiles'			=> 1,
);


%defaultDirInfo = (
	'hidden'						=> "0",
	'has_content'					=> "0",
	'had_content_when_finalized'		=> "0",
	'descendant_leaves_with_content'	=> "0",
	'descendant_leaves'				=> "1",
	'marked_for_deletion'				=> "0",
	'has_been_finalized'				=> "0",
	'content_template'				=> "",
	'page_template'					=> "",
	'title'							=> $config{'defaulttitle'},
);	

our %requiredparams = (
	'main'			=> [],
	'preview'			=> ['node'],
	'edit'				=> ['node'],
	'finalize'			=> ['node','recurse'],
	'create'			=> ['parentnode', 'nodename'],
	'delete'			=> ['node'],
	'undelete'			=> ['node'],
	'copy'			=> ['node', 'parentnode', 'nodename'],
	'change_attribute'	=> ['node', 'displayname', 'title', 'hidden'],
	'save'			=> ['node'],
	'settemplate'		=> ['node', 'page_template', 'content_template'],
	'upload'			=> ['node'],
	'move'			=> ['node', 'direction'],
);

our %optionalparams = (
	'create'			=> ['displayname'],
	'copy'			=> ['displayname'],
);


our %actionlabels = (
	'main'			=> 'Main',
	'preview'			=> 'Preview',
	'edit'				=> 'Edit',
	'finalize'			=> 'Finalize',
	'create'			=> 'Create',
	'delete'			=> 'Delete',
	'undelete'			=> 'Undelete',
	'copy'			=> 'Copy',
	'change_attribute'	=> 'Change Attributes',
	'save'			=> 'Save',
	'settemplate'		=> 'Set Template',
	'upload'			=> 'Upload',
	'move'			=> 'Move',
);


our %paramtypes = (
	'node'			=> 'treepath',
	'parentnode'		=> 'treepath',
	'nodename'		=> 'alphanumeric',
	'displayname'		=> 'string',
	'recurse'			=> 'boolean',
	'content_template'	=> 'filename',
	'page_template'		=> 'filename',
	'hidden'			=> 'boolean',
	'direction'			=> 'direction',
	'title'				=> 'string',
);

our %paramlabels = (
	'node' => 'Node',
	'parentnode' => 'Child of',
	'nodename' => 'Node ID',
	'displayname' => 'Displayed Name',
	'recurse' => 'Recursively',
	'content_template' => 'Content Type',
	'page_template'	=> 'Page Type',  
	'hidden' => 'Hidden',
	'direction'	=> 'Direction',
	'title'		=> 'Page Title',
);

our %dataTypeRegexes = (
	'treepath'		=> qr/^$config{'delimiter'}(\w+$config{'delimiter'})*$/,
	'alphanumeric'	=> qr/^\w+$/,
	'string'		=> qr/^.*$/,
	'boolean'		=> qr/0|1/,
	'filename'		=> qr/^[ \w\.]+$/, # could be more precise
	'direction'		=> qr/^(-1|1)$/,
);

our @fileTypes = (
	'image',
	'css',
	'script',
	'other',
);

our %fileTypeFolders = (
	'image'	=> 'images',
	'css'		=> 'css',
	'script'	=> 'scripts',
	'other'	=> 'other',
);

our %filetypemodes = (
	'image'	=> 0, # 0 = binary, 1 = ascii, 2 = auto
	'css'		=> 1,
	'script'	=> 1,
	'other'	=> 2,
);

our %fileTypeCaptions = (
	'image'	=> 'Images',
	'css'		=> 'Style Sheets',
	'script'	=> 'Client-Side Scripts',
	'other'	=> 'Other',
);

our %fileTypeSingularCaptions = (
	'image'	=> 'Image',
	'css'		=> 'Style Sheet',
	'script'	=> 'Client-Side Script',
	'other'	=> 'File',
);
1;
