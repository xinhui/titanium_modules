/**
 * Facebook Module
 * Copyright (c) 2009-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */

#import "FacebookModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiBlob.h"
#import "TiUtils.h"
#import "TiApp.h"
#import "TiFacebookLoginButtonProxy.h"

FBSession *mySession;

@implementation FacebookModule
#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"da8acc57-8673-4692-9282-e3c1a21f5d83";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"facebook";
}

#pragma mark Lifecycle

-(void)dealloc
{
	RELEASE_TO_NIL(stateListeners);
	RELEASE_TO_NIL(permissions);
	RELEASE_TO_NIL(uid);
	[super dealloc];
}

-(BOOL)handleRelaunch
{
	NSDictionary *launchOptions = [[TiApp app] launchOptions];
	if (launchOptions!=nil)
	{
		NSString *urlString = [launchOptions objectForKey:@"url"];
		if (urlString!=nil && [urlString hasPrefix:@"fb"])
		{
			// if we're resuming under the same URL, we need to ignore
			if (url!=nil && [urlString isEqualToString:url])
			{
				return YES;
			}
			RELEASE_TO_NIL(url);
			url = [urlString copy];
            return [FBSession.activeSession handleOpenURL:[NSURL URLWithString:urlString]];
		}
	}
	return NO;
}

-(void)resumed:(id)note
{
	VerboseLog(@"[DEBUG] facebook resumed");
	
	[self handleRelaunch];
}

-(void)activateApp:(NSNotification *)notification
{
    VerboseLog(@"[DEBUG] activateApp notification");
    [FBSession.activeSession handleDidBecomeActive];
}

-(void)startup
{
	VerboseLog(@"[DEBUG] facebook startup");
	[super startup];
	TiThreadPerformOnMainThread(^{
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];

        [nc addObserver:self selector:@selector(activateApp:) name:UIApplicationDidBecomeActiveNotification object:nil];
        if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
            // Start with logged-in state, guaranteed no login UX is fired since logged-in
            loggedIn = YES;
            [self authorize:nil];
        } else {
            loggedIn = NO;
        }
	}, YES);
}

-(void)shutdown:(id)sender
{
	VerboseLog(@"[DEBUG] facebook shutdown");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super shutdown:sender];
}

-(BOOL)isLoggedIn
{
    return loggedIn;
}

#pragma mark Auth Internals

- (void)populateUserDetails {
    TiThreadPerformOnMainThread(^{
        if (FBSession.activeSession.isOpen) {
            mySession = FBSession.activeSession;
            [[FBRequest requestForMe] startWithCompletionHandler:
             ^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error) {
                 RELEASE_TO_NIL(uid);
                 if (!error) {
                     uid = [[user objectForKey:@"id"] copy];
                     loggedIn = YES;
                     [self fireLoginChange];
                     [self fireLogin:user cancelled:NO withError:nil];
                 } else {
                     // Error on /me call
                     // In a future rev perhaps use stored user info
                     // But for now bail out
                     VerboseLog(@"/me graph call error");
                     if (error.fberrorCategory != FBErrorCategoryAuthenticationReopenSession) {
                         // Session errors will be handled by sessionStateChanged, not here
                         TiThreadPerformOnMainThread(^{
                             [FBSession.activeSession closeAndClearTokenInformation];
                         }, YES);
                         loggedIn = NO;
                         [self fireLoginChange];
                         [self fireLogin:nil cancelled:NO withError:error];
                     }
                 }
             }];
        }
    }, NO);
}

- (void)sessionStateChanged:(FBSession *)session
                      state:(FBSessionState) state
                      error:(NSError *)error
{
    RELEASE_TO_NIL(uid);
    if (error) {
        VerboseLog(@"sessionStateChanged error");
        loggedIn = NO;
        [self fireLoginChange];
        BOOL userCancelled = error.fberrorCategory == FBErrorCategoryUserCancelled;
        [self fireLogin:nil cancelled:userCancelled withError:error];
    } else {
        switch (state) {
            case FBSessionStateOpen:
                VerboseLog(@"[DEBUG] FBSessionStateOpen");
                [self populateUserDetails];
                 break;
            case FBSessionStateClosed:
            case FBSessionStateClosedLoginFailed:
                VerboseLog(@"[DEBUG] facebook session closed");
                TiThreadPerformOnMainThread(^{
                    [FBSession.activeSession closeAndClearTokenInformation];
                }, YES);
                
                loggedIn = NO;
                [self fireLoginChange];
                [self fireEvent:@"logout"];
                break;
            default:
                break;
        }
    }
}

#pragma mark Public APIs

/**
 * JS example:
 *
 * var facebook = require('facebook');
 * alert(facebook.uid);
 *
 */
-(id)uid
{
	return uid;
}

/**
 * JS example:
 *
 * var facebook = require('facebook');
 * if (facebook.loggedIn) {
 * }
 *
 */
-(id)loggedIn
{
	return NUMBOOL([self isLoggedIn]);
}

/**
 * JS example:
 *
 * var facebook = require('facebook');
 * facebook.permissions = ['read_stream'];
 * alert(facebook.permissions);
 *
 */
-(id)permissions
{
	return permissions;
}

/**
 * JS example:
 *
 * var facebook = require('facebook');
 * alert(facebook.accessToken);
 *
 */

-(id)accessToken
{
    return mySession.accessTokenData.accessToken;
}


/**
 * JS example:
 *
 * var facebook = require('facebook');
 * alert(facebook.expirationDate);
 *
 */

