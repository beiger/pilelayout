#import "PilelayoutPlugin.h"
#if __has_include(<pilelayout/pilelayout-Swift.h>)
#import <pilelayout/pilelayout-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "pilelayout-Swift.h"
#endif

@implementation PilelayoutPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPilelayoutPlugin registerWithRegistrar:registrar];
}
@end
