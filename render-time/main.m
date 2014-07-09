//
//  main.m
//  render-time
//
//  Created by Jason Barrie Morley on 12/06/2014.
//  Copyright (c) 2014 Jason Barrie Morley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

static CGPoint point(CGPoint center, CGFloat angle, CGFloat r) {
  CGFloat t = (angle * -1) + M_PI_2;
  return CGPointMake(center.x + (r * cos(t)), center.y + (r * sin(t)));
}

void renderTime(CGContextRef context, NSUInteger hours, NSUInteger minutes)
{
  static CGFloat lineWidth = 8.0;
  static CGFloat radius = 60.0;
  static CGFloat hourScale = 0.6;
  static CGFloat minuteScale = 0.8;
  static CGPoint center = { 100.0, 100.0 };

  // Set up.
  NSColor *color = [NSColor whiteColor];
  CGContextSetStrokeColorWithColor(context, color.CGColor);
  CGContextSetLineWidth(context, lineWidth);
  CGContextSetLineCap(context, kCGLineCapRound);
  
  // Clock.
  CGContextAddArc(context, center.x, center.y, radius, 0.0, M_PI * 2, 1);
  CGContextStrokePath(context);
  
  // Determine the positions of the hands.
  CGPoint hourPoint = point(center, (M_PI * 2) * (((CGFloat)(hours % 12) + + ((CGFloat)(minutes % 60) / 60.0)) / 12.0), radius * hourScale);
  CGPoint minutePoint = point(center, (M_PI * 2) * ((CGFloat)(minutes % 60) / 60.0), radius * minuteScale);
  
  // Hands.
  CGContextMoveToPoint(context, center.x, center.y);
  CGContextAddLineToPoint(context, hourPoint.x, hourPoint.y);
  CGContextStrokePath(context);
  CGContextMoveToPoint(context, center.x, center.y);
  CGContextAddLineToPoint(context, minutePoint.x, minutePoint.y);
  CGContextStrokePath(context);
  
}

static NSDictionary *getProperties(NSString *path) {
  
  NSURL *URL = [NSURL fileURLWithPath:path];
  CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)URL, NULL);
  if (source == nil) {
    return NO;
  }
  
  NSDictionary *props = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
  CFRelease(source);
  
  return props;
}

static BOOL getTime(NSString *path, NSUInteger *hours, NSUInteger *minutes)
{
  NSDictionary *props = getProperties(path);
  if (props == nil) {
    return NO;
  }
  
  // Get the date.
  NSString *date = props[@"{Exif}"][@"DateTimeOriginal"];
  if (date == nil) {
    return NO;
  }
  
  // Parse the date.
  NSArray *components = [date componentsSeparatedByString:@" "];
  NSArray *time = [components[1] componentsSeparatedByString:@":"];
  *hours = [time[0] integerValue];
  *minutes = [time[1] integerValue];
  return YES;
}

int main(int argc, const char * argv[])
{
  @autoreleasepool {
    
    // Process the arguments.
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:3];
    for (int i = 1; i < argc; i++) {
      NSString *argument = [NSString stringWithUTF8String:argv[i]];
      [files addObject:argument];
    }
    
    // Process the files.
    for (NSString *file in files) {
      NSLog(@"Processing '%@'...", file);
      
      // Load the date and only attempt to render a clock if we have a time.
      NSUInteger hours = 5;
      NSUInteger minutes = 5;
      if (getTime(file, &hours, &minutes)) {
        
        // Render the clock.
        @autoreleasepool {
          NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
          [image lockFocus];
          CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
          renderTime(context, hours, minutes);
          [image unlockFocus];
          NSBitmapImageRep *tiffRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
          NSDictionary *imageProperties = @{NSImageCompressionFactor: @0.5};
          NSData *data = [tiffRep representationUsingType:NSJPEGFileType properties:imageProperties];
          [data writeToFile:@"output.jpg" atomically:YES];
        }
      }
    }
    
  }
    return 0;
}

