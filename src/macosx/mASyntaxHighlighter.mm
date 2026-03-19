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

#import "mASyntaxHighlighter.h"

NSString *IDEKit_TextColorsPrefKey = @"IDEKit_TextColors";

NSString *IDEKit_NameForColor(int color)
{
    switch (color) {
        case IDEKit_kLangColor_Background:
            return @"Background";
        case IDEKit_kLangColor_NormalText:
            return @"Normal Text";
        case IDEKit_kLangColor_Invisibles:
            return @"Invlsible Text";
        case IDEKit_kLangColor_Adorners:
            return @"Adorners";
        case IDEKit_kLangColor_Errors:
            return @"Errors";
        // first the browser symbol coloring
        case IDEKit_kLangColor_Classes:
            return @"Classes";
        case IDEKit_kLangColor_Constants: return @"Constants";
        case IDEKit_kLangColor_Enums: return @"Enums";
        case IDEKit_kLangColor_Functions: return @"Functions";
        case IDEKit_kLangColor_Globals: return @"Globals";
        case IDEKit_kLangColor_Macros: return @"Macros";
        case IDEKit_kLangColor_Templates: return @"Templates";
        case IDEKit_kLangColor_Typedefs: return @"Typedefs";
        // more syntax coloring
        case IDEKit_kLangColor_Comments: return @"Comments";
        case IDEKit_kLangColor_Keywords: return @"Keywords";
        case IDEKit_kLangColor_Preprocessor: return @"Preprocessor";
        case IDEKit_kLangColor_AltKeywords: return @"AltKeywords";
        case IDEKit_kLangColor_DocKeywords: return @"DocKeywords";
        case IDEKit_kLangColor_Strings: return @"Strings";
        case IDEKit_kLangColor_FieldsBG: return @"Field Background";
        case IDEKit_kLangColor_Characters: return @"Characters";
        case IDEKit_kLangColor_Numbers: return @"Numbers";
        case IDEKit_kLangColor_UserKeyword1: return @"User 1";
        case IDEKit_kLangColor_UserKeyword2: return @"User 2";
        case IDEKit_kLangColor_UserKeyword3: return @"User 3";
        case IDEKit_kLangColor_UserKeyword4: return @"User 4";
        // spencer: add ugens
        case IDEKit_kLangColor_OtherSymbol1: return @"UGens";
    }
    return nil;
}


@implementation NSColor(IDEKit_StringToColors)
+ (NSColor *)colorWithHTML: (NSString *)hex
{
    // for example, string should be "#ffffff"
    NSScanner *scanner = [NSScanner scannerWithString: hex];
    [scanner setCharactersToBeSkipped: [NSCharacterSet characterSetWithCharactersInString: @" #,$"]];
    [scanner setCaseSensitive: NO];
    unsigned value;
    if ([scanner scanHexInt: &value] == NO) value = 0;
    return [NSColor colorWithCalibratedRed: float((value >> 16) & 0xff) / 255.0 green: float((value >> 8) & 0xff) / 255.0 blue: float((value) & 0xff) / 255.0 alpha: 1.0];
}
- (NSString *)htmlString
{
    id rgb = [self colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
    return [NSString stringWithFormat: @"#%.2X%.2X%.2X", (int)([rgb redComponent] * 255.0),(int)([rgb greenComponent] * 255.0),(int)([rgb blueComponent] * 255.0)];
}
@end
