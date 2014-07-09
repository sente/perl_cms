function newRepetition(newbutton)
{
	var id = newbutton.id.substr(0, newbutton.id.length - ("_new_").length);
	
	var fieldsetdiv = myGetElementById(id + "_contents_");

	var newfieldset = myGetElementById(id + "_prototype_").cloneNode(true);
	newfieldset.style.display = 'block';

	var countelement = myGetElementById(id + "_count_");
	var repetitionnum = parseInt(countelement.value);

	// change IDs within newfieldset
	fixRepetitionIDs(newfieldset, repetitionnum, id.length + 1);
	setId(newfieldset, id + "_" + repetitionnum + "_fieldset_");
	var newdiv = newfieldset.getElementsByTagName('div')[0];	
	setId(newdiv, id + "_" + repetitionnum + "_fieldset__contents_");
	var newlegend = newfieldset.getElementsByTagName('legend')[0];
	newlegend.childNodes[newlegend.childNodes.length-1].data += " #" + (repetitionnum+1);
	
	fieldsetdiv.insertBefore(newfieldset, newbutton.parentNode);
	
	// focus first element in newfieldset
	var firstformelement = findfirstformelement(newfieldset);
	if (firstformelement) {
		firstformelement.focus();
	}
	window.scrollTo(0, getElementY(newfieldset));
	
	if (repetitionnum == 0)
		myGetElementById(id + "_" + repetitionnum + "_moveup_").disabled = true;
	else {
		myGetElementById(id + "_" + (repetitionnum-1) + "_movedown_").disabled = false;
		myGetElementById(id + "_" + repetitionnum + "_moveup_").disabled = false;
	}

	if (repetitionnum == countelement.value)
		myGetElementById(id + "_" + repetitionnum + "_movedown_").disabled = true;
	else
		myGetElementById(id + "_" + repetitionnum + "_movedown_").disabled = false;

	// Fix IE form-element-created-by-DOM bugs
	// I HATE IE
	if (navigator.userAgent.indexOf('MSIE') != -1)
	{
		var olddropdowns = myGetElementById(id + "_prototype_").getElementsByTagName('select');
		var newdropdowns = newfieldset.getElementsByTagName('select');
		for (var a=0; a < olddropdowns.length; a++)
		{
			var oldoptions = olddropdowns[a].getElementsByTagName('option');
			var newoptions = newdropdowns[a].getElementsByTagName('option');
			for (var b=0; b < oldoptions.length; b++)
			{
				newoptions[b].selected = oldoptions[b].selected;
			}
		}
	}

	countelement.value = repetitionnum + 1;
}
function removeRepetition(removebutton)
{
	var id = removebutton.id.substr(0, removebutton.id.length - ("remove_").length);
	
	for (var underscorepos=id.length-1; underscorepos--; underscorepos >= 0)
	{
		if (id.substr(underscorepos,1) == "_") {
			break;
		}
	}
	
	var number = parseInt(id.substr(underscorepos+1));
	var baseid = id.substr(0,underscorepos);
	
	// remove fieldset
	var fieldset = myGetElementById(id + "fieldset_");
	fieldset.parentNode.removeChild(fieldset);
	
	// fix IDs of later fieldsets
	var countelement = myGetElementById(baseid + "_count_");

	for (var a=number+1; a < countelement.value; a++)
	{
		var thisfieldset = myGetElementById(baseid + "_" + a + "_fieldset_");
		fixRepetitionIDs(thisfieldset, a-1, baseid.length+1);
		
		var thislegendtext = thisfieldset.getElementsByTagName('legend')[0].childNodes[thisfieldset.getElementsByTagName('legend')[0].childNodes.length-1];
		thislegendtext.data = thislegendtext.data.substr(0, thislegendtext.data.length - (a+1).toString().length) + a;
	}
	
	// change count
	countelement.value--;

	if (countelement.value > 0)
	{
		if (number == 0)
		{
			myGetElementById(baseid + "_0_moveup_").disabled = true;
		}
		if (number == countelement.value)
		{
			myGetElementById(baseid + "_" + (countelement.value-1) + "_movedown_").disabled = true;
		}
	}
}
function moveRepetition(movebutton, direction)
{
	var id;
	if (direction == 1) {
		id = movebutton.id.substr(0, movebutton.id.length - ("movedown_").length);
	}
	else { // direction == -1
		id = movebutton.id.substr(0, movebutton.id.length - ("moveup_").length);
	}
	for (var underscorepos=id.length-1; underscorepos--; underscorepos >= 0)
	{
		if (id.substr(underscorepos,1) == "_") {
			break;
		}
	}
	var number = parseInt(id.substr(underscorepos+1));
	var baseid = id.substr(0,underscorepos);
	
	var countelement = myGetElementById(baseid + "_count_");
	
	var firstfieldset, secondfieldset;
	var firstmoveup, firstmovedown, secondmoveup, secondmovedown;
	var firstnumber, secondnumber;
	if (direction == 1)
	{
		if (number >= countelement.value -1) return;
		firstfieldset = 		myGetElementById(id + "fieldset_");
		secondfieldset = 	myGetElementById(baseid + "_" + (number+1) + "_fieldset_");
		firstmoveup = 		myGetElementById(id + "moveup_");
		firstmovedown = 	myGetElementById(id + "movedown_");
		secondmoveup = 	myGetElementById(baseid + "_" + (number+1) + "_moveup_");
		secondmovedown = 	myGetElementById(baseid + "_" + (number+1) + "_movedown_");
		firstnumber = number;
		secondnumber = number+1;
	}
	else // direction == -1
	{
		if (number <= 0) return;
		firstfieldset = 		myGetElementById(baseid + "_" + (number-1) + "_fieldset_");
		secondfieldset = 	myGetElementById(id + "fieldset_");
		firstmoveup = 		myGetElementById(baseid + "_" + (number-1) + "_moveup_");
		firstmovedown = 	myGetElementById(baseid + "_" + (number-1) + "_movedown_");
		secondmoveup = 	myGetElementById(id + "moveup_");
		secondmovedown = 	myGetElementById(id + "movedown_");
		firstnumber = number-1;
		secondnumber = number;
	}
	
	if (firstnumber == 0)
	{
		firstmoveup.disabled = false;
		secondmoveup.disabled = true;
	}
	if (secondnumber == countelement.value-1)
	{
		firstmovedown.disabled = true;
		secondmovedown.disabled = false;
	}
	
	fixRepetitionIDs(firstfieldset, "TEMPORARY", baseid.length+1);
	fixRepetitionIDs(secondfieldset, firstnumber, baseid.length+1);
	fixRepetitionIDs(firstfieldset, secondnumber, baseid.length+1);
	
	var legendtext = firstfieldset.getElementsByTagName('legend')[0].childNodes[firstfieldset.getElementsByTagName('legend')[0].childNodes.length-1];
	legendtext.data = legendtext.data.substr(0, legendtext.data.length - (firstnumber+1).toString().length) + (secondnumber+1);
	
	legendtext = secondfieldset.getElementsByTagName('legend')[0].childNodes[secondfieldset.getElementsByTagName('legend')[0].childNodes.length-1];
	legendtext.data = legendtext.data.substr(0, legendtext.data.length - (secondnumber+1).toString().length) + (firstnumber+1);
	
	firstfieldset.parentNode.insertBefore(secondfieldset, firstfieldset);
	
	if (direction == 1) {
		window.scrollTo(0, getElementY(firstfieldset));
	}
	else { // direction == -1
		window.scrollTo(0, getElementY(secondfieldset));
	}
}

