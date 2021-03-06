/*
 * Copyright 2011 Tim Horton. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY TIM HORTON "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL TIM HORTON OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NBDocument.h"

#import "NBWindowController.h"
#import "NBDocumentController.h"
#import "NotebookAppDelegate.h"

@implementation NBDocument

@synthesize notebookView;
@synthesize languageButton;
@synthesize splitView;
@synthesize initialized;
@synthesize initializedFromFile;
@synthesize notebook;
@synthesize searchResultsView;
@synthesize globalsTableView;
@synthesize searchField;

- (id)init
{
    self = [super init];

    if(self != nil)
    {
        initialized = initializedFromFile = NO;

        notebook = [[NBNotebook alloc] init];
        watchedGlobals = [[NSMutableArray alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(finishedEvaluation:)
                                                     name:NBCellFinishedEvaluationNotification
                                                   object:notebook];
    }

    return self;
}

- (void)setInitialized:(BOOL)inInitialized
{
    initialized = inInitialized;

    // Synchronize all window titles after initialization, so they'll include the language name

    for(NSWindowController * windowController in [self windowControllers])
    {
        [windowController synchronizeWindowTitleWithDocumentName];
    }
}

- (void)makeWindowControllers
{
    NBWindowController * windowController = [[NBWindowController alloc] initWithWindowNibPath:[[NSBundle mainBundle] pathForResource:@"Notebook" ofType:@"nib"] owner:self];

    [self addWindowController:windowController];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    [notebookView setNotebook:notebook];
    [searchResultsView setDataSource:self];
    [globalsTableView setDataSource:self];
    [searchResultsView setDelegate:self];
    [globalsTableView setDelegate:self];
    
    [searchResultsView registerForDraggedTypes:[NSArray arrayWithObject:NBDocumentGlobalDragType]];
    [globalsTableView registerForDraggedTypes:[NSArray arrayWithObject:NBDocumentGlobalDragType]];
}

- (void)finishLoadingFile:(NSDictionary *)userData
{
    [self initDocumentWithEngineClass:[userData objectForKey:@"engineClass"] withTemplate:nil];

    // We need to disable undo registration while creating the cells, otherwise a document will
    // appear as edited immediately after being loaded

    [[self undoManager] disableUndoRegistration];

    for(NBCell * cell in [userData objectForKey:@"cells"])
    {
        [notebook addCell:cell];
    }

    [[self undoManager] enableUndoRegistration];
}

+ (NSString *)fileExtension
{
    return @"txt";
}

+ (NSString *)fileTypeName
{
    return @"Notebook";
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation
{
    return [NSArray arrayWithObject:[self fileType]];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    Class engineClass = [[NSDocumentController sharedDocumentController] engineClassForType:typeName];

    NSData * data = nil;

    if(engineClass)
    {
        NBEngineEncoder * encoder = [[[engineClass encoderClass] alloc] init];
        data = [encoder dataForCells:notebook.cells];
    }

    if(outError != nil)
    {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
	}

	return data;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    self.initializedFromFile = YES;

    Class engineClass = [[NSDocumentController sharedDocumentController] engineClassForType:typeName];

    if(engineClass)
    {
        NBEngineEncoder * encoder = [[[engineClass encoderClass] alloc] init];

        [[NSRunLoop mainRunLoop] performSelector:@selector(finishLoadingFile:)
                                          target:self
                                        argument:[NSDictionary dictionaryWithObjectsAndKeys:[encoder cellsFromData:data],@"cells",engineClass,@"engineClass",nil]
                                           order:0
                                           modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
    }
    else
    {
        NSLog(@"Unknown file type: %@", typeName);

        if(outError != nil)
        {
            *outError = [NSError errorWithDomain:@"Notebook" code:1 userInfo:nil]; // TODO: better errors
        }

        return NO;
    }


    if(outError != nil)
    {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
	}

    return YES;
}

- (void)initDocumentWithEngineClass:(Class)engineClass withTemplate:(NSString *)template
{
    [notebook setEngine:[[engineClass alloc] init]];

    [languageButton setTitle:[engineClass name]];

    [self setFileType:NSStringFromClass([engineClass documentClass])];

    self.initialized = YES;

    // We need to disable undo registration while creating the cells, otherwise a document will
    // appear as edited immediately after being created

    [[self undoManager] disableUndoRegistration];

    if([template isEqualToString:@"empty-cell"]) // TODO: these need to come from somewhere
    {
        NBCell * cell = [[NBCell alloc] init];
        cell.type = NBCellSnippet;
        [notebook addCell:cell];
    }

    [[self undoManager] enableUndoRegistration];
}

- (BOOL)hasKeyCell
{
    return ([self keyCellView] != nil);
}

- (BOOL)hasSelectedCell
{
    return ([self selectedCellViews] && ([[self selectedCellViews] count] > 0));
}

- (BOOL)keyCellIsRichText
{
    NBCellView * cellView = [self keyCellView];

    if(cellView)
    {
        return [cellView isRichText];
    }
    else
    {
        return NO;
    }
}

- (IBAction)doSomethingButton:(id)sender
{
    NSLog(@"something");
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
    [[NSApp delegate] setCurrentDocument:self];
}

#pragma mark Selection

- (NBCellView *)keyCellView
{
    NSResponder * firstResponder = [[NSApp keyWindow] firstResponder];

    if([firstResponder conformsToProtocol:@protocol(NBCellSubview)])
    {
        return [(id<NBCellSubview>)firstResponder parentCellView];
    }

    return nil;
}

- (NSArray *)selectedCellViews
{
    NSArray * selectedViews = notebookView.selectedCellViews;

    if([selectedViews count])
    {
        NSMutableArray * orderedSelectedViews = [[NSMutableArray alloc] init];

        // Iterate through in the order that the cells are in the notebook so that
        // they are in display order and not in selection order

        for(NBCell * cell in notebook.cells)
        {
            NBCellView * cellView = [notebookView.cellViews objectForKey:cell];

            if([selectedViews containsObject:cellView])
            {
                [orderedSelectedViews addObject:cellView];
            }
        }

        return orderedSelectedViews;
    }
    else
    {
        NBCellView * currentView = [self keyCellView];

        if(currentView)
        {
            return [NSArray arrayWithObject:currentView];
        }
    }

    return nil;
}

#pragma mark Menu Actions

- (IBAction)increaseIndent:(id)sender
{
    NSResponder * firstResponder = [[NSApp keyWindow] firstResponder];

    if([firstResponder respondsToSelector:@selector(increaseIndent)])
    {
        [(NBTextView *)firstResponder increaseIndent];
    }
}

- (IBAction)decreaseIndent:(id)sender
{
    NSResponder * firstResponder = [[NSApp keyWindow] firstResponder];

    if([firstResponder respondsToSelector:@selector(decreaseIndent)])
    {
        [(NBTextView *)firstResponder decreaseIndent];
    }
}

- (IBAction)insertCell:(id)sender
{
    NBCellView * lastSelectedView = [[self selectedCellViews] lastObject];

    NBCell * newCell = [[NBCell alloc] init];
    newCell.type = NBCellSnippet;

    if(lastSelectedView)
    {
        [notebook addCell:newCell afterCell:[lastSelectedView cell]];
    }
    else
    {
        [notebook addCell:newCell];
    }
}

- (IBAction)deleteCell:(id)sender
{
    NSArray * selectedViews = [self selectedCellViews];

    if([selectedViews count])
    {
        for(NBCellView * cellView in selectedViews)
        {
            [notebook removeCell:[cellView cell]];
        }
    }
}

- (IBAction)splitCell:(id)sender
{
    NBCellView * keyView;
    NSRange splitLocation;

    keyView = [self keyCellView];

    if(!keyView)
    {
        return;
    }

    splitLocation = [keyView editableCursorLocation];

    if(splitLocation.location == NSNotFound)
    {
        return;
    }

    [notebook splitCell:[keyView cell] atLocation:splitLocation.location];
}

- (IBAction)mergeCells:(id)sender
{
    NSMutableArray * cells = [[NSMutableArray alloc] init];

    for(NBCellView * cellView in [self selectedCellViews])
    {
        [cells addObject:[cellView cell]];
    }

    [notebook mergeCells:cells];
}

- (IBAction)evaluateCells:(id)sender
{
    for(NBCellView * cellView in [self selectedCellViews])
    {
        [[cellView cell] evaluate];
    }
}

- (IBAction)abortEvaluation:(id)sender
{
    [[notebook engine] abort];
}

- (IBAction)selectAllCells:(id)sender
{
    [notebookView selectAll];
}

- (IBAction)selectAllCellsAboveCurrent:(id)sender
{
    NSArray * selectedViews = [self selectedCellViews];
    NBCellView * startView = [selectedViews objectAtIndex:0];

    if([selectedViews count] != 1)
    {
        return;
    }

    [notebookView deselectAll];

    for(NBCell * cell in notebook.cells)
    {
        NBCellView * cellView = [notebookView.cellViews objectForKey:cell];

        [notebookView selectedCell:cellView];

        if(cellView == startView)
        {
            break;
        }
    }
}

- (IBAction)selectAllCellsBelowCurrent:(id)sender
{
    BOOL sawStartView = NO;
    NSArray * selectedViews = [self selectedCellViews];
    NBCellView * startView = [selectedViews objectAtIndex:0];

    if([selectedViews count] != 1)
    {
        return;
    }

    [notebookView deselectAll];

    for(NBCell * cell in notebook.cells)
    {
        NBCellView * cellView = [notebookView.cellViews objectForKey:cell];

        if(cellView == startView)
        {
            sawStartView = YES;
        }

        if(sawStartView)
        {
            [notebookView selectedCell:cellView];
        }
    }
}

#pragma mark Globals Sidebar

// TODO: most of this stuff needs to move elsewhere

- (void)finishedEvaluation:(NSNotification *)notification
{
    globalsCache = [[[notebook engine] globals] copy];
    
    [searchResultsView reloadData];
    [searchResultsView setNeedsDisplay:YES];
    
    [globalsTableView reloadData];
    [globalsTableView setNeedsDisplay:YES];
}

- (IBAction)searchGlobals:(id)sender
{
    NSString * searchString = [searchField stringValue];
    
    if(!searchString || [searchString isEqualToString:@""])
    {
        filteredGlobals = nil;
    }
    else
    {
        NSMutableDictionary * newFilteredGlobals = [[NSMutableDictionary alloc] init];
        
        for(NSString * global in globalsCache)
        {
            NSRange findRange = [global rangeOfString:[searchField stringValue]];
            
            if(findRange.location != NSNotFound)
            {
                [newFilteredGlobals setObject:[globalsCache objectForKey:global] forKey:global];
            }
        }
        
        filteredGlobals = newFilteredGlobals;
    }
    
    [searchResultsView reloadData];
    [searchResultsView setNeedsDisplay:YES];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if(tableView == searchResultsView)
    {
        NSDictionary * globals = filteredGlobals ? filteredGlobals : globalsCache;
        
        return [[globals allKeys] count];
    }
    else if(tableView == globalsTableView)
    {
        return [watchedGlobals count] || 1;
    }
    
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if(tableView == searchResultsView)
    {
        NSDictionary * globals = filteredGlobals ? filteredGlobals : globalsCache;
        
        if([[tableColumn identifier] isEqualToString:@"icon"])
        {
            NSString * type = [globals objectForKey:[[globals allKeys] objectAtIndex:row]];
            return [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:type]];
        }
        else if([[tableColumn identifier] isEqualToString:@"name"])
        {
            return [[globals allKeys] objectAtIndex:row];
        }
    }
    else if(tableView == globalsTableView)
    {
        if([[tableColumn identifier] isEqualToString:@"icon"])
        {
            if(![watchedGlobals count])
                return nil;

            NSString * type = [globalsCache objectForKey:[watchedGlobals objectAtIndex:row]];
            return [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:type]];
        }
        else if([[tableColumn identifier] isEqualToString:@"name"])
        {
            if(![watchedGlobals count])
            {
                NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                [paragraphStyle setAlignment:NSCenterTextAlignment];
                NSDictionary * attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor grayColor], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
                NSAttributedString * dragString = [[NSAttributedString alloc] initWithString:@"Drag globals here." attributes:attrs];
                return dragString;
            }

            return [NSString stringWithFormat:@"%@ = %@", [watchedGlobals objectAtIndex:row], [[notebook engine] globalWithKey:[watchedGlobals objectAtIndex:row]]];
        }
    }
    
    return nil;
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    if(tableView == searchResultsView)
    {
        NSDictionary * globals = filteredGlobals ? filteredGlobals : globalsCache;
        NSMutableSet * globalNames = [[NSMutableSet alloc] init];
        
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [globalNames addObject:[[globals allKeys] objectAtIndex:idx]];
        }];
        
        NSData * data = [NSKeyedArchiver archivedDataWithRootObject:globalNames];
        
        [pboard declareTypes:[NSArray arrayWithObject:NBDocumentGlobalDragType] owner:self];
        [pboard setData:data forType:NBDocumentGlobalDragType];
        
        return YES;
    }
    else if(tableView == globalsTableView)
    {
        return NO;
    }
    
    return NO;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    if(tableView == searchResultsView)
    {
        return NSDragOperationNone;
    }
    else if(tableView == globalsTableView)
    {
        return NSDragOperationLink;
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    if(tableView == searchResultsView)
    {
        return NO;
    }
    else if(tableView == globalsTableView)
    {
        NSPasteboard * pboard = [info draggingPasteboard];
        NSData * nameData = [pboard dataForType:NBDocumentGlobalDragType];
        NSSet * globalNames = [NSKeyedUnarchiver unarchiveObjectWithData:nameData];
        
        [watchedGlobals addObjectsFromArray:[globalNames allObjects]];
        [tableView reloadData];
        
        return YES;
    }
    
    return NO;
}

@end
