//
// Copyright (c) 2014 Jason Barrie Morley.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
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
  NSArray *components = [date componentsSeparatedByString:@" "];
  NSArray *time = [components[1] componentsSeparatedByString:@":"];
  *hours = [time[0] integerValue];
  *minutes = [time[1] integerValue];
  return YES;
}

CGImageRef CGImageCreateWithCGContext(CGContextRef context)
{
  CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                CGBitmapContextGetData(context),
                                CGBitmapContextGetBytesPerRow(context) * CGBitmapContextGetHeight(context));
  CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
  CGImageRef image = CGImageCreate(CGBitmapContextGetWidth(context),
                                   CGBitmapContextGetHeight(context),
                                   CGBitmapContextGetBitsPerComponent(context),
                                   CGBitmapContextGetBitsPerPixel(context),
                                   CGBitmapContextGetBytesPerRow(context),
                                   CGBitmapContextGetColorSpace(context),
                                   CGBitmapContextGetBitmapInfo(context),
                                   provider,
                                   NULL,
                                   NO,
                                   kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  CFRelease(data);
  return image;
}

NSImage *NSImageCreateWithCGContext(CGContextRef context)
{
  CGImageRef imageRef = CGImageCreateWithCGContext(context);
  NSImage *image = [[NSImage alloc] initWithCGImage:imageRef
                                               size:NSMakeSize(CGImageGetWidth(imageRef),
                                                               CGImageGetHeight(imageRef))];
  CGImageRelease(imageRef);
  return image;
}

CGContextRef CGContextCreateWithCGImage(CGImageRef image)
{
  size_t kBitsPerComponent = 8;
  size_t kBytesPerPixel = 4;
  CGContextRef context = CGBitmapContextCreate(NULL,
                                               CGImageGetWidth(image),
                                               CGImageGetHeight(image),
                                               kBitsPerComponent,
                                               CGImageGetWidth(image) * kBytesPerPixel,
                                               CGImageGetColorSpace(image),
                                               (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
  if (context == NULL) {
    return NULL;
  }
  CGContextDrawImage(context,
                     CGRectMake(0.0,
                                0.0,
                                CGImageGetWidth(image),
                                CGImageGetHeight(image)),
                     image);
  
  return context;
}

CGContextRef CGContextCreateWithNSImage(NSImage *image)
{
  NSBitmapImageRep *representation = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
  CGImageRef cgImage = [representation CGImage];
  CGContextRef context = CGContextCreateWithCGImage(cgImage);
  return context;
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
      fprintf(stderr,
              "usage: timestamp [-radius RADIUS] [-centerX CENTERX] [-centerY CENTERY] image1 [image2 ...]\n"
              "\n"
              "Render an analog clock showing the EXIF timestamp into an image.\n"
              "\n"
              "Output files will have '-timestamp' appended to the filename and will JPEG\n"
              "formatted.\n"
              "\n"
              "optional arguments:\n"
              " -radius RADIUS       Radius of the clock\n"
              " -centerX CENTERX     The x-coordinate of the center of the clock\n"
              " -centerY CENTERY     The y-coordinate of the center of the clock\n");
      return 1;
    }
    
    // Process the files.
    for (NSString *file in files) {
      @autoreleasepool {
        printf("Processing '%s'...\n", [file cStringUsingEncoding:NSUTF8StringEncoding]);
      
        // Load the date and only attempt to render a clock if we have a time.
        NSUInteger hours, minutes;
        if (getTime(file, &hours, &minutes)) {
          
          // Determine the output filename.
          NSString *directory = [file stringByDeletingLastPathComponent];
          NSString *filename = [[file lastPathComponent] stringByDeletingPathExtension];
          NSString *output = [[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-timestamp", filename]] stringByAppendingPathExtension:@"jpg"];
        
          // Render the clock.
          NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
          CGContextRef context = CGContextCreateWithNSImage(image);
          renderTime(context, hours, minutes, radius, CGPointMake(centerX, centerY));
          CGImageRef result = CGImageCreateWithCGContext(context);
          CGContextRelease(context);
          
          NSBitmapImageRep *contextRep = [[NSBitmapImageRep alloc] initWithCGImage:result];
          [contextRep setSize:[image size]];
          NSDictionary *imageProperties = @{NSImageCompressionFactor: @0.5};
          NSData *data = [contextRep representationUsingType:NSJPEGFileType properties:imageProperties];
          BOOL success = [data writeToFile:output atomically:YES];
          if (NO == success) {
            fprintf(stderr, "ERROR: Unable to write to '%s'.\n", [output cStringUsingEncoding:NSUTF8StringEncoding]);
          }
          
          CGImageRelease(result);


        } else {
          fprintf(stderr, "ERROR: Unable to read '%s'.\n", [file cStringUsingEncoding:NSUTF8StringEncoding]);
          return 1;
        }
        
      }
    }
    
  }
    return 0;
}

