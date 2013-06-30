Titanium Facebook Module
================================

Module Goals
------------

* Reliable Facebook authorization
* Proper error recovery mechanisms and user messaging - per Facebook's specs
* Use recent, preferably current, Facebook SDKs otherwise the above is unlikely....
* Feature parity with Titanium's Android Facebook module
* Future: include additional Facebook SDK functionality, such as friend and place pickers

Module Versioning
-----------------

x.y.zt, where x.y.z is the Facebook iOS SDK version, t denotes the Titanium module version for this SDK.
The initial module version is 3.5.30 - i.e. uses Facebook iOS SDK 3.5.3

Module API
----------

The module tries to stick to the original Titanium Facebook iOS module API (distributed with Ti SDK 3.1.0).
However, there are some differences, and not all functionality is present yet.
As of version 3.5.30, the only implemented API is authorization, logout, and associated error handling.

*	`appid` - parameter unused. However, per the SDK docs, the app ID needs to be added in an additional key in plist.info (or tiapp.xml).
	In addition to the required `<property name="ti.facebook.appid">FACEBOOK_APP_ID</property>`, we also need to add the following:
	`<key>FacebookAppID</key> <string>FACEBOOK_APP_ID</string>` - you can add this in the ios plist dictionary in tiapp.xml
*	`forceDialogAuth` - parameter unused.
*	The rest of the parameters work as in the original module. `BUTTON_STYLE_NORMAL` and `BUTTON_STYLE_WIDE` untested at this point.
*	The `reauthorize`, `dialog` and `requestWithGraphPath` methods are not yet implemented.
*	The `createLoginButton` method is untested.
*	Of course the getters and setters for `appid` and `forceDialogAuth` are not needed.

Events and error handling
-------------------------

The `login` and `logout` events work as in the original module. 
However, the error handling is now adhering to Facebook's guidelines. Here is how to handle `login` events:
```javascript
fb.addEventListener('login', function(e) {
	if(e.success) {
		// do your thang.... 
	} else if (e.cancelled) {
		// login was cancelled, just show your login UI again
	} else if (e.error) {
		if (Ti.Platform.name === 'iPhone OS') {
			// For all of these errors - assume the user is logged out
			// so show your login UI
			if (e.error.indexOf('Go to Settings') === 0){
				// alert: Go to Settings > Facebook and turn ON My Cool App 
				alert(e.error + 'My Cool App')
			} else if (e.error.indexOf('Session Error') === 0){
				// Session was invalid - e.g. the user deauthorized your app, etc
				alert('Please login again.');
			} else if (e.error.indexOf('OTHER:') !== 0){
				// another error that may require user attention
				alert (e.error);
			} else {
				// if error string starts with OTHER: then it is some other error
				// probably nothing the user can do much about
				// so just pop a lame message to check the network and try again 
				alert('Please check your network connection and try again.')
			}
		} else {
			// not iOS............
```

*	note: the module currently does not cache user info (i.e. the `data` object for the `login` event, so if the the graph call
	during login fails, the user is logged out and you will get a `login` event with error set.
	This is fine for apps that need network access in any case, but not good for apps that are functional offline.
	
Feel free to comment and help out! :)
-------------------------------------
