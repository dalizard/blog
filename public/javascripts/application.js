// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

jQuery(document).ready(function () {
	jQuery('.post').hover(
		function () {
			jQuery(this).find('footer').animate({
				right: '-122px'
			}, 200);
		},
		function () {
			jQuery(this).find('footer').animate({
				right: '-47px'
			}, 200);
		}
	);
});