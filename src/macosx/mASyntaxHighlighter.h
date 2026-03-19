/*----------------------------------------------------------------------------
miniAudicle
Cocoa GUI to chuck audio programming environment

Copyright (c) 2005-2013 Spencer Salazar.  All rights reserved.
http://chuck.cs.princeton.edu/
http://soundlab.cs.princeton.edu/

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
U.S.A.
-----------------------------------------------------------------------------*/

#import <Cocoa/Cocoa.h>

extern NSString *IDEKit_TextColorsPrefKey;

enum {
    IDEKit_kLangColor_Background = 0,
    IDEKit_kLangColor_NormalText,
    IDEKit_kLangColor_Invisibles,
    IDEKit_kLangColor_Adorners,
    IDEKit_kLangColor_Errors,
    IDEKit_kLangColor_OtherInternal2,   // 5
    IDEKit_kLangColor_OtherInternal3,
    IDEKit_kLangColor_OtherInternal4,
    // first the browser symbol coloring
    IDEKit_kLangColor_Classes,      // 8
    IDEKit_kLangColor_Constants,
    IDEKit_kLangColor_Enums,        // 10
    IDEKit_kLangColor_Functions,
    IDEKit_kLangColor_Globals,
    IDEKit_kLangColor_Macros,
    IDEKit_kLangColor_Templates,
    IDEKit_kLangColor_Typedefs, // 15
    IDEKit_kLangColor_OtherSymbol1,
    IDEKit_kLangColor_OtherSymbol2,
    IDEKit_kLangColor_OtherSymbol3,
    IDEKit_kLangColor_OtherSymbol4,
    // more syntax coloring
    IDEKit_kLangColor_Comments, // 20
    IDEKit_kLangColor_Keywords,
    IDEKit_kLangColor_Strings,
    IDEKit_kLangColor_FieldsBG, // for background completion templates
    IDEKit_kLangColor_Preprocessor,
    IDEKit_kLangColor_AltKeywords,  // 25
    IDEKit_kLangColor_DocKeywords,
    IDEKit_kLangColor_Characters,
    IDEKit_kLangColor_Numbers,
    IDEKit_kLangColor_OtherSyntax6,
    IDEKit_kLangColor_OtherSyntax7, // 30
    IDEKit_kLangColor_OtherSyntax8,
    IDEKit_kLangColor_UserKeyword1, // 32
    IDEKit_kLangColor_UserKeyword2,
    IDEKit_kLangColor_UserKeyword3,
    IDEKit_kLangColor_UserKeyword4,
    IDEKit_kLangColor_End
};
extern NSString *IDEKit_NameForColor(int color);

@interface NSColor(IDEKit_StringToColors)
+ (NSColor *)colorWithHTML: (NSString *)hex;
- (NSString *)htmlString;
@end
