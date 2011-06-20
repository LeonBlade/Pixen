  //
  //  PXCanvasDocument.m
  //  Pixen
  //
  // Copyright (c) 2003,2004, 2005 Open Sword Group

  // Permission is hereby granted, free of charge, to any person obtaining a
  // copy of this software and associated documentation// files (the "Software"),
  // to deal in the Software without restriction, including without limitation
  // the rights to use, copy, modify, merge, publish, distribute, sublicense, 
  // and/or sell copies of the Software, and to permit persons
  // to whom the Software is furnished to do so, subject to the following 
  //conditions:

  // The above copyright notice and this permission notice shall be included
  // in all copies or substantial portions of the Software.

  // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
  //OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
  // IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
  // BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
  // OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
  // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
  //IN THE SOFTWARE.
  //
  //  PXCanvasDocument.m
  //  Pixen

  //  Created by Joe Osborn on Thu Sep 11 2003.
  //  Copyright (c) 2003 Open Sword Group. All rights reserved.
  //

#import "PXCanvasDocument.h"
#import "PXCanvasWindowController.h"
#import "PXCanvas.h"
#import "PXCanvas_ImportingExporting.h"
#import "PXCanvas_CopyPaste.h"
#import "PXCanvas_Drawing.h"
#import "PXCanvas_Modifying.h"
#import "PXCanvas_Layers.h"
#import "PXPalette.h"
#import "PXCanvasView.h"
#import "PXCanvasPrintView.h"
#import "PXLayerController.h"
#import "PXIconExporter.h"
#import "gif_lib.h"
#import "PXAnimatedGifExporter.h"
#import "PXLayer.h"
#import <AppKit/NSAlert.h>
#import "PXCanvasWindowController_IBActions.h"

BOOL isPowerOfTwo(int num);

@implementation PXCanvasDocument

- (id)init
{
	if ( ! ( self = [super init] ) ) 
		return nil;
	
	canvas = [[PXCanvas alloc] init];
	[canvas setUndoManager:[self undoManager]];
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared]; 
  return self;
}

- (void)setCanvas:(PXCanvas *)aCanvas
{
	[aCanvas retain];
	[canvas release];
	canvas = aCanvas;
	[canvas setUndoManager:[self undoManager]];
}

- (void)dealloc
{
	[windowController releaseCanvas];
	[canvas release];
    //	[[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (PXCanvasController *)canvasController
{
	return [windowController canvasController];
}

- (void)initWindowController
{
  windowController = [[PXCanvasWindowController alloc] initWithWindowNibName:@"PXCanvasDocument"];
}

- (void)setWindowControllerData
{
  [windowController setCanvas:canvas];
}


BOOL isPowerOfTwo(int num)
{
	double logResult = log2(num);
	return (logResult == (int)logResult);
}

- (void)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
  if(absoluteURL == nil)
  {
    return;
  }
  if ([typeName isEqualToString:JPEGFileType])
	{
		saveFactor = 100;
  }
  [super saveToURL:absoluteURL 
            ofType:typeName 
  forSaveOperation:saveOperation 
          delegate:delegate 
   didSaveSelector:didSaveSelector 
       contextInfo:contextInfo];
}

+ (NSData *)dataRepresentationOfType:(NSString *)aType withCanvas:(PXCanvas *)canvas
{
	if([aType isEqualToString:PixenImageFileType])
  {
		return [NSKeyedArchiver archivedDataWithRootObject:canvas];
  }
	
	if ([aType isEqualToString:JPEGFileType])
	{
		return [canvas imageDataWithType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0]
                                                                                           forKey:NSImageCompressionFactor]];
	}
  
	if ([aType isEqualToString:ICOFileType])
	{
		PXIconExporter *iconExporter = [[[PXIconExporter alloc] init] autorelease];
		return [iconExporter iconDataForCanvas:canvas];
	}
	
	if([aType isEqualToString:PNGFileType])
  {
		return [canvas imageDataWithType:NSPNGFileType properties:nil];
  }
	
	if([aType isEqualToString:TIFFFileType])
  {
		return [canvas imageDataWithType:NSTIFFFileType properties:nil];
  }
	
	if([aType isEqualToString:GIFFileType])
  {	
		id exportCanvas = canvas;
		exportCanvas = [canvas copy];
		[exportCanvas reduceColorsTo:256 withTransparency:YES matteColor:[NSColor whiteColor]];
		id exporter = [[PXAnimatedGifExporter alloc] initWithSize:[canvas size] iterations:1];
		[exporter writeCanvas:exportCanvas withDuration:0 transparentColor:nil];
		[exporter finalizeExport];
		return [exporter data];
      //return [PXGifExporter gifDataForImage:[canvas exportImage]];
  }
	if([aType isEqualToString:BMPFileType])
  {
		return [canvas imageDataWithType:NSBMPFileType properties:nil];
  }
	if([aType isEqualToString:PICTFileType])
  {
		NSMutableData *pictData = [NSMutableData data];
		CGImageDestinationRef pictOutput = 
		CGImageDestinationCreateWithData((CFMutableDataRef)pictData, 
																		 kUTTypePICT, 
																		 1, 
																		 NULL);
		CGImageDestinationAddImage(pictOutput,
															 [[canvas displayImage] CGImageForProposedRect:NULL 
																																		 context:nil 
																																			 hints:nil],
															 NULL);
		CGImageDestinationFinalize(pictOutput);
		return pictData;
  }
	
	return nil;
}

