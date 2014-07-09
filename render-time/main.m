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

void renderTime(CGContextRef context, NSUInteger hours, NSUInteger minutes, CGFloat radius, CGPoint center)
{
  static CGFloat hourScale = 0.6;
  static CGFloat minuteScale = 0.8;
  CGFloat lineWidth = radius / 7.5;

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
  // TODO Time zones.
  NSArray *components = [date componentsSeparatedByString:@" "];
  NSArray *time = [components[1] componentsSeparatedByString:@":"];
  *hours = [time[0] integerValue];
  *minutes = [time[1] integerValue];
  return YES;
}

int main(int argc, const char * argv[])
{
  @autoreleasepool {
    
    static NSString *const kDefaultRadius = @"radius";
    static NSString *const kDefaultCenterX = @"centerX";
    static NSString *const kDefaultCenterY = @"centerY";
    
    // Register the defaults.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{kDefaultRadius: @60.0,
                                 kDefaultCenterX: @100.0,
                                 kDefaultCenterY: @100.0}];
    
    // Strip the defaults from the arguments.
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSInteger index = 1;
    while (index < [arguments count]) {
      NSString *argument = arguments[index];
      NSRange range = [argument rangeOfString:@"-"];
      if (range.location == 0) {
        index = index + 2;
      } else {
        [files addObject:argument];
        index = index + 1;
      }
    }
    
    CGFloat radius = [defaults floatForKey:kDefaultRadius];
    CGFloat centerX = [defaults floatForKey:kDefaultCenterX];
    CGFloat centerY = [defaults floatForKey:kDefaultCenterY];
    
    if ([files count] == 0) {
      printf("usage: render-time [-radius RADIUS] [-centerX CENTERX] image1 [image2 [image3 ...]]\n"
             "\n"
             "Render an analog clock showing the EXIF timestamp into an image.\n"
             "\n"
             "optional arguments:\n"
             " -radius RADIUS       Radius of the clock\n"
             " -centerX CENTERX     The x-coordinate of the center of the clock\n"
             " -centerY CENTERY     The y-coordinate of the center of the clock\n");
      return 1;
    }
    
    // Process the files.
    for (NSString *file in files) {
      printf("Processing '%s'...\n", [file cStringUsingEncoding:NSUTF8StringEncoding]);
      
      // Load the date and only attempt to render a clock if we have a time.
      NSUInteger hours, minutes;
      if (getTime(file, &hours, &minutes)) {
        
        // Render the clock.
        @autoreleasepool {
          NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
          [image lockFocus];
          CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
          renderTime(context, hours, minutes, radius, CGPointMake(centerX, centerY));
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