-(id)expirationDate
{
    return mySession.accessTokenData.expirationDate;
}

/**
 * JS example:
 *
 * var facebook = require('facebook');
 * facebook.permissions = ['publish_stream'];
 * alert(facebook.permissions);
 *
 */
-(void)setPermissions:(id)arg
{
	RELEASE_TO_NIL(permissions);
	permissions = [arg retain];
}

/**
 * JS example:
 *
 * var facebook = require('facebook');
 *
 * facebook.addEventListener('login',function(e) {
 *    if (e.success) {
 *		alert('login from uid: '+e.uid+', name: '+e.data.name);
 *    }
 *    else if (e.cancelled) {
 *      // user cancelled logout
 *    }
 *    else {
 *      alert(e.error);
 *    }
 * });
 *
 * facebook.addEventListener('logout',function(e) {
 *    alert('logged out');
 * });
 *
 * facebook.permissions = ['publish_stream'];
 * facebook.authorize();
 *
 */

-(void)authorize:(id)args
{
	VerboseLog(@"[DEBUG] facebook authorize");
	
//	if ([self isLoggedIn])
//	{
//		// if already authorized, this should do nothing
//		return;
//	}
	
	TiThreadPerformOnMainThread(^{
		NSArray *permissions_ = permissions == nil ? [NSArray array] : permissions;
        [FBSession openActiveSessionWithReadPermissions:permissions_
                                           allowLoginUI:YES
                                      completionHandler:
            ^(FBSession *session,
                FBSessionState state, NSError *error) {
                [self sessionStateChanged:session state:state error:error];
         }];
	}, NO);
}

/**
 * JS example:
 *
 * var facebook = require('facebook');
 * facebook.logout();
 *
 */
-(void)logout:(id)args
{
	VerboseLog(@"[DEBUG] facebook logout");
	if ([self isLoggedIn])
	{
        RELEASE_TO_NIL(uid);
        TiThreadPerformOnMainThread(^{
            [FBSession.activeSession closeAndClearTokenInformation];
        }, NO);
	}
}

/**
 * JS example:
 *
 * var facebook = require('facebook');
 * var button = facebook.createLoginButton({bottom:10});
 * window.add(button);
 *
 */
-(id)createLoginButton:(id)args
{
	return [[[TiFacebookLoginButtonProxy alloc] _initWithPageContext:[self executionContext] args:args module:self] autorelease];
}

#pragma mark Listener work

-(void)fireLoginChange
{
	if (stateListeners!=nil)
	{
		for (id<TiFacebookStateListener> listener in [NSArray arrayWithArray:stateListeners])
		{
			if (loggedIn)
			{
				[listener login];
			}
			else
			{
				[listener logout];
			}
		}
	}
}

-(void)fireLogin:(id)result cancelled:(BOOL)cancelled withError:(NSError *)error
{
	BOOL success = (result != nil);
	int code = [error code];
	if ((code == 0) && !success)
	{
		code = -1;
	}
	NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								  NUMBOOL(cancelled),@"cancelled",
								  NUMBOOL(success),@"success",
								  NUMINT(code),@"code",nil];
	if(error != nil){
        NSString * errorMessage = @"OTHER: ";
        if (error.fberrorShouldNotifyUser) {
            if ([[error userInfo][FBErrorLoginFailedReason]
                 isEqualToString:FBErrorLoginFailedReasonSystemDisallowedWithoutErrorValue]) {
                // Show a different error message
                errorMessage = @"Go to Settings > Facebook and turn ON ";
            } else {
                // If the SDK has a message for the user, surface it.
                errorMessage = error.fberrorUserMessage;
            }
        } else if (error.fberrorCategory == FBErrorCategoryAuthenticationReopenSession) {
            // It is important to handle session closures as mentioned. You can inspect
            // the error for more context but this sample generically notifies the user.
            errorMessage = @"Session Error";
        } else if (error.fberrorCategory == FBErrorCategoryUserCancelled) {
            // The user has cancelled a login. You can inspect the error
            // for more context. For this sample, we will simply ignore it.
            errorMessage = @"User cancelled the login process.";
        } else {
            // For simplicity, this sample treats other errors blindly, but you should
            // refer to https://developers.facebook.com/docs/technical-guides/iossdk/errors/ for more information.
            errorMessage = [errorMessage stringByAppendingFormat:@" %@", (NSString *) error];
        }
        [event setObject:errorMessage forKey:@"error"];
	}

	if(result != nil)
	{
		[event setObject:result forKey:@"data"];
		if (uid != nil)
		{
			[event setObject:uid forKey:@"uid"];
		}
	}
	[self fireEvent:@"login" withObject:event];
}


#pragma mark Listeners

-(void)addListener:(id<TiFacebookStateListener>)listener
{
	if (stateListeners==nil)
	{
		stateListeners = [[NSMutableArray alloc]init];
	}
	[stateListeners addObject:listener];
}

-(void)removeListener:(id<TiFacebookStateListener>)listener
{
	if (stateListeners!=nil)
	{
		[stateListeners removeObject:listener];
		if ([stateListeners count]==0)
		{
			RELEASE_TO_NIL(stateListeners);
		}
	}
}

MAKE_SYSTEM_PROP(BUTTON_STYLE_NORMAL,FB_LOGIN_BUTTON_NORMAL);
MAKE_SYSTEM_PROP(BUTTON_STYLE_WIDE,FB_LOGIN_BUTTON_WIDE);

@end
