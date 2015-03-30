// Checkmark every box if any are unchecked. If all are checked, this will uncheck all of them
function check_all() {
	var checked = $("input:checkbox:checked").length == $("input:checkbox").length;
	var chks = document.querySelectorAll("input[type='checkbox']");

	for (var i = 0; i < chks.length; i++) {
		chks[i].checked = !checked;
	}
}

// Check a checkbox by a specified ID number
function check(id_number) {
	var chks = document.querySelectorAll("input[type='checkbox'][value='" + id_number + "']");
	if (chks.length > 0) {
		chks[0].checked = true;
	}
}
