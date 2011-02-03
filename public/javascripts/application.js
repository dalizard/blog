// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

jQuery(document).ready(function () {
	jQuery(function() {
		var config = {
			sensitivity: 3,
			interval: 200,
			timeout: 200,
			over: function() {
				jQuery(this).find('a.read-more').animate({
					right: '-122px'
					}, 200);
				jQuery(this).find('.share').animate({
					bottom: '-3.2em'
				}, 200);			
			},
			out: function() {
				jQuery(this).find('a.read-more').animate({
					right: '-47px'
				}, 200);
				jQuery(this).find('.share').animate({
					bottom: '-1em'
				}, 200);					
			}
		}
		jQuery('.post').hoverIntent(config);
	});
});