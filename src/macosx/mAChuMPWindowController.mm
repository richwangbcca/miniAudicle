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

#import "mAChuMPWindowController.h"

#include "chuck_def.h"
#include "manager.h"
#include "util.h"
#include "chuck_version.h"

#include <algorithm>
#include <filesystem>
#include <sstream>
#include <stdexcept>

namespace fs = std::filesystem;

static const char * const g_manifestBaseURL = "https://chuck.stanford.edu/release/chump/manifest/";

static NSString * nsstr( const std::string & s )
{
    return [NSString stringWithUTF8String:s.c_str()];
}

static NSString * const g_pkgName        = @"name";
static NSString * const g_pkgDescription = @"description";
static NSString * const g_pkgLatest      = @"latestVersion";
static NSString * const g_pkgInstalled   = @"installedVersion";
static NSString * const g_pkgUpdateAvail = @"updateAvailable";
static NSString * const g_pkgKeywords    = @"keywords";

static void appendLine( NSMutableAttributedString * as,
                        NSString * label,
                        NSString * value,
                        NSFont * labelFont,
                        NSFont * valueFont,
                        NSColor * labelColor,
                        NSColor * valueColor )
{
    if( value == nil || [value length] == 0 )
        return;

    NSDictionary * labelAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      labelFont, NSFontAttributeName,
                                      labelColor, NSForegroundColorAttributeName,
                                      nil];
    NSDictionary * valueAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      valueFont, NSFontAttributeName,
                                      valueColor, NSForegroundColorAttributeName,
                                      nil];

    NSAttributedString * labelString = [[[NSAttributedString alloc]
                                         initWithString:label
                                         attributes:labelAttributes] autorelease];
    NSAttributedString * valueString = [[[NSAttributedString alloc]
                                         initWithString:[value stringByAppendingString:@"\n"]
                                         attributes:valueAttributes] autorelease];

    [as appendAttributedString:labelString];
    [as appendAttributedString:valueString];
}

static void appendLink( NSMutableAttributedString * as,
                        NSString * label,
                        NSString * urlString,
                        NSFont * labelFont,
                        NSFont * linkFont,
                        NSColor * labelColor )
{
    if( urlString == nil || [urlString length] == 0 )
        return;

    NSURL * url = [NSURL URLWithString:urlString];
    if( url == nil )
        return;

    NSDictionary * labelAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      labelFont, NSFontAttributeName,
                                      labelColor, NSForegroundColorAttributeName,
                                      nil];
    NSDictionary * linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     linkFont, NSFontAttributeName,
                                     [NSColor linkColor], NSForegroundColorAttributeName,
                                     [NSNumber numberWithInteger:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
                                     url, NSLinkAttributeName,
                                     nil];

    [as appendAttributedString:[[[NSAttributedString alloc]
                                 initWithString:label
                                 attributes:labelAttributes] autorelease]];
    [as appendAttributedString:[[[NSAttributedString alloc]
                                 initWithString:[urlString stringByAppendingString:@"\n"]
                                 attributes:linkAttributes] autorelease]];
}

@interface mAChuMPWindowController ()
{
    Manager * _manager;
    dispatch_queue_t _managerQueue;
    BOOL _isClosing;
}

- (void)initManager:(BOOL)updateManifest;
- (void)loadPackages;
- (void)filterWithQuery:(NSString *)query;
- (void)updateActionButton;
- (void)showDetailForPackage:(NSString *)name
                   installed:(NSString *)installedVer
                 updateAvail:(BOOL)updateAvail;
- (void)updateDisplayedPackages:(NSArray *)packages;

@end


@implementation mAChuMPWindowController

- (id)init
{
    if( self = [super initWithWindowNibName:@"mAChuMP"] )
    {
        _allPackages = [[NSArray alloc] init];
        _displayedPackages = [[NSArray alloc] init];
        _showInstalledOnly = NO;
        _manager = NULL;
        _isClosing = NO;
        _managerQueue = dispatch_queue_create( "edu.princeton.chuck.miniAudicle.chump", DISPATCH_QUEUE_SERIAL );
    }

    return self;
}

