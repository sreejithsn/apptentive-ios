//
//  Apptentive+Debugging.m
//  ApptentiveConnect
//
//  Created by Frank Schmitt on 1/4/16.
//  Copyright © 2016 Apptentive, Inc. All rights reserved.
//

#import "Apptentive+Debugging.h"
#import "ApptentiveWebClient.h"
#import "ApptentiveBackend.h"
#import "ApptentiveEngagementBackend.h"
#import "ApptentiveInteraction.h"
#import "ApptentiveDeviceInfo.h"
#import "ApptentiveMessageCenterViewController.h"
#import "ApptentiveTaskQueue.h"


@implementation Apptentive (Debugging)

- (ApptentiveDebuggingOptions)debuggingOptions {
	return 0;
}

- (NSString *)SDKVersion {
	return kApptentiveVersionString;
}

- (void)setAPIKey:(NSString *)APIKey baseURL:(NSURL *)baseURL storagePath:(nonnull NSString *)storagePath {
	if (![baseURL isEqual:self.baseURL]) {
		ApptentiveLogDebug(@"Base URL of %@ will not be used due to SDK version. Using %@ instead.", baseURL, self.baseURL);
	}

	if (![storagePath isEqualToString:self.storagePath]) {
		ApptentiveLogDebug(@"Storage path of %@ will not be used due to SDK version. Using %@ instead.", storagePath, self.storagePath);
	}

	self.APIKey = APIKey;
}

- (void)setLocalInteractionsURL:(NSURL *)localInteractionsURL {
	self.engagementBackend.localEngagementManifestURL = localInteractionsURL;
}

- (NSURL *)localInteractionsURL {
	return self.engagementBackend.localEngagementManifestURL;
}

- (NSString *)storagePath {
	return [self class].supportDirectoryPath;
}

- (NSURL *)baseURL {
	return self.webClient.baseURL;
}

- (UIView *)unreadAccessoryView {
	return [self unreadMessageCountAccessoryView:YES];
}

- (NSString *)manifestJSON {
	NSData *rawJSONData = self.engagementBackend.engagementManifestJSON;

	if (rawJSONData != nil) {
		NSData *outputJSONData = nil;

		// try to pretty-print by round-tripping through NSJSONSerialization
		id JSONObject = [NSJSONSerialization JSONObjectWithData:rawJSONData options:0 error:NULL];
		if (JSONObject) {
			outputJSONData = [NSJSONSerialization dataWithJSONObject:JSONObject options:NSJSONWritingPrettyPrinted error:NULL];
		}

		// fall back to ugly JSON
		if (!outputJSONData) {
			outputJSONData = rawJSONData;
		}

		return [[NSString alloc] initWithData:outputJSONData encoding:NSUTF8StringEncoding];
	} else {
		return nil;
	}
}

- (NSDictionary *)deviceInfo {
	return [[[[ApptentiveDeviceInfo alloc] init] dictionaryRepresentation] objectForKey:@"device"];
}

- (NSArray *)engagementEvents {
	return [self.engagementBackend targetedLocalEvents];
}

- (NSArray *)engagementInteractions {
	return [self.engagementBackend allEngagementInteractions];
}

- (NSInteger)numberOfEngagementInteractions {
	return [[self engagementInteractions] count];
}

- (NSString *)engagementInteractionNameAtIndex:(NSInteger)index {
	ApptentiveInteraction *interaction = [[self engagementInteractions] objectAtIndex:index];

	return [interaction.configuration objectForKey:@"name"] ?: [interaction.configuration objectForKey:@"title"] ?: @"Untitled Interaction";
}

- (NSString *)engagementInteractionTypeAtIndex:(NSInteger)index {
	ApptentiveInteraction *interaction = [[self engagementInteractions] objectAtIndex:index];

	return interaction.type;
}

- (void)presentInteractionAtIndex:(NSInteger)index fromViewController:(UIViewController *)viewController {
	[self.engagementBackend presentInteraction:[self.engagementInteractions objectAtIndex:index] fromViewController:viewController];
}

- (void)presentInteractionWithJSON:(NSDictionary *)JSON fromViewController:(UIViewController *)viewController {
	[self.engagementBackend presentInteraction:[ApptentiveInteraction interactionWithJSONDictionary:JSON] fromViewController:viewController];
}

- (NSString *)conversationToken {
	return [ApptentiveConversationUpdater currentConversation].token;
}

- (void)resetSDK {
	[[ApptentiveTaskQueue sharedTaskQueue] clear];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:ApptentiveCustomDeviceDataPreferenceKey];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:ApptentiveCustomPersonDataPreferenceKey];

	[self.engagementBackend resetEngagementData];
	[self.backend resetBackendData];

	[ApptentiveMessageCenterViewController resetPreferences];

	self.personName = nil;
	self.personEmailAddress = nil;

	self.APIKey = nil;
	self.appID = nil;

	[self setValue:nil forKey:@"backend"];
	[self setValue:nil forKey:@"webClient"];
	[self setValue:nil forKey:@"engagementBackend"];
}

- (void)checkSDKConfiguration {
	BOOL hasPhotoLibraryUsageDescription = [[NSBundle mainBundle].infoDictionary objectForKey:@"NSPhotoLibraryUsageDescription"] != nil;

	if (!hasPhotoLibraryUsageDescription) {
		ApptentiveLogError(@"No Photo Library Usage Description Set. This will cause your app to be rejected during app review.");
	}

	BOOL hasAppIDSet = self.appID != nil;

	if (!hasAppIDSet) {
		ApptentiveLogError(@"No App ID set. This may keep the ratings prompt from directing users to your app in the App Store.");
	}

	BOOL hasResources = [Apptentive resourceBundle] != nil;

	if (!hasResources) {
		ApptentiveLogError(@"Missing resources.");
#if APPTENTIVE_COCOAPODS
		ApptentiveLogError(@"Try cleaning derived data and/or `pod deintegrate && pod install`.");
#else
		ApptentiveLogError(@"Please make sure the resources are added to the appropriate target(s).");
#endif
	}
}

@end