var SymbolTable = new Object();
function myGetElementById(id)
{
	if (navigator.userAgent.indexOf('MSIE'))
	{
		// IE seems to have trouble updating its symbol table in obscure cases.
		// we decided to take matters into our own hands.
		if (typeof(SymbolTable[id]) == "undefined")
			SymbolTable[id] = document.getElementById(id);
		return SymbolTable[id];
	}
	else
	{
		return document.getElementById(id);
	}
}
function setId(node, newid)
{
	if (navigator.userAgent.indexOf('MSIE'))
		SymbolTable[newid] = node;
	node.id = newid;
	return newid;
}

function fixRepetitionIDs(node, repetitionnum, insertat)
{
	if (node.id) {
		var oldid = node.id;
		node.id = node.id.substr(0,insertat) + repetitionnum + node.id.substr(node.id.indexOf('_', insertat));
		SymbolTable[node.id] = node;
	}
	if (node.name)
		node.name = node.name.substr(0,insertat) + repetitionnum + node.name.substr(node.name.indexOf('_', insertat));
	if (node.nodeName.toLowerCase() == "label" && node.htmlFor)
		node.htmlFor = node.htmlFor.substr(0,insertat) + repetitionnum + node.htmlFor.substr(node.htmlFor.indexOf('_', insertat));
	if (node.nodeName.toLowerCase() == "option" && checkClass(node.parentNode, 'choicechooser'))
		node.value = node.value.substr(0,insertat) + repetitionnum + node.value.substr(node.value.indexOf('_', insertat));
	
	for (var a=0; a < node.childNodes.length; a++)
		fixRepetitionIDs(node.childNodes[a], repetitionnum, insertat);
}