- (NSData *)dataOfType:(NSString *)type error:(NSError **)err
{
	if ([type isEqualToString:JPEGFileType])
	{
    NSNumber *sf = [NSNumber numberWithFloat:saveFactor];
    NSDictionary *props = [NSDictionary dictionaryWithObject:sf
                                                      forKey:NSImageCompressionFactor];
		return [canvas imageDataWithType:NSJPEGFileType 
                          properties:props];
	}
	return [[self class] dataRepresentationOfType:type withCanvas:canvas];
}

- (void)loadFromPasteboard:(NSPasteboard *)board
{	
	if ([[board types] containsObject:PXLayerPboardType])
	{
    NSData *data = [board dataForType:PXLayerPboardType];
		PXLayer *layer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		[canvas setSize:[layer size]];
		[canvas pasteFromPasteboard:board type:PXLayerPboardType];
	}
	else 
	{
		for (NSString *type in [NSImage imagePasteboardTypes])
		{
			if ([[board types] containsObject:type])
			{
				id image = [[[NSImage alloc] initWithPasteboard:board] autorelease];
				[canvas setSize:NSMakeSize(ceilf([image size].width), 
                                   ceilf([image size].height))];
				[canvas pasteFromPasteboard:board type:PXNSImagePboardType];
				break;
			}
		}
	}
	
	if (canvas)
	{
		[canvas setUndoManager:[self undoManager]];
		[self makeWindowControllers];
		// remove the auto-created main layer
		if ([[canvas layers] count] > 1)
    {
			[canvas removeLayerAtIndex:0];
    }
	}
	
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
}

- (void)delete:sender
{
	[windowController delete:sender];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)aType error:(NSError **)error
{
	if([aType isEqualToString:PixenImageFileType])
  {
		[canvas release];
		canvas = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
  }
	else if ([aType isEqualTo:BMPFileType])
	{
		[canvas release];
		canvas = [[PXCanvas alloc] init];
		[canvas replaceActiveLayerWithImage:[[[NSImage alloc] initWithData:data] autorelease]];
	}
	else
  {
		NSImage *image = [[[NSImage alloc] initWithData:data] autorelease];
		[canvas release];
		canvas = [[PXCanvas alloc] initWithImage:image type:aType];
  }
	if(canvas)
  {
		[canvas setUndoManager:[self undoManager]];
		[windowController setCanvas:canvas];
		[[self undoManager] removeAllActions];
		[self updateChangeCount:NSChangeCleared]; 
		return YES;
  }
	return NO;
}

- (void)printDocumentWithSettings:(NSDictionary *)printSettings
				   showPrintPanel:(BOOL)showPanels delegate:(id)delegate
				 didPrintSelector:(SEL)didPrintSelector contextInfo:(void *)contextInfo {
	
	if (!printableView) {
		printableView = [PXCanvasPrintView viewForCanvas:[self canvas]];
		[printableView retain];
	}
	
	float scale = [[[[self printInfo] dictionary] objectForKey:NSPrintScalingFactor] floatValue];
	
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform scaleXBy:scale yBy:scale];
	
	[printableView setBoundsOrigin:[transform transformPoint:[printableView frame].origin]];
	[printableView setBoundsSize:[transform transformSize:[printableView frame].size]];
	
	NSPrintOperation *op = [NSPrintOperation printOperationWithView:printableView
														  printInfo:[self printInfo]];
	[op setShowsPrintPanel:showPanels];
	[op setShowsProgressPanel:showPanels];
	
	[self runModalPrintOperation:op delegate:nil didRunSelector:NULL contextInfo:NULL];
}

-(PXCanvas *)canvas
{
	return canvas;
}

@end