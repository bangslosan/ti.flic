/**
 * ti.flic
 *
 * Created by Hans Knoechel
 * Copyright (c) 2016 Your Company. All rights reserved.
 */

#import "TiFlicModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "TiApp.h"

#define ENSURE_AND_FIRE_EVENT(event, dict) \
{\
    if (![self _hasListeners:event]) {\
        return;\
    }\
    [self fireEvent:event withObject:dict];\
}\

@implementation TiFlicModule

#pragma mark Internal

- (id)moduleGUID
{
	return @"217e0fd5-c0c4-413c-bafe-803226fb139a";
}

- (NSString *)moduleId
{
	return @"ti.flic";
}

#pragma mark Lifecycle

- (void)startup
{
	[super startup];
	NSLog(@"[DEBUG] %@ loaded",self);
}

#pragma mark Cleanup

- (void)shutdown:(id)sender
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super shutdown:sender];
}

- (void)dealloc
{
    [super dealloc];
}

#pragma mark Notification Observer

- (void)didHandleURL:(NSNotification *)notification
{
    NSString *url = [[[TiApp app] launchOptions] objectForKey:@"url"];
    
    if (!url) {
        NSLog(@"[ERROR] Tried to handle an URL but it was null!");
        return;
    }
    
    [[SCLFlicManager sharedManager] handleOpenURL:[NSURL URLWithString:url]];
}

#pragma Public APIs

- (void)configure:(id)args
{
    ENSURE_SINGLE_ARG(args, NSDictionary);
    
    NSString *appID;
    NSString *appSecret;
    
    ENSURE_ARG_FOR_KEY(appID, args, @"appID", NSString);
    ENSURE_ARG_FOR_KEY(appSecret, args, @"appSecret", NSString);
    
    if ([appID isEqualToString:@""] || [appSecret isEqualToString:@""]) {
        NSLog(@"[WARN] The 'appID' and 'appSecret' should not be empty!");
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didHandleURL:)
                                                 name:@"TiApplicationLaunchedFromURL"
                                               object:nil];
    
    [SCLFlicManager configureWithDelegate:self
                    defaultButtonDelegate:self
                                    appID:appID
                                appSecret:appSecret
                      backgroundExecution:[TiUtils boolValue:@"backgroundExecution" properties:args def:NO]];
}

- (void)grabFlicFromFlicAppWithCallbackUrlScheme:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
    [[SCLFlicManager sharedManager] grabFlicFromFlicAppWithCallbackUrlScheme:value];
}

- (void)enable:(id)unused
{
    [[SCLFlicManager sharedManager] enable];
}

- (void)disable:(id)unused
{
    [[SCLFlicManager sharedManager] disable];
}

- (void)onLocationChange:(id)unused
{
    [[SCLFlicManager sharedManager] onLocationChange];
}

- (id)isEnabled:(id)unused
{
    return NUMBOOL([[SCLFlicManager sharedManager] isEnabled]);
}

- (id)bluetoothState
{
    return NUMINTEGER([[SCLFlicManager sharedManager] bluetoothState]);
}

- (id)knownButtons
{
    NSMutableArray *knownButtons = [NSMutableArray array];
    
    
    for (NSUUID *uuid in [[SCLFlicManager sharedManager] knownButtons]) {
        SCLFlicButton *button = [[[SCLFlicManager sharedManager] knownButtons] objectForKey:uuid];
        [knownButtons addObject:[TiFlicModule dictionaryFromFlickButton:button andError:nil]];
    }
    
    return knownButtons;
}

#pragma mark Flic Button methods

// TODO: Move all of these in own proxy

- (NSDictionary *)getButtonByUUID:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
    
    SCLFlicButton *flicButton = [self flicButtonFromUUIDString:value];
    
    if (!flicButton) {
        NSLog(@"[ERROR] Could not get button with UUID = %@, the button does not seem to be active and connected.");
        return;
    }
    
    return [TiFlicModule dictionaryFromFlickButton:flicButton andError:nil];
    
}

- (void)forgetButton:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
    
    SCLFlicButton *flicButton = [self flicButtonFromUUIDString:value];
    
    if (!flicButton) {
        NSLog(@"[ERROR] Could not forget button with UUID = %@, the button does not seem to be active and connected.");
        return;
    }
    
    [[SCLFlicManager sharedManager] forgetButton:flicButton];
}

- (void)connectButton:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
    
    SCLFlicButton *flicButton = [self flicButtonFromUUIDString:value];
    
    if (!flicButton) {
        NSLog(@"[ERROR] Could not connect to button with UUID = %@, the button does not seem to be reachable.");
        return;
    }
    
    [flicButton connect];
}

- (void)disconnectButton:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
    
    SCLFlicButton *flicButton = [self flicButtonFromUUIDString:value];
    
    if (!flicButton) {
        NSLog(@"[ERROR] Could not disconnect from button with UUID = %@, the button does not seem to be reachable.");
        return;
    }
    
    [flicButton disconnect];
}

