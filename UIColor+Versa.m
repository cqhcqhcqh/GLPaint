//
//  UIColor+Versa.m
//  WatchTV
//
//  Created by sheen on 15/11/10.
//  Copyright © 2015年 WatchTV. All rights reserved.
//

#define DEFAULT_VOID_COLOR [UIColor whiteColor]
#import "UIColor+Versa.h"

@implementation UIColor (Versa)
+ (UIColor *)colorWithHexString:(NSString *)stringToConvert WithAlpha:(CGFloat)alpha {
    NSString *cString = [[stringToConvert stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    if ([cString length] < 6)
        return DEFAULT_VOID_COLOR;
    if ([cString hasPrefix:@"#"])
        cString = [cString substringFromIndex:1];
    if ([cString hasPrefix:@"0X"])
        cString = [cString substringFromIndex:2];
    if ([cString length] != 6)
        return DEFAULT_VOID_COLOR;
    
    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString *rString = [cString substringWithRange:range];
    
    range.location = 2;
    NSString *gString = [cString substringWithRange:range];
    
    range.location = 4;
    NSString *bString = [cString substringWithRange:range];
    
    
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    if ([UIColor respondsToSelector:@selector(colorWithDisplayP3Red:green:blue:alpha:)]) {
        return [UIColor colorWithDisplayP3Red:((float) r / 255.0f) green:((float) g / 255.0f) blue:((float) b / 255.0f) alpha:alpha];
    } else {
        return [UIColor colorWithRed:((float) r / 255.0f)
                               green:((float) g / 255.0f)
                                blue:((float) b / 255.0f)
                               alpha:alpha];
    }
}

//字符串转颜色
+ (UIColor *)colorWithHexString:(NSString *)stringToConvert
{
    return [self colorWithHexString:stringToConvert WithAlpha:1.0];
}
@end
