#import "TSApplicationsManager.h"
#import <TSUtil.h>
extern NSUserDefaults* trollStoreUserDefaults();

@implementation TSApplicationsManager

+ (instancetype)sharedInstance
{
    static TSApplicationsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TSApplicationsManager alloc] init];
    });
    return sharedInstance;
}

- (NSArray*)installedAppPaths
{
    return trollStoreInstalledAppBundlePaths();
}

- (NSError*)errorForCode:(int)code
{
    NSString* errorDescription = NSLocalizedString(@"Unknown Error",nil);
    switch(code)
    {
        // IPA install errors
        case 166:
        errorDescription = NSLocalizedString(@"The IPA file does not exist or is not accessible.",nil);
        break;
        case 167:
        errorDescription = NSLocalizedString(@"The IPA file does not appear to contain an app.",nil);
        break;
        case 168:
        errorDescription = NSLocalizedString(@"Failed to extract IPA file.",nil);
        break;
        case 169:
        errorDescription = NSLocalizedString(@"Failed to extract update tar file.",nil);
        break;
        // App install errors
        case 170:
        errorDescription = NSLocalizedString(@"Failed to create container for app bundle.",nil);
        break;
        case 171:
        errorDescription = NSLocalizedString(@"A non-TrollStore app with the same identifier is already installed. If you are absolutely sure it is not, you can force install it.",nil);
        break;
        case 172:
        errorDescription = NSLocalizedString(@"The app does not contain an Info.plist file.",nil);
        break;
        case 173:
        errorDescription = NSLocalizedString(@"The app is not signed with a fake CoreTrust certificate and ldid is not installed. Install ldid in the settings tab and try again.",nil);
        break;
        case 174:
        errorDescription = NSLocalizedString(@"The app's main executable does not exist.",nil);
        break;
        case 175: {
            //if (@available(iOS 16, *)) {
            //    errorDescription = @"Failed to sign the app.";
            //}
            //else {
                errorDescription = NSLocalizedString(@"Failed to sign the app. ldid returned a non zero status code.",nil);
            //}
        }
        break;
        case 176:
        errorDescription = NSLocalizedString(@"The app's Info.plist is missing required values.",nil);
        break;
        case 177:
        errorDescription = NSLocalizedString(@"Failed to mark app as TrollStore app.",nil);
        break;
        case 178:
        errorDescription = NSLocalizedString(@"Failed to copy app bundle.",nil);
        break;
        case 179:
        errorDescription = NSLocalizedString(@"The app you tried to install has the same identifier as a system app already installed on the device. The installation has been prevented to protect you from possible bootloops or other issues.",nil);
        break;
        case 180:
        errorDescription = NSLocalizedString(@"The app you tried to install has an encrypted main binary, which cannot have the CoreTrust bypass applied to it. Please ensure you install decrypted apps.",nil);
        break;
        case 181:
        errorDescription = NSLocalizedString(@"Failed to add app to icon cache.",nil);
        break;
        case 182:
        errorDescription = NSLocalizedString(@"The app was installed successfully, but requires developer mode to be enabled to run. After rebooting, select \"Turn On\" to enable developer mode.",nil);
        break;
        case 183:
        errorDescription = NSLocalizedString(@"Failed to enable developer mode.",nil);
        break;
        case 184:
        errorDescription = NSLocalizedString(@"The app was installed successfully, but has additional binaries that are encrypted (e.g. extensions, plugins). The app itself should work, but you may experience broken functionality as a result.",nil);
    }

    NSError* error = [NSError errorWithDomain:TrollStoreErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
    return error;
}

- (int)installIpa:(NSString*)pathToIpa force:(BOOL)force log:(NSString**)logOut
{
    NSMutableArray* args = [NSMutableArray new];
    [args addObject:NSLocalizedString(@"install",nil)];
    if(force)
    {
        [args addObject:@"force"];
    }
    NSNumber* installationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"installationMethod"];
    int installationMethodToUse = installationMethodToUseNum ? installationMethodToUseNum.intValue : 1;
    if(installationMethodToUse == 1)
    {
        [args addObject:NSLocalizedString(@"custom",nil)];
    }
    else
    {
        [args addObject:NSLocalizedString(@"installd",nil)];
    }
    [args addObject:pathToIpa];

    int ret = spawnRoot(rootHelperPath(), args, nil, logOut);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)installIpa:(NSString*)pathToIpa
{
    return [self installIpa:pathToIpa force:NO log:nil];
}

- (int)uninstallApp:(NSString*)appId
{
    if(!appId) return -200;

    NSMutableArray* args = [NSMutableArray new];
    [args addObject:NSLocalizedString(@"uninstall",nil)];

    NSNumber* uninstallationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"uninstallationMethod"];
    int uninstallationMethodToUse = uninstallationMethodToUseNum ? uninstallationMethodToUseNum.intValue : 0;
    if(uninstallationMethodToUse == 1)
    {
        [args addObject:NSLocalizedString(@"custom",nil)];
    }
    else
    {
        [args addObject:NSLocalizedString(@"installd",nil)];
    }

    [args addObject:appId];

    int ret = spawnRoot(rootHelperPath(), args, nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)uninstallAppByPath:(NSString*)path
{
    if(!path) return -200;

    NSMutableArray* args = [NSMutableArray new];
    [args addObject:@"uninstall-path"];

    NSNumber* uninstallationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"uninstallationMethod"];
    int uninstallationMethodToUse = uninstallationMethodToUseNum ? uninstallationMethodToUseNum.intValue : 0;
    if(uninstallationMethodToUse == 1)
    {
        [args addObject:NSLocalizedString(@"custom",nil)];
    }
    else
    {
        [args addObject:NSLocalizedString(@"installd",nil)];
    }

    [args addObject:path];

    int ret = spawnRoot(rootHelperPath(), args, nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (BOOL)openApplicationWithBundleID:(NSString *)appId
{
    return [[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:appId];
}

- (int)enableJITForBundleID:(NSString *)appId
{
    return spawnRoot(rootHelperPath(), @[@"enable-jit", appId], nil, nil);
}

- (int)changeAppRegistration:(NSString*)appPath toState:(NSString*)newState
{
    if(!appPath || !newState) return -200;
    return spawnRoot(rootHelperPath(), @[@"modify-registration", appPath, newState], nil, nil);
}

@end