- (void)indicateButtonLED:(id)value
{
    ENSURE_SINGLE_ARG(value, NSNumber);
    
    SCLFlicButton *flicButton = [self flicButtonFromUUIDString:value];
    
    if (!flicButton) {
        NSLog(@"[ERROR] Could not indicate LED from button with UUID = %@, the button does not seem to be reachable.");
        return;
    }
    
    [flicButton indicateLED:[TiFlicModule numbertoIndicateCount:value]];
}

- (void)readButtonRSSI:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
    
    SCLFlicButton *flicButton = [self flicButtonFromUUIDString:value];
    
    if (!flicButton) {
        NSLog(@"[ERROR] Could not read RSSI from button with UUID = %@, the button does not seem to be reachable.");
        return;
    }
    
    [flicButton readRSSI];
}

#pragma mark ButtonDelegates

- (void) flicButton:(SCLFlicButton * _Nonnull) button didReceiveButtonDown:(BOOL) queued age: (NSInteger) age
{
    ENSURE_AND_FIRE_EVENT(@"didReceiveButtonDown", (@{@"queued": NUMBOOL(queued), @"age": NUMINTEGER(age)}));
}

- (void) flicButton:(SCLFlicButton * _Nonnull) button didReceiveButtonUp:(BOOL) queued age: (NSInteger) age
{
    ENSURE_AND_FIRE_EVENT(@"didReceiveButtonUp", (@{@"queued": NUMBOOL(queued), @"age": NUMINTEGER(age)}));
}

- (void) flicButton:(SCLFlicButton * _Nonnull) button didReceiveButtonClick:(BOOL) queued age: (NSInteger) age
{
    ENSURE_AND_FIRE_EVENT(@"didReceiveButtonClick", (@{@"queued": NUMBOOL(queued), @"age": NUMINTEGER(age)}));
}

- (void) flicButton:(SCLFlicButton * _Nonnull) button didReceiveButtonDoubleClick:(BOOL) queued age: (NSInteger) age
{
    ENSURE_AND_FIRE_EVENT(@"didReceiveButtonDoubleClick", (@{@"queued": NUMBOOL(queued), @"age": NUMINTEGER(age)}));
}

- (void) flicButton:(SCLFlicButton * _Nonnull) button didReceiveButtonHold:(BOOL) queued age: (NSInteger) age
{
    ENSURE_AND_FIRE_EVENT(@"didReceiveButtonHold", (@{@"queued": NUMBOOL(queued), @"age": NUMINTEGER(age)}));
}

- (void) flicButtonDidConnect:(SCLFlicButton * _Nonnull) button
{
    ENSURE_AND_FIRE_EVENT(@"flicButtonDidConnect", nil);
}

- (void) flicButtonIsReady:(SCLFlicButton * _Nonnull) button
{
    ENSURE_AND_FIRE_EVENT(@"flicButtonIsReady", nil);
}

- (void) flicButton:(SCLFlicButton * _Nonnull) button didDisconnectWithError:(NSError * _Nullable) error
{
    ENSURE_AND_FIRE_EVENT(@"didDisconnectWithError", [TiFlicModule dictionaryFromFlickButton:button andError:error]);
}

- (void) flicButton:(SCLFlicButton * _Nonnull) button didFailToConnectWithError:(NSError * _Nullable) error
{
    ENSURE_AND_FIRE_EVENT(@"didFailToConnectWithError", [TiFlicModule dictionaryFromFlickButton:button andError:error]);
}

- (void) flicButton:(SCLFlicButton * _Nonnull) button didUpdateRSSI:(NSNumber * _Nonnull) RSSI error:(NSError * _Nullable) error
{
    ENSURE_AND_FIRE_EVENT(@"didUpdateRSSI", [TiFlicModule dictionaryFromFlickButton:button andError:error]);
}

#pragma mark Manager Delegates

- (void) flicManager:(SCLFlicManager * _Nonnull) manager didGrabFlicButton:(SCLFlicButton * _Nullable) button withError: (NSError * _Nullable) error
{
    ENSURE_AND_FIRE_EVENT(@"didGrabFlicButton", [TiFlicModule dictionaryFromFlickButton:button andError:error]);
}

- (void) flicManager:(SCLFlicManager * _Nonnull) manager didChangeBluetoothState: (SCLFlicManagerBluetoothState) state
{
    ENSURE_AND_FIRE_EVENT(@"didChangeBluetoothState", @{@"state": NUMINTEGER(state)});
}

- (void) flicManagerDidRestoreState:(SCLFlicManager * _Nonnull) manager
{
    ENSURE_AND_FIRE_EVENT(@"didRestoreState", nil);
}

- (void) flicManager:(SCLFlicManager * _Nonnull) manager didForgetButton:(NSUUID * _Nonnull) buttonIdentifier error:(NSError * _Nullable)error
{
    ENSURE_AND_FIRE_EVENT(@"didForgetButton", (@{@"identifier":buttonIdentifier.UUIDString, @"error": [error localizedDescription] ?: [NSNull null]}));
}

