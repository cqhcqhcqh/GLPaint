//
//  UIColor+Versa.h
//  WatchTV
//
//  Created by sheen on 15/11/10.
//  Copyright © 2015年 WatchTV. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (Versa)
+ (UIColor *)colorWithHexString:(NSString *)stringToConvert;
+ (UIColor *)colorWithHexString:(NSString *)stringToConvert WithAlpha:(CGFloat)alpha;
@end