- (void)dealloc
{
    _isClosing = YES;

    if( _managerQueue )
    {
        dispatch_sync( _managerQueue, ^{
            if( _manager )
            {
                delete _manager;
                _manager = NULL;
            }
        } );
#if !OS_OBJECT_USE_OBJC
        dispatch_release( _managerQueue );
#endif
    }

    [_allPackages release];
    [_displayedPackages release];

    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [_detailTextView setTextContainerInset:NSMakeSize( 12, 12 )];
    [_detailTextView setLinkTextAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [NSColor linkColor], NSForegroundColorAttributeName,
      [NSNumber numberWithInteger:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
      [NSCursor pointingHandCursor], NSCursorAttributeName,
      nil]];

    [self initManager:NO];
}


#pragma mark NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    [_tableView deselectAll:self];
    [_detailTextView setString:@""];
}


#pragma mark IBActions

- (IBAction)installOrUninstall:(id)sender
{
    NSInteger row = [_tableView selectedRow];
    if( row < 0 || row >= (NSInteger)[_displayedPackages count] )
        return;

    NSDictionary * pkg = [_displayedPackages objectAtIndex:row];
    BOOL isInstalled = ([pkg objectForKey:g_pkgInstalled] != nil);
    BOOL updateAvail = [[pkg objectForKey:g_pkgUpdateAvail] boolValue];
    NSString * name = [pkg objectForKey:g_pkgName];
    std::string pkgName = [name UTF8String];

    NSString * label = nil;
    if( isInstalled && updateAvail )
        label = [NSString stringWithFormat:@"Updating %@...", name];
    else if( isInstalled )
        label = [NSString stringWithFormat:@"Uninstalling %@...", name];
    else
        label = [NSString stringWithFormat:@"Installing %@...", name];

    [_progressIndicator startAnimation:nil];
    [_statusLabel setStringValue:label];
    [_actionButton setEnabled:NO];
    [_searchField setEnabled:NO];
    [_installedOnlyCheckbox setEnabled:NO];

    dispatch_async( _managerQueue, ^{
        NSString * errorMessage = nil;

        if( _manager == NULL )
            errorMessage = @"ChuMP is not initialized.";
        else
        {
            try
            {
                if( isInstalled && updateAvail )
                    _manager->update( pkgName );
                else if( isInstalled )
                    _manager->uninstall( pkgName, false );
                else
                    _manager->install( pkgName );
            }
            catch( const std::exception & e )
            {
                errorMessage = [nsstr( std::string("[chump] ") + e.what() ) retain];
            }
        }

        dispatch_async( dispatch_get_main_queue(), ^{
            if( _isClosing )
            {
                [errorMessage release];
                return;
            }

            if( errorMessage != nil )
                [_statusLabel setStringValue:errorMessage];

            [errorMessage release];
            [self loadPackages];
        } );
    } );
}

- (IBAction)reload:(id)sender
{
    [self initManager:YES];
}

- (IBAction)search:(id)sender
{
    [self filterWithQuery:[_searchField stringValue]];
}

- (IBAction)showInstalledOnly:(id)sender
{
    _showInstalledOnly = ([_installedOnlyCheckbox state] == NSControlStateValueOn);
    [self filterWithQuery:[_searchField stringValue]];
}


#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_displayedPackages count];
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
             row:(NSInteger)row
{
    NSDictionary * pkg = [_displayedPackages objectAtIndex:row];
    NSString * name = [pkg objectForKey:g_pkgName];
    BOOL isInstalled = ([pkg objectForKey:g_pkgInstalled] != nil);
    BOOL updateAvail = [[pkg objectForKey:g_pkgUpdateAvail] boolValue];

    if( name == nil )
        name = @"";

    NSColor * nameColor = nil;
    if( updateAvail )
        nameColor = [NSColor systemOrangeColor];
    else if( isInstalled )
        nameColor = [NSColor secondaryLabelColor];
    else
        nameColor = [NSColor labelColor];

    NSDictionary * attributes = [NSDictionary dictionaryWithObject:nameColor
                                                            forKey:NSForegroundColorAttributeName];
    NSMutableAttributedString * attributedName = [[[NSMutableAttributedString alloc]
                                                   initWithString:name
                                                   attributes:attributes] autorelease];

    if( updateAvail )
    {
        NSDictionary * badgeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSColor systemOrangeColor], NSForegroundColorAttributeName,
                                          [NSFont systemFontOfSize:11], NSFontAttributeName,
                                          nil];
        NSAttributedString * badge = [[[NSAttributedString alloc]
                                       initWithString:@" ^"
                                       attributes:badgeAttributes] autorelease];
        [attributedName appendAttributedString:badge];
    }

    return attributedName;
}


