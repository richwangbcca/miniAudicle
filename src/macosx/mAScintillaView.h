#import <Cocoa/Cocoa.h>
#import "external/scintilla/cocoa/ScintillaView.h"

@interface mAScintillaView : NSView <ScintillaNotificationProtocol>

- (void)enableLineNumbers:(BOOL)enable;
- (void)reloadUserDefaults;
- (void)toggleLineComment;

@property (nonatomic, copy) NSString *content;

// Direct ScintillaView access for makeFirstResponder
@property (nonatomic, readonly) ScintillaView *scintillaView;

@end
