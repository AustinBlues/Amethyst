$(document).ready(function(){
	$('a.back_nav').click(function(){
		parent.history.back();
		return false;
	});
});