#pragma mark NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [self updateActionButton];

    NSInteger row = [_tableView selectedRow];
    if( row < 0 || row >= (NSInteger)[_displayedPackages count] )
    {
        [_detailTextView setString:@""];
        return;
    }

    NSDictionary * pkg = [_displayedPackages objectAtIndex:row];
    [self showDetailForPackage:[pkg objectForKey:g_pkgName]
                     installed:[pkg objectForKey:g_pkgInstalled]
                   updateAvail:[[pkg objectForKey:g_pkgUpdateAvail] boolValue]];
}


#pragma mark Private

- (void)initManager:(BOOL)updateManifest
{
    [_progressIndicator startAnimation:nil];
    [_statusLabel setStringValue:(updateManifest ? @"Updating manifest..." : @"Initializing...")];
    [_actionButton setEnabled:NO];
    [_searchField setEnabled:NO];
    [_installedOnlyCheckbox setEnabled:NO];

    dispatch_async( _managerQueue, ^{
        Manager * newManager = NULL;
        NSString * errorMessage = nil;

        try
        {
            fs::path chump_dir = chumpDir();
            fs::path manifest_path = chump_dir / "manifest.json";
            std::string url = manifestURL( g_manifestBaseURL );

            fs::create_directories( chump_dir );

            ChuckVersion ck_ver = ChuckVersion::makeVersion( CHUCK_VERSION_STRING );
            ApiVersion api_ver = ApiVersion::makeVersion(
                std::to_string( CHUGIN_API_VERSION_MAJOR ) + "." +
                std::to_string( CHUGIN_API_VERSION_MINOR ) );

            newManager = new Manager( manifest_path.string(), chump_dir,
                                      ck_ver, api_ver,
                                      whichOS(), whichArch(),
                                      url, false );

            if( !validate_manifest( manifest_path ) )
                throw std::runtime_error( "No package manifest available. Check your network connection." );
        }
        catch( const std::exception & e )
        {
            errorMessage = [nsstr( std::string("[chump] ") + e.what() ) retain];
            delete newManager;
            newManager = NULL;
        }

        if( newManager != NULL )
        {
            Manager * oldManager = _manager;
            _manager = newManager;
            if( oldManager )
                delete oldManager;
        }

        dispatch_async( dispatch_get_main_queue(), ^{
            if( _isClosing )
            {
                [errorMessage release];
                return;
            }

            if( newManager != NULL )
            {
                [_searchField setEnabled:YES];
                [_installedOnlyCheckbox setEnabled:YES];
                [errorMessage release];
                [self loadPackages];
            }
            else
            {
                [_progressIndicator stopAnimation:nil];
                if( errorMessage != nil )
                    [_statusLabel setStringValue:errorMessage];
                [errorMessage release];

                dispatch_async( _managerQueue, ^{
                    BOOL hasManager = (_manager != NULL);
                    dispatch_async( dispatch_get_main_queue(), ^{
                        if( _isClosing )
                            return;

                        if( hasManager )
                        {
                            [_searchField setEnabled:YES];
                            [_installedOnlyCheckbox setEnabled:YES];
                            [self updateActionButton];
                        }
                    } );
                } );
            }
        } );
    } );
}

