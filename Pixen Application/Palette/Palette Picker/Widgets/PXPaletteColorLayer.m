//
//  PXColorPickerColorWellCell.m
//  PXColorPicker
//
//  Created by Andy Matuschak on 7/7/05.
//  Copyright 2005 Pixen. All rights reserved.
//

#import "PXPaletteColorLayer.h"

#import "NSBezierPath+PXRoundedRectangleAdditions.h"

@interface NSImage (PXTintedImage)

- (NSImage *)tintedImage;

@end

@implementation NSImage (PXTintedImage)

- (NSImage *)tintedImage
{
	NSImage *tintImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
	
	[tintImage lockFocus];
	[[[NSColor blackColor] colorWithAlphaComponent:1] set];
	[[NSBezierPath bezierPathWithRect:(NSRect){NSZeroPoint, [self size]}] fill];
	[tintImage unlockFocus];
	
	NSImage *tintMaskImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
	[tintMaskImage lockFocus];
	[self compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
	[tintImage compositeToPoint:NSZeroPoint operation:NSCompositeSourceIn];
	[tintMaskImage unlockFocus];
	
	NSImage *newImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
	[newImage lockFocus];
	[self dissolveToPoint:NSZeroPoint fraction:0.6];
	[tintMaskImage compositeToPoint:NSZeroPoint operation:NSCompositeDestinationAtop];
	[newImage unlockFocus];
	
	return newImage;
}

@end


@implementation PXPaletteColorLayer

@synthesize color, index, controlSize, highlighted;

- (void)dealloc
{
	[color release];
	[super dealloc];
}

- (void)drawColorSwatchWithFrame:(NSRect)rect
{
	// Draw that black/white alpha helper and use non-blind compositing. But only if we have to.
	if ([color alphaComponent] != 1)
	{
		NSPoint points[3];
		NSBezierPath *path = [NSBezierPath bezierPath];
		
		// First draw the black triangle, which covers the upper-left portion of the rect.
		points[0] = NSMakePoint(NSMinX(rect), NSMinY(rect));
		points[1] = NSMakePoint(NSMaxX(rect), NSMinY(rect));
		points[2] = NSMakePoint(NSMinX(rect), NSMaxX(rect));
		
		[path appendBezierPathWithPoints:points count:3];
		
		[[NSColor blackColor] set];
		[path fill];
		
		// Now for the white triangle.
		points[0] = NSMakePoint(NSMaxX(rect), NSMinY(rect));
		points[1] = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
		points[2] = NSMakePoint(NSMinX(rect), NSMaxY(rect));
		
		[path removeAllPoints];
		[path appendBezierPathWithPoints:points count:3];
		
		[[NSColor whiteColor] set];
		[path fill];
		
		// Now composite over the actual color.
		[color set];
		NSRectFillUsingOperation(rect, NSCompositeSourceOver);
	}
	else
	{
		// Nothing fancy's required; just paint the color.
		[color set];
		NSRectFill(rect);
	}
}

- (void)drawInContext:(CGContextRef)ctx
{
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:ctx flipped:YES]];
	
	NSRect frame = NSRectFromCGRect([self bounds]);
	[color set];
	
	[self drawColorSwatchWithFrame:frame];
	
	int fontSize = [NSFont systemFontSizeForControlSize:NSMiniControlSize];
	
	if (index > 9999)
		fontSize = floorf(fontSize * .85);
	
	NSAttributedString *badgeString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d", index]
																	   attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor], NSForegroundColorAttributeName, [NSFont systemFontOfSize:fontSize], NSFontAttributeName, nil]] autorelease];
	
	NSSize badgeSize = [badgeString size];
	badgeSize.width += 6.5f;
	badgeSize.height += 0;
	
	NSRect badgeRect = NSMakeRect(NSMaxX(frame) - badgeSize.width - 1.5f, NSMaxY(frame) - badgeSize.height - 2, badgeSize.width, badgeSize.height);
	
	if (!highlighted) {
		[[[NSColor grayColor] colorWithAlphaComponent:0.5f] set];
		NSFrameRectWithWidthUsingOperation(frame, 2.0f, NSCompositeSourceOver);
	}
	
	// Exceuse me for my mdrfkr hardcoded numbers and ternary operators.
	int verticalTextOffset = (index > 9999) ? 1 : 2;
	
	NSBezierPath *indexBadge = [NSBezierPath bezierPathWithRoundedRect:badgeRect
														  cornerRadius:5
															 inCorners:OSBottomLeftCorner];
	
	if ([self controlSize] != NSRegularControlSize) {
		[NSGraphicsContext restoreGraphicsState];
		return;
	}
	
	[[[NSColor grayColor] colorWithAlphaComponent:0.5f] set];
	[indexBadge fill];
	
	[badgeString drawAtPoint:NSMakePoint(NSMaxX(frame) - badgeSize.width + 3, NSMaxY(frame) - badgeSize.height - verticalTextOffset)];
	
	if (highlighted) {
		NSSetFocusRingStyle(NSFocusRingAbove);
		NSFrameRectWithWidthUsingOperation(NSInsetRect(frame, -1, -1), 2.0f, NSCompositeSourceOver);
	}
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)setIndex:(NSUInteger)newIndex
{
	if (index != newIndex) {
		index = newIndex;
		[self setNeedsDisplay];
	}
}

- (void)setColor:(NSColor *)newColor
{
	if (color != newColor) {
		[color release];
		color = [newColor retain];
		
		[self setNeedsDisplay];
	}
}

- (void)setHighlighted:(BOOL)state
{
	if (highlighted != state) {
		highlighted = state;
		
		[self setNeedsDisplay];
	}
}

@end
