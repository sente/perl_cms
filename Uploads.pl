#####################################################
# Stuart Powers - 2006-03-21
# Stuart.Powers@gmail.com
# You're free to use this code but probably wise enough not too :)

#####################################################
# Uploads.pl
#
#  This file contains functions related to the "File Manager" with which one can
#  upload files into a node.
#
#####################################################

#####################################################
# Function: getUploads
# Parameters: none
# Return value: 0 if failure
# 
# Purpose: Gets uploads from the CGI parameters and places them in the 
#		appropriate place of the node specified by the request.
#
sub getUploads
{
	foreach my $typeofupload (@fileTypes)
	{
		my $numofuploads = $q->param($typeofupload . "_newcount");
		
		my $directory = $requestinfo{'node'} . $fileTypeFolders{$typeofupload} . $config{'delimiter'};

		for(my $i=0; $i<$numofuploads; $i++)
		{
			my $file = $q->param("${typeofupload}_$i");
			my $FH = $q->upload("${typeofupload}_$i"); #$file
		
			#print "\n\n" . Dumper($FH) . "<--";
		
			#get the actual file name...
			
			my ($filename) = $file =~ /.*[\\\/](.*)/;
			if($filename eq "")
			{
				$filename = "untitled";
			}
			
			# create directory if necessary
			if (!(-d makeSystemPath($directory)))
			{
				mkdir makeSystemPath($directory);
			}
			
			local *FINALFILE;
			
			my $fileopened = 0;
			my $filepath;

			#my $trynum = 0;
			#do {
			#	my $newfilename = $filename;
			#	if($trynum) {
			#		$newfilename =~ s/(\.\w+)?$/'_' . padWith0s(2, $trynum) . $1/e;
			#	}
			#	$filepath = makeSystemPath($directory . $newfilename);
			#	
			#	$trynum++;
			#}while ($trynum < 100 && (-e $filepath || !($fileopened = open(FINALFILE, ">$filepath"))));
			## IF EVER USED, MUST LOCK 'FINALFILE'
			

			$filepath = makeSystemPath($directory . $filename);
			
			if(!open(FINALFILE, ">$filepath"))
			{
				$STATUS_FLAG = 19;
				return 0;
			}
			writeLock(FINALFILE);
			
			my $usebinary = ($filetypemodes{$typeofupload} == 0);
			if ($filetypemodes{$typeofupload} == 2)
			{
				$usebinary = -B $FH; # makes a heuristic guess whether it's binary or not
			}
			if($usebinary)  #binary mode..
			{
				binmode $FH;
				binmode FINALFILE;
			}
			
			my $BUFFER_SIZE = 16384;
			my $buffer = "";

			my $hasabyte = 0;
			while(read($FH, $buffer, $BUFFER_SIZE))
			{
				$hasabyte=1;
				print FINALFILE $buffer;
			}
			unlock(FINALFILE);
			close(FINALFILE);
			
			if (!$hasabyte && !$file)
			{
				unlink($filepath);
			}
		}
	}
}

#####################################################
# Function: renameAndDelete
# Parameters: none
# Return value: 0 if failure
# 
# Purpose: Renames and deletes files as specified by CGI parameters sent from 
#		the node file manager.
#
sub renameAndDelete
{
	foreach my $filetype (@fileTypes)
	{
		my $directory = makeSystemPath($requestinfo{'node'} . $fileTypeFolders{$filetype} . $config{'delimiter'});
		my @files = sort(&getAllFilesInFolder($directory));
		my $i=0;
		foreach my $file (@files)
		{
			if($q->param("filename_${filetype}_$i"))
			{
				if ($file eq $q->param("filename_${filetype}_$i"))
				{
					if($q->param("delete_${filetype}_$i"))
					{
						unlink($directory . $file);
					}
					if($q->param("rename_${filetype}_$i") ne $file)
					{
						if($q->param("rename_${filetype}_$i") =~ /$dataTypeRegexes{'filename'}/)	#make sure its a legal filename
						{
							rename($directory . $file, $directory .  $q->param("rename_${filetype}_$i")); # or die?
						}
						else
						{
							$STATUS_FLAG = 15;
						}
					}
				}
				else
				{
					$STATUS_FLAG = 16;
					return 0;
				}
			}
			$i++;
		}
	}
}