- (void)loadPackages
{
    [_progressIndicator startAnimation:nil];
    [_statusLabel setStringValue:@"Loading packages..."];

    dispatch_async( _managerQueue, ^{
        NSMutableArray * result = nil;
        NSString * errorMessage = nil;
        BOOL hasManager = (_manager != NULL);

        if( !hasManager )
            errorMessage = [@"ChuMP is not initialized." retain];
        else
        {
            try
            {
                std::vector<Package> packages = _manager->listPackages();
                std::sort( packages.begin(), packages.end() );

                result = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)packages.size()];

                for( std::vector<Package>::const_iterator iter = packages.begin();
                     iter != packages.end(); iter++ )
                {
                    const Package & pkg = *iter;
                    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
                    [dict setObject:nsstr( pkg.name ) forKey:g_pkgName];
                    [dict setObject:nsstr( pkg.description ) forKey:g_pkgDescription];

                    std::ostringstream keywords;
                    for( size_t i = 0; i < pkg.keywords.size(); i++ )
                    {
                        if( i > 0 )
                            keywords << ", ";
                        keywords << pkg.keywords[i];
                    }
                    [dict setObject:nsstr( keywords.str() ) forKey:g_pkgKeywords];

                    optional<PackageVersion> latest = _manager->latestPackageVersion( pkg.name );
                    if( latest )
                        [dict setObject:nsstr( latest->getVersionString() ) forKey:g_pkgLatest];

                    if( _manager->is_installed( pkg ) )
                    {
                        fs::path install_path = _manager->install_path( pkg );
                        optional<InstalledVersion> installedVersion =
                            _manager->open_installed_version_file( install_path / "version.json" );
                        if( installedVersion )
                        {
                            [dict setObject:nsstr( installedVersion->getVersionString() ) forKey:g_pkgInstalled];
                            if( latest && installedVersion->version() < *latest )
                                [dict setObject:[NSNumber numberWithBool:YES] forKey:g_pkgUpdateAvail];
                        }
                    }

                    [result addObject:dict];
                }
            }
            catch( const std::exception & e )
            {
                errorMessage = [nsstr( std::string("[chump] ") + e.what() ) retain];
                [result release];
                result = nil;
            }
        }

        dispatch_async( dispatch_get_main_queue(), ^{
            if( _isClosing )
            {
                [result release];
                [errorMessage release];
                return;
            }

            [_progressIndicator stopAnimation:nil];

            if( result != nil )
            {
                [self updateDisplayedPackages:result];
                [result release];
                [_searchField setEnabled:YES];
                [_installedOnlyCheckbox setEnabled:YES];
                [errorMessage release];
            }
            else
            {
                if( errorMessage != nil )
                    [_statusLabel setStringValue:errorMessage];
                [_searchField setEnabled:hasManager];
                [_installedOnlyCheckbox setEnabled:hasManager];
                [self updateActionButton];
                [errorMessage release];
            }
        } );
    } );
}

- (void)updateDisplayedPackages:(NSArray *)packages
{
    [_allPackages release];
    _allPackages = [packages copy];

    [_displayedPackages release];
    _displayedPackages = [packages copy];

    [_tableView reloadData];
    [self filterWithQuery:[_searchField stringValue]];

    NSInteger row = [_tableView selectedRow];
    if( row >= 0 && row < (NSInteger)[_displayedPackages count] )
    {
        NSDictionary * pkg = [_displayedPackages objectAtIndex:row];
        [self showDetailForPackage:[pkg objectForKey:g_pkgName]
                         installed:[pkg objectForKey:g_pkgInstalled]
                       updateAvail:[[pkg objectForKey:g_pkgUpdateAvail] boolValue]];
    }
    else
    {
        [_detailTextView setString:@""];
    }
}

- (void)filterWithQuery:(NSString *)query
{
    NSArray * source = _allPackages;

    if( _showInstalledOnly )
    {
        NSMutableArray * installedPackages = [NSMutableArray array];
        NSEnumerator * pkgEnumerator = [source objectEnumerator];
        NSDictionary * pkg = nil;
        while( ( pkg = [pkgEnumerator nextObject] ) )
        {
            if( [pkg objectForKey:g_pkgInstalled] != nil )
                [installedPackages addObject:pkg];
        }
        source = installedPackages;
    }

    if( query == nil || [query length] == 0 )
    {
        [_displayedPackages release];
        _displayedPackages = [source copy];
    }
    else
    {
        NSString * lowerQuery = [query lowercaseString];
        NSMutableArray * filteredPackages = [[NSMutableArray alloc] init];
        NSEnumerator * pkgEnumerator = [source objectEnumerator];
        NSDictionary * pkg = nil;

        while( ( pkg = [pkgEnumerator nextObject] ) )
        {
            NSString * name = [[pkg objectForKey:g_pkgName] lowercaseString];
            NSString * description = [[pkg objectForKey:g_pkgDescription] lowercaseString];
            NSString * keywords = [[pkg objectForKey:g_pkgKeywords] lowercaseString];

            if( [name rangeOfString:lowerQuery].location != NSNotFound ||
                [description rangeOfString:lowerQuery].location != NSNotFound ||
                [keywords rangeOfString:lowerQuery].location != NSNotFound )
            {
                [filteredPackages addObject:pkg];
            }
        }

        [_displayedPackages release];
        _displayedPackages = filteredPackages;
    }

    [_tableView reloadData];
    [self updateActionButton];

    if( [_tableView selectedRow] < 0 )
        [_detailTextView setString:@""];

    NSUInteger count = [_displayedPackages count];
    if( _showInstalledOnly )
        [_statusLabel setStringValue:[NSString stringWithFormat:@"%lu installed", (unsigned long)count]];
    else
        [_statusLabel setStringValue:[NSString stringWithFormat:@"%lu packages", (unsigned long)count]];
}

