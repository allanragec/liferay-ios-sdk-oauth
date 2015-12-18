/**
 * Copyright (c) 2000-present Liferay, Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation; either version 2.1 of the License, or (at your option)
 * any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 */

#import "LROAuthWebView.h"

#import "LRAccessToken.h"
#import "LRRequestToken.h"

#define OAUTH_PORTLET_FORM_ID @"_3_WAR_oauthportlet_fm"
#define OAUTH_TOKEN @"oauthportlet_oauth_token"

/**
 * @author Allan Melo
 */
@interface LROAuthWebView() <UIWebViewDelegate>

@property (nonatomic, weak) id<LROAuthCallback> callback;
@property (nonatomic, strong) LROAuthConfig *config;

@end

@implementation LROAuthWebView

#pragma mark - Public Methods

- (void)start:(LROAuthConfig *)config callback:(id<LROAuthCallback>)callback {
	[self _start:config callback:callback denyURL:nil
		grantAutomatically:YES];
}

- (void)start:(LROAuthConfig *)config callback:(id<LROAuthCallback>)callback
		denyURL:(NSString *)denyURL {

	[self _start:config callback:callback denyURL:denyURL
		grantAutomatically:NO];
}

#pragma mark - Private Methods

- (void) _clearAllCookies {
	NSHTTPCookieStorage *storage = [NSHTTPCookieStorage
		sharedHTTPCookieStorage];

	for (NSHTTPCookie *cookie in [storage cookies]) {
		[storage deleteCookie:cookie];
	}

	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_hideWebView:(NSURLRequest *)request {
	if (self.grantAutomatically && [self _isGrantPage:request.URL]) {
		self.hidden = YES;

		if ([self.callback respondsToSelector:@selector(onGrantedAccess)]) {
			[self.callback onGrantedAccess];
		}
	}
}

- (BOOL)_isGrantPage:(NSURL *)URL {
	NSUInteger range = [URL.absoluteString rangeOfString:OAUTH_TOKEN].location;
	return (range != NSNotFound);
}

- (void)_onCallBackURL:(NSURL *)url {
	self.config.verifier = url.absoluteString;

	[LRAccessToken accessTokenWithConfig:self.config
		onSuccess:^(LROAuthConfig *config) {
			config.server = self.config.server;

			self.config = config;
			[self.callback onSuccess:self.config];
			
		}
		onFailure:^(NSError *error) {
			[self.callback onFailure:error];
		}
	 ];	
}

- (void)_start:(LROAuthConfig *)config callback:(id<LROAuthCallback>)callback
		denyURL:(NSString *)denyURL
		grantAutomatically:(BOOL)grantAutomatically {

	self.delegate = self;

	self.config = config;
	self.callback = callback;
	self.denyURL = denyURL;
	self.grantAutomatically = grantAutomatically;

	[LRRequestToken requestTokenWithConfig:self.config
		onSuccess:^(LROAuthConfig *config) {
			self.config = config;
			
			NSURL *url = [NSURL URLWithString:self.config.authorizeTokenURL];
			NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
			[self loadRequest:request];
		}
		onFailure:^(NSError *error) {
			[self.callback onFailure:error];
		}
	 ];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	if (self.grantAutomatically && [self _isGrantPage:webView.request.URL]) {
		NSString *queryButton =  [NSString
			stringWithFormat:@"document.getElementById('%@')",
			OAUTH_PORTLET_FORM_ID];

		[webView stringByEvaluatingJavaScriptFromString:
		[queryButton stringByAppendingString:@".submit();"]];
	}
}

- (BOOL)webView:(UIWebView *)webView
		shouldStartLoadWithRequest:(NSURLRequest *)request
		navigationType:(UIWebViewNavigationType)navigationType {

	[self _hideWebView:request];

	if ([request.URL.absoluteString hasPrefix:self.config.callbackURL]) {
		[self _onCallBackURL:webView.request.URL];
		[self _clearAllCookies];
		
		return NO;
	}
	else if (self.denyURL &&
			[request.URL.absoluteString hasSuffix:self.denyURL]) {

		if ([self.callback respondsToSelector:@selector(onDeniedAccess)]) {
			[self.callback onDeniedAccess];
		}

		[self _clearAllCookies];

		return NO;
	}

	return YES;
}

@end