#####################################################
# Function: uploadPageGenerator
# Parameters: file handle to write the page to
# Return value: none
# 
# Purpose: Generates the page with which one can upload, rename, and delete 
#		files contained in a node.
#
sub uploadPageGenerator
{
	my $FH = shift;
	
	print $FH "<div class=\"largeformcontainer\">\n";
	
	outputStatus();
	
	print $FH "<form action=\"\" method=\"post\" enctype=\"multipart/form-data\">\n";
	print $FH "<input type=\"hidden\" name=\"node\" value=\"" . escapeForHTMLAttribute($requestinfo{'node'}) . "\" />\n";
	print $FH "<input type=\"hidden\" name=\"action\" value=\"upload\" />\n";
	foreach my $filetype (@fileTypes)
	{
		my $dirpath = makeSystemPath($requestinfo{'node'} . $fileTypeFolders{$filetype});
		my @files = sort(&getAllFilesInFolder($dirpath));
		my $numfiles = scalar(@files);
		
		print $FH "<fieldset><legend>" . escapeForHTML($fileTypeCaptions{$filetype}) . "</legend>\n";
		print $FH "<table id=\"" . escapeForHTMLAttribute("${filetype}_table") . "\" class=\"filelisttable\"";
			#mozilla cannot handle the hiding feature.
		print $FH " style=\"display:none;\"" unless ($numfiles || $ENV{'HTTP_USER_AGENT'} =~ /Gecko/);
		print $FH ">\n";
		
		print $FH "<colgroup>\n";
		print $FH "<col class=\"filename\" />\n";
		print $FH "<col class=\"filesize\" />\n";
		print $FH "<col class=\"rename\" />\n";
		print $FH "<col class=\"delete\" />\n";
		print $FH "</colgroup>\n";
		
		print $FH "<thead>\n";
		print $FH "\t<tr>\n";

		print $FH "\t\t<th>\n";
		print $FH "\t\t\tFilename\n";
		print $FH "\t\t</th>\n";

		print $FH "\t\t<th>\n";
		print $FH "\t\t\tSize\n";
		print $FH "\t\t</th>\n";

		print $FH "\t\t<th>\n";
		print $FH "\t\t\tRename\n";
		print $FH "\t\t</th>\n";

		print $FH "\t\t<th>\n";
		print $FH "\t\t\tDelete\n";
		print $FH "\t\t</th>\n";

		print $FH "\t</tr>\n";
		print $FH "</thead>\n";
		
		print $FH "<tbody>\n";
		
		my $i = 0;
		foreach my $file (@files)
		{
			
			print $FH "\t<tr id=\"" . escapeForHTMLAttribute("file_${filetype}_$i") . "\">\n";
			
			print $FH "\t\t<td>\n";
			print $FH "\t\t\t<a href=\"" . escapeForHTMLAttribute(makePreviewURL($requestinfo{'node'} . $fileTypeFolders{$filetype} . $config{'delimiter'} . $file)) . "\" id=\"" . escapeForHTMLAttribute("filename_${filetype}_$i") . "\" target=\"_blank\" title=\"View in a new window\">";
			print $FH "\t\t\t$file";
			print $FH "\t\t\t</a>\n";
			print $FH "\t\t</td>\n";
			
			print $FH "\t\t<td>\n";
			my $filesize = -s $dirpath . $config{'systemslash'} . $file;

			if($filesize > 2**20)
			{
				$filesizetext = sprintf("%.1f MB", $filesize/(2**20));
			}
			elsif($filesize > 2**10)
			{
				$filesizetext = sprintf("%.1f KB", $filesize/(2**10));
			}
			else
			{
				$filesizetext = "$filesize B";
			}
			print $FH "\t\t\t" . escapeForHTML($filesizetext) . "\n";
			print $FH "\t\t</td>\n";

			print $FH "\t\t<td>\n";
			print $FH "\t\t\t<input type=\"button\" value=\"Rename\" class=\"button\" onclick=\"" . escapeForHTMLAttribute("renameFile('$filetype', $i);") . "\" /><input type=\"hidden\" name=\"" . escapeForHTMLAttribute("rename_${filetype}_$i") . "\" id=\"" . escapeForHTMLAttribute("rename_${filetype}_$i") . "\" value=\"" . escapeForHTMLAttribute($file) . "\" />\n";
			print $FH "\t\t</td>\n";

			print $FH "\t\t<td>\n";
			print $FH "\t\t\t<input type=\"button\" value=\"Delete\" class=\"button\" onclick=\"" . escapeForHTMLAttribute("deleteFile('$filetype', $i);") . "\" /><input type=\"hidden\" name=\"" . escapeForHTMLAttribute("delete_${filetype}_$i") . "\" id=\"" . escapeForHTMLAttribute("delete_${filetype}_$i") . "\" value=\"0\" />\n";
			print $FH "\t\t</td>\n";

			print $FH "\t</tr>\n";
			
			$i++;
		}
		print $FH "</tbody>\n";
		print $FH "</table>\n";
		
		$i=0;
		foreach my $file (@files)
		{
			print $FH "<input type=\"hidden\" name=\"" . escapeForHTMLAttribute("filename_${filetype}_$i") . "\" id=\"" . escapeForHTMLAttribute("filename_${filetype}_$i") . "\" value=\"" . escapeForHTMLAttribute($file) . "\" />\n";
			$i++;
		}
		
		print $FH "<input type=\"hidden\" class=\"button\" name=\"" . escapeForHTMLAttribute("${filetype}_count") . "\" id=\"" . escapeForHTMLAttribute("${filetype}_count") . "\" value=\"" . escapeForHTMLAttribute($numfiles) . "\" onclick=\"" . escapeForHTMLAttribute("addFile('$filetype')") . "\" />\n";
		print $FH "<input type=\"hidden\" class=\"button\" name=\"" . escapeForHTMLAttribute("${filetype}_newcount") . "\" id=\"" . escapeForHTMLAttribute("${filetype}_newcount") . "\" value=\"0\" onclick=\"" . escapeForHTMLAttribute("addFile('$filetype')") . "\" />\n";
		print $FH "<input type=\"button\" class=\"button\" value=\"" . escapeForHTMLAttribute("New $fileTypeSingularCaptions{$filetype}") . "\" onclick=\"" . escapeForHTMLAttribute("addFile('$filetype');") . "\" />\n";
		print $FH "</fieldset>\n";
	}
	print $FH "<p>(Changes will not take effect unless the \"Apply Changes\" button is clicked.)<br />\n";
	print $FH "<input type=\"submit\" value=\"Apply Changes\" class=\"button\" /></p>\n";
	print $FH "</form>\n";
	print $FH "</div>\n";
}

1;
