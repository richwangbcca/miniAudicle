#import <Cocoa/Cocoa.h>
#import "ScintillaView.h"

@interface mAScintillaView : NSView <ScintillaNotificationProtocol>

- (void)enableLineNumbers:(BOOL)enable;
- (void)reloadUserDefaults;

@property (nonatomic, copy) NSString *content;

// Direct ScintillaView access for makeFirstResponder
@property (nonatomic, readonly) ScintillaView *scintillaView;

@end