function checkClass(node, classname)
{
	var classes = node.className.split(' ');
	for (var a=0; a < classes.length; a++)
	{
		if (classes[a] == classname)
			return true;
	}
	return false;
}

function makeChoice(selectelem)
{
	for(var a=0; a < selectelem.options.length; a++)
	{
		var elem = myGetElementById(selectelem.options[a].value);
		if (elem) elem.style.display='none';
	}
	var elem = myGetElementById(selectelem.options[selectelem.selectedIndex].value);
	if (elem) elem.style.display='block';
}

var fileTypes = new Object();
function newFileType(type)
{
	fileTypes[type] = new Object();
	fileTypes[type].listtable = myGetElementById(type + "_table");
	fileTypes[type].numfiles = myGetElementById(type + "_count").value;
	fileTypes[type].truenumfiles = myGetElementById(type + "_count").value;
}
function addFile(type)
{
	if (typeof(fileTypes[type]) == "undefined") newFileType(type);

	var table = myGetElementById(type + "_table");
	var tbody = table.getElementsByTagName('tbody')[0];
	var tr = tbody.appendChild(document.createElement("tr"));
	var td = tr.appendChild(document.createElement("td"));
	
	var countelem = myGetElementById(type + "_newcount");
	
	var inputthing = document.createElement("input");
	inputthing.type = "file";
	inputthing.name = setId(inputthing, type + "_" + countelem.value);
	
	countelem.value = parseInt(countelem.value) + 1;
	
	td.appendChild(inputthing);

	tr.appendChild(document.createElement("td"));
	tr.appendChild(document.createElement("td"));
	td = tr.appendChild(document.createElement("td"));
	
	var thisnumber = parseInt(myGetElementById(type + "_count").value) + parseInt(countelem.value) -1;
	
	var deletebutton = document.createElement('input');
	deletebutton.type = 'button';
	deletebutton.value = 'Delete';
	setId(deletebutton, 'deletebutton_' + type + "_" + thisnumber);
	deletebutton.className = 'button';
	deletebutton.associatedtype = type;
	deletebutton.associatednumber = thisnumber;
	deletebutton.onclick = function() {deleteFile(this.associatedtype, this.associatednumber)};

	td.appendChild(deletebutton);

	setId(tr, "file_" + type + "_" + thisnumber);
	
	fileTypes[type].numfiles++;
	fileTypes[type].truenumfiles++;
	if (fileTypes[type].numfiles == 1 && navigator.userAgent.indexOf('Gecko') == -1)
	{
		if (navigator.userAgent.indexOf('MSIE') != -1)
			fileTypes[type].listtable.style.display = 'block';
		else
			fileTypes[type].listtable.style.display = 'table';
	}
}
function renameFile(type, number)
{
	var renameelem = myGetElementById("rename_" + type + "_" + number);
	var newname = prompt("New name?", renameelem.value);
	if (newname == null) return;
	
	renameelem.value = newname;
	
	var td = myGetElementById("filename_" + type + "_" + number);
	for (var a=td.childNodes.length-1; a >= 0; a--) td.removeChild(td.childNodes[a]);
	td.appendChild(document.createTextNode(newname));
}
function deleteFile(type, number)
{
	if (typeof(fileTypes[type]) == "undefined") newFileType(type);

	if (number < myGetElementById(type + "_count").value)
	{
		//var renameelem = myGetElementById("rename_" + type + "_" + number);
		//if (!confirm("Are you sure you want to delete \"" + renameelem.value + "?\"")) return;

		myGetElementById("delete_" + type + "_" + number).value = 1;
	}

	var tablerow = myGetElementById("file_" + type + "_" + number);
	if (number < myGetElementById(type + "_count").value)
	{
		tablerow.style.display = 'none';
	}
	else
	{
		tablerow.parentNode.removeChild(tablerow);
		// rename and re-id the following files
		for (var a=number+1; a < fileTypes[type].truenumfiles; a++)
		{
			var subtract = myGetElementById(type + "_count").value;
			//alert(a + ", " + (a-subtract));
			setId(myGetElementById("file_" + type + "_" + a), "file_" + type + "_" + (a-1));
			setId(myGetElementById(type + "_" + (a-subtract)), type + "_" + (a-subtract-1));
			myGetElementById("deletebutton_" + type + "_" + a).associatednumber = a-1;
			setId(myGetElementById("deletebutton_" + type + "_" + a), "deletebutton_" + type + "_" + (a-1));
		}
		
		fileTypes[type].truenumfiles--;
		myGetElementById(type + "_newcount").value--;
	}

	fileTypes[type].numfiles--;
	if (fileTypes[type].numfiles == 0 && navigator.userAgent.indexOf('Gecko') == -1)
	{
		fileTypes[type].listtable.style.display = 'none';
	}
}