#pragma mark Utilities

- (SCLFlicButton *)flicButtonFromUUIDString:(NSString *)UUIDString
{
    NSUUID *ownUUID = [[NSUUID alloc] initWithUUIDString:UUIDString];
    
    for (NSUUID *uuid in [[SCLFlicManager sharedManager] knownButtons]) {
        SCLFlicButton *button = [[[SCLFlicManager sharedManager] knownButtons] objectForKey:uuid];
        
        if ([button buttonIdentifier] == ownUUID) {
            RELEASE_TO_NIL(ownUUID);
            return button;
        }
    }
    
    RELEASE_TO_NIL(ownUUID);
    NSLog(@"[ERROR] Could not find Flic button with UUID = %@. Make sure it is reachable.", UUIDString);
    
    return nil;
}

+ (SCLFlicButtonLEDIndicateCount)numbertoIndicateCount:(NSNumber *)number
{
    int count = [TiUtils intValue:number def:-1];
    
    if (count < 1 || count > 5) {
        NSLog(@"[ERROR] Invalid number (%i) supplied. Please choose a number between 1 and 5.");
        return nil;
    }
    
    switch (count) {
        case 1:
        return SCLFlicButtonLEDIndicateCount1;
        case 2:
        return SCLFlicButtonLEDIndicateCount2;
        case 3:
        return SCLFlicButtonLEDIndicateCount3;
        case 4:
        return SCLFlicButtonLEDIndicateCount4;
        case 5:
        return SCLFlicButtonLEDIndicateCount5;
        default:
        NSLog(@"[ERROR] Logic error! Please report an issue to the Ti.Flic repository!");
        return nil;
    }
}

+ (NSDictionary *)dictionaryFromFlickButton:(SCLFlicButton *)button andError:( NSError* _Nullable)error
{
    if (button == nil) {
        return @{};
    }
    
    if (error != nil) {
        return @{
            @"error": [error localizedDescription],
            @"isReady": NUMBOOL(NO)
        };
    }
    
    // TODO: Move to own proxy so we can connect/disconnect manually
    return @{
         @"identifier": button.buttonIdentifier.UUIDString,
         @"publicKey": button.buttonPublicKey,
         @"name": button.name,
         @"userAssignedName": button.userAssignedName,
         @"connectionState": NUMINTEGER(button.connectionState),
         @"lowLatency": NUMBOOL(button.lowLatency),
         @"triggerBehavior": NUMINTEGER(button.triggerBehavior),
         @"pressCount": NUMINT(button.pressCount),
         @"isReady": NUMBOOL(button.isReady)
    };
}

// CBCentralManager* constants are deprecated since iOS 10, use CBManager* constants instead.
// We keep them here for backward-compatibility
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_POWERED_ON, CBManagerStatePoweredOn);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_POWERED_OFF, CBManagerStatePoweredOff);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_RESETTING, CBManagerStateResetting);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_UNSUPPORTED, CBManagerStateUnsupported);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_UNAUTHORIZED, CBManagerStateUnauthorized);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_UNKNOWN, CBManagerStateUnknown);
#else
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_POWERED_ON, CBCentralManagerStatePoweredOn);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_POWERED_OFF, CBCentralManagerStatePoweredOff);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_RESETTING, CBCentralManagerStateResetting);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_UNSUPPORTED, CBCentralManagerStateUnsupported);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_UNAUTHORIZED, CBCentralManagerStateUnauthorized);
MAKE_SYSTEM_PROP(BLUETOOTH_STATE_UNKNOWN, CBCentralManagerStateUnknown);
#endif

MAKE_SYSTEM_PROP(CONNECTION_STATE_CONNECTED, SCLFlicButtonConnectionStateConnected);
MAKE_SYSTEM_PROP(CONNECTION_STATE_CONNECTING, SCLFlicButtonConnectionStateConnecting);
MAKE_SYSTEM_PROP(CONNECTION_STATE_DISCONNECTED, SCLFlicButtonConnectionStateDisconnected);
MAKE_SYSTEM_PROP(CONNECTION_STATE_DISCONNECTING, SCLFlicButtonConnectionStateDisconnecting);

MAKE_SYSTEM_PROP(TRIGGER_BEHAVIOR_CLICK_AND_HOLD, SCLFlicButtonTriggerBehaviorClickAndHold);
MAKE_SYSTEM_PROP(TRIGGER_BEHAVIOR_CLICK_AND_DOUBLE_CLICK, SCLFlicButtonTriggerBehaviorClickAndDoubleClick);
MAKE_SYSTEM_PROP(TRIGGER_BEHAVIOR_CLICK_AND_DOUBLE_CLICK_AND_HOLD, SCLFlicButtonTriggerBehaviorClickAndDoubleClickAndHold);

@end