- (void)updateActionButton
{
    NSInteger row = [_tableView selectedRow];
    if( row < 0 || row >= (NSInteger)[_displayedPackages count] )
    {
        [_actionButton setEnabled:NO];
        [_actionButton setTitle:@"Install"];
        return;
    }

    NSDictionary * pkg = [_displayedPackages objectAtIndex:row];
    BOOL isInstalled = ([pkg objectForKey:g_pkgInstalled] != nil);
    BOOL updateAvail = [[pkg objectForKey:g_pkgUpdateAvail] boolValue];

    if( isInstalled && updateAvail )
        [_actionButton setTitle:@"Update"];
    else
        [_actionButton setTitle:(isInstalled ? @"Uninstall" : @"Install")];

    [_actionButton setEnabled:YES];
}

- (void)showDetailForPackage:(NSString *)name
                   installed:(NSString *)installedVer
                 updateAvail:(BOOL)updateAvail
{
    if( name == nil )
        return;

    [_detailTextView setString:@"Loading..."];

    NSString * selectedName = [name copy];
    NSString * installedVersion = [installedVer retain];
    dispatch_async( _managerQueue, ^{
        NSString * latestVersionString = nil;
        NSAttributedString * detailString = nil;
        NSString * missingMessage = nil;

        if( _manager == NULL )
            missingMessage = [@"ChuMP is not initialized." retain];
        else
        {
            try
            {
                optional<Package> package = _manager->getPackage( [selectedName UTF8String] );
                if( !package )
                    missingMessage = [@"(package not found)" retain];
                else
                {
                    Package pkg = *package;
                    NSString * packageName = nsstr( pkg.name );

                    optional<PackageVersion> latest = _manager->latestPackageVersion( pkg.name );
                    if( latest )
                        latestVersionString = [nsstr( latest->getVersionString() ) retain];

                    NSMutableAttributedString * as = [[NSMutableAttributedString alloc] init];

                    NSFont * titleFont = [NSFont boldSystemFontOfSize:16];
                    NSFont * labelFont = [NSFont boldSystemFontOfSize:11];
                    NSFont * valueFont = [NSFont systemFontOfSize:12];
                    NSFont * monoFont = [NSFont fontWithName:@"Menlo" size:11];
                    if( monoFont == nil )
                        monoFont = [NSFont systemFontOfSize:11];

                    NSColor * primaryColor = [NSColor labelColor];
                    NSColor * secondaryColor = [NSColor secondaryLabelColor];
                    NSColor * tertiaryColor = [NSColor tertiaryLabelColor];

                    NSDictionary * titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      titleFont, NSFontAttributeName,
                                                      primaryColor, NSForegroundColorAttributeName,
                                                      nil];
                    [as appendAttributedString:[[[NSAttributedString alloc]
                                                 initWithString:[packageName stringByAppendingString:@"\n\n"]
                                                 attributes:titleAttributes] autorelease]];

                    if( !pkg.description.empty() )
                    {
                        NSDictionary * descriptionAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                valueFont, NSFontAttributeName,
                                                                primaryColor, NSForegroundColorAttributeName,
                                                                nil];
                        [as appendAttributedString:[[[NSAttributedString alloc]
                                                     initWithString:[nsstr( pkg.description ) stringByAppendingString:@"\n\n"]
                                                     attributes:descriptionAttributes] autorelease]];
                    }

                    if( !pkg.authors.empty() )
                    {
                        std::string joinedAuthors;
                        for( size_t i = 0; i < pkg.authors.size(); i++ )
                        {
                            if( i > 0 ) joinedAuthors += ", ";
                            joinedAuthors += pkg.authors[i];
                        }
                        appendLine( as, @"Authors  ", nsstr( joinedAuthors ),
                                    labelFont, valueFont, secondaryColor, primaryColor );
                    }

                    if( !pkg.keywords.empty() )
                    {
                        std::string joinedKeywords;
                        for( size_t i = 0; i < pkg.keywords.size(); i++ )
                        {
                            if( i > 0 ) joinedKeywords += "  ";
                            joinedKeywords += pkg.keywords[i];
                        }
                        appendLine( as, @"Keywords  ", nsstr( joinedKeywords ),
                                    labelFont, monoFont, secondaryColor, tertiaryColor );
                    }

                    if( !pkg.license.empty() )
                    {
                        appendLine( as, @"License  ", nsstr( pkg.license ),
                                    labelFont, valueFont, secondaryColor, primaryColor );
                    }

                    if( !pkg.homepage.empty() || !pkg.repository.empty() )
                    {
                        NSDictionary * spacerAttributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:4]
                                                                                      forKey:NSFontAttributeName];
                        [as appendAttributedString:[[[NSAttributedString alloc]
                                                     initWithString:@"\n"
                                                     attributes:spacerAttributes] autorelease]];
                    }

                    appendLink( as, @"Homepage    ", nsstr( pkg.homepage ),
                                labelFont, valueFont, secondaryColor );
                    appendLink( as, @"Repository  ", nsstr( pkg.repository ),
                                labelFont, valueFont, secondaryColor );

                    if( installedVersion != nil )
                    {
                        NSDictionary * spacerAttributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:6]
                                                                                      forKey:NSFontAttributeName];
                        [as appendAttributedString:[[[NSAttributedString alloc]
                                                     initWithString:@"\n"
                                                     attributes:spacerAttributes] autorelease]];

                        NSString * installLine = nil;
                        if( updateAvail && latestVersionString != nil )
                        {
                            installLine = [NSString stringWithFormat:@"Installed %@  -  update available: %@",
                                           installedVersion, latestVersionString];
                        }
                        else
                        {
                            installLine = [NSString stringWithFormat:@"Installed %@", installedVersion];
                        }

                        appendLine( as, @"", installLine,
                                    labelFont, [NSFont systemFontOfSize:11],
                                    secondaryColor,
                                    ( updateAvail ? [NSColor systemOrangeColor] : [NSColor systemGreenColor] ) );
                    }
                    else if( latestVersionString != nil )
                    {
                        NSDictionary * spacerAttributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:6]
                                                                                      forKey:NSFontAttributeName];
                        [as appendAttributedString:[[[NSAttributedString alloc]
                                                     initWithString:@"\n"
                                                     attributes:spacerAttributes] autorelease]];

                        appendLine( as, @"Latest  ", latestVersionString,
                                    labelFont, [NSFont systemFontOfSize:11],
                                    secondaryColor, primaryColor );
                    }

                    if( pkg.long_description && !pkg.long_description->empty() )
                    {
                        NSDictionary * spacerAttributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:8]
                                                                                      forKey:NSFontAttributeName];
                        [as appendAttributedString:[[[NSAttributedString alloc]
                                                     initWithString:@"\n"
                                                     attributes:spacerAttributes] autorelease]];

                        NSDictionary * longDescriptionAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                    valueFont, NSFontAttributeName,
                                                                    primaryColor, NSForegroundColorAttributeName,
                                                                    nil];
                        [as appendAttributedString:[[[NSAttributedString alloc]
                                                     initWithString:nsstr( *pkg.long_description )
                                                     attributes:longDescriptionAttributes] autorelease]];
                    }

                    detailString = as;
                }
            }
            catch( const std::exception & e )
            {
                missingMessage = [nsstr( std::string("[chump] ") + e.what() ) retain];
            }
        }

        dispatch_async( dispatch_get_main_queue(), ^{
            NSInteger row = [_tableView selectedRow];
            NSDictionary * pkg = nil;

            if( _isClosing )
            {
                [selectedName release];
                [installedVersion release];
                [latestVersionString release];
                [detailString release];
                [missingMessage release];
                return;
            }

            if( row >= 0 && row < (NSInteger)[_displayedPackages count] )
                pkg = [_displayedPackages objectAtIndex:row];

            if( pkg == nil || ![[pkg objectForKey:g_pkgName] isEqualToString:selectedName] )
            {
                [selectedName release];
                [installedVersion release];
                [latestVersionString release];
                [detailString release];
                [missingMessage release];
                return;
            }

            if( detailString != nil )
            {
                [[_detailTextView textStorage] setAttributedString:detailString];
                [_detailTextView scrollPoint:NSZeroPoint];
            }
            else if( missingMessage != nil )
            {
                [_detailTextView setString:missingMessage];
            }

            [selectedName release];
            [installedVersion release];
            [latestVersionString release];
            [detailString release];
            [missingMessage release];
        } );
    } );
}

@end