var currentURLid;
function selectURL(chooserbutton)
{
	currentURLid = chooserbutton.id.substr(0, chooserbutton.id.length - ("_chooser_").length);
	var URLchooser = window.open('?action=urlchooser', 'urlchooser');
	URLchooser.focus();
}
function chooseURL(chosenURL)
{
	window.opener.urlChosen(chosenURL, self);
	self.close();
	return false;
}
function urlChosen(chosenURL)
{
	var URLinput = document.getElementById(currentURLid);
	self.focus();
	if (URLinput)
	{
		URLinput.value = chosenURL;
		URLinput.focus();
	}
}

//document.onmouseover = function() {window.status = event.srcElement.id;};

function getElementY(elem)
{
	if (elem.offsetTop) return elem.offsetTop + getElementY(elem.offsetParent);
	return 0;
}

function toggleDisplay(id)
{
	var elem = myGetElementById(id);
	if (elem && elem.style) {
		if (elem.style.display != 'block') {
			elem.style.display = 'block';
		}
		else {
			elem.style.display = 'none';
		}
	}
	return false;
}

function toggleFieldset(link)
{
	if (link.firstChild.data=='-')
		link.firstChild.data='+';
	else
		link.firstChild.data='-';
		
	var id = link.parentNode.parentNode.id;
	
	return toggleDisplay(id + "_contents_");
}

function findfirstformelement(node)
{
	if (node.nodeName && ((node.nodeName.toLowerCase() == 'input' && node.type.toLowerCase() != 'hidden') || node.nodeName.toLowerCase() == 'select' || node.nodeName.toLowerCase() == 'textarea' || node.nodeName.toLowerCase() == 'button'))
	{
		return node;
	}
	for (var a=0; a < node.childNodes.length; a++)
	{
		var winner = findfirstformelement(node.childNodes[a]);
		if (winner) return winner;
	}
	return false;
}

var loadingstart = new Date();
function loaded() {
	var loadingend = new Date();
	if (loadingend.getTime() - loadingstart.getTime() < 300)
	{
		var firstformelement = findfirstformelement(document.getElementsByTagName('body')[0]);
		if (firstformelement)
			firstformelement.focus();
	}
}
onload = loaded